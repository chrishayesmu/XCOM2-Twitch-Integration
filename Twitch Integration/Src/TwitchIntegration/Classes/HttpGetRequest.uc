class HttpGetRequest extends TcpLink;

struct HttpHeader {
	var string Key;
	var string Value;
};

struct HttpResponse {
	var array<HttpHeader> Headers;
	var string Body;
	var int ResponseCode;
};

var private string CurrentUrl;
var private string Host;
var private string RequestPath;

// State tracking for reading the response data in chunks
var private bool bIsChunkTransferEncoding;
var private bool bFirstChunkReceived;
var private bool bLastChunkReceived;
var private bool bRequestInProgress;
var private int RemainingBytesInChunk;
var private HttpResponse Response;

var private delegate<ResponseHandler> OnRequestComplete;
var private delegate<ResponseHandler> OnRequestError;

delegate ResponseHandler(HttpResponse Resp);

const LogRequest = true;

function Call(string Url, delegate<ResponseHandler> CompletionHandler, delegate<ResponseHandler> ErrorHandler = none)
{
    local HttpResponse EmptyResponse;
	local int Index;

    if (bRequestInProgress) {
        `WARN("[HttpGetRequest] Same object is being re-used while still in use, which is not allowed", , 'TwitchIntegration');
        return;
    }

	CurrentUrl = Url;
	OnRequestComplete = CompletionHandler;
    OnRequestError = ErrorHandler;

	Index = InStr(CurrentUrl, "/");
	Host = Left(CurrentUrl, Index);
	RequestPath = Mid(CurrentUrl, Index);

    // Reset per-request state
    bIsChunkTransferEncoding = false;
    bFirstChunkReceived = false;
    bLastChunkReceived = false;
    bRequestInProgress = true;
    RemainingBytesInChunk = 0;

    Response = EmptyResponse;

    `LOG("[HttpGetRequest] Resolving host: " $ Host, LogRequest, 'TwitchIntegration');
    resolve(Host);
}

function int SendText(coerce string str) {
	`LOG("[HttpGetRequest] [SEND] " $ str, LogRequest, 'TwitchIntegration');

	return super.SendText(str);
}

event Resolved(IpAddr Addr)
{
    Addr.Port = 80;

    `LOG("[HttpGetRequest] " $ CurrentUrl $ " resolved to " $ IpAddrToString(Addr), LogRequest, 'TwitchIntegration');
    `LOG("[HttpGetRequest] Bound to local port: " $ BindPort(), LogRequest, 'TwitchIntegration');

    if (!Open(Addr))
    {
        `WARN("[HttpGetRequest] Failed to open request", , 'TwitchIntegration');

        Response.ResponseCode = 400;

        if (OnRequestError != none) {
            OnRequestError(Response);
        }
    }
}

event ResolveFailed()
{
    `LOG("[HttpGetRequest] Unable to resolve address " $ CurrentUrl, LogRequest, 'TwitchIntegration');

    Response.ResponseCode = 400;

    if (OnRequestError != none) {
        OnRequestError(Response);
    }
}

event Opened()
{
	local string CRLF;
	CRLF = chr(13) $ chr(10);

    `LOG("[HttpGetRequest] Sending HTTP request body", LogRequest, 'TwitchIntegration');

    // Simple HTTP GET request
    SendText("GET " $ RequestPath $ " HTTP/1.1" $ CRLF);
    SendText("Host: " $ Host $ CRLF);
    SendText("Connection: close" $ CRLF);
	SendText(CRLF); // indicate request is done

    `LOG("[HttpGetRequest] GET request sent", LogRequest, 'TwitchIntegration');
}

event Closed()
{
    `LOG("[HttpGetRequest] Connection closed; final response body is " $ Response.Body, LogRequest, 'TwitchIntegration');

    bRequestInProgress = false;

	OnRequestComplete(Response);
}

event ReceivedText(string Text)
{
    local array<string> HeaderStrings;
	local array<string> ResponseParts;
    local int Index;
    local string ChunkBody;
    local string ChunkSizeInHex;
	local string CRLF;
	local string HeaderLine;

	CRLF = chr(13) $ chr(10);

    // Trim any leading CRLF, which chunks sometimes start with for some reason
    if (Left(Text, 2) == CRLF) {
        Text = Mid(Text, 2);
    }

    `LOG("[HttpGetRequest] Received text: " $ Text, LogRequest, 'TwitchIntegration');

    if (bLastChunkReceived) {
        // We might receive headers after the response body, but we don't care about them
        return;
    }

    if (!bFirstChunkReceived) {
        bFirstChunkReceived = true;

        // The headers and body are separated by two CRLFs
        ResponseParts = SplitString(Text, CRLF $ CRLF, /* bCullEmpty */ true);

        // Headers are one per line, though the first line is the response code so we'll handle it specially
        HeaderStrings = SplitString(ResponseParts[0], CRLF, /* bCullEmpty */ true);
        Response.Headers.Length = HeaderStrings.Length - 1;

        // The first line is always "HTTP/1.1 xxx TEXT", where xxx is the response code (200 being OK) and TEXT is the text
        // version of the response code (OK, Bad Request, etc). We only care about xxx so we grab it directly.
        Response.ResponseCode = int(Mid(HeaderStrings[0], 9, 3));

        for (Index = 1; Index < HeaderStrings.Length; Index++) {
            HeaderLine = HeaderStrings[Index];
            Response.Headers[Index - 1].Key = Left(HeaderLine, InStr(HeaderLine, ":"));
            Response.Headers[Index - 1].Value = Split(HeaderLine, ": ", /* bOmitSplitStr */ true);

            if (Response.Headers[Index - 1].Key == "Transfer-Encoding" && Response.Headers[Index - 1].Value == "chunked") {
                bIsChunkTransferEncoding = true;
            }
        }

        if (Response.ResponseCode < 200 || Response.ResponseCode >= 300) {
            if (OnRequestError != none) {
                OnRequestError(Response);
            }

            return;
        }

        // For the body, in a chunked encoding, the first line of the body will be a hex number indicating the number of bytes
        // in the first chunk; otherwise we go straight into the body
        if (bIsChunkTransferEncoding) {
            ChunkSizeInHex = Left(ResponseParts[1], Instr(ResponseParts[1], CRLF));
            Response.Body = Split(ResponseParts[1], CRLF, /* bOmitSplitStr */ true);

            RemainingBytesInChunk = HexToInt(ChunkSizeInHex);
            RemainingBytesInChunk -= Len(Response.Body);
        }
        else {
            Response.Body = ResponseParts[1];
        }
    }
    else {
        // We've already received the first chunk. Non-chunk encodings are simply appended, but for chunked encodings, we need to see
        // whether we're currently in the middle of a chunk, because the TcpLink class isn't handing us the entire chunk at once. We
        // also need to see if we're receiving the last chunk, which is just a chunk with a size of 0.
        if (!bIsChunkTransferEncoding) {
            Response.Body $= Text;
            return;
        }

        // We might get multiple chunks concatenated thanks to TcpLink buffering, so we need to be able to identify a new chunk mid-stream
        if (Len(Text) > RemainingBytesInChunk) {
            Response.Body $= Left(Text, RemainingBytesInChunk);
            Text = Mid(Text, RemainingBytesInChunk + 2); // skip past the CRLF that ends this chunk

            RemainingBytesInChunk = 0;
        }

        if (RemainingBytesInChunk == 0) {
            // Previous chunk is done; we're about to start a new one, or end completely
            ChunkSizeInHex = Left(Text, Instr(Text, CRLF));
            RemainingBytesInChunk = HexToInt(ChunkSizeInHex);

            if (RemainingBytesInChunk == 0) {
                bLastChunkReceived = true;
                return;
            }

            ChunkBody = Split(Text, CRLF, /* bOmitSplitStr */ true);
        }
        else {
            ChunkBody = Text;
        }

        // Append data from the current chunk
        Response.Body $= ChunkBody;
        RemainingBytesInChunk -= Len(ChunkBody);

        if (RemainingBytesInChunk < 0) {
            `WARN("[HttpGetRequest] WARNING: negative number of bytes remaining in chunk: " $ RemainingBytesInChunk, , 'TwitchIntegration');
        }
    }
}

private function int HexToInt(string HexVal) {
    local int CurrentCharAscii;
    local int IntVal;
    local int Index;
    local int Power;

    HexVal = Locs(HexVal);
    Power = 1;

    for (Index = 0; Index < Len(HexVal); Index++) {
        // Asc gives the ASCII value of the first character of the string, so we just pull successively
        // more characters from the right side of the string
        CurrentCharAscii = Asc(Right(HexVal, Index + 1));

        // ASCII characters 0 through 9 map to [48, 57]; a through f map to [97, 102]
        CurrentCharAscii = CurrentCharAscii - 48;

        if (CurrentCharAscii > 9) {
            CurrentCharAscii = CurrentCharAscii - 39;
        }

        if (CurrentCharAscii < 0 || CurrentCharAscii > 15) {
            `LOG("[HttpGetRequest] WARNING: character out of range; adjusted ASCII value is " $ CurrentCharAscii, , 'TwitchIntegration');
            return -1;
        }

        IntVal += CurrentCharAscii * Power;
        Power *= 16;
    }

    return IntVal;
}