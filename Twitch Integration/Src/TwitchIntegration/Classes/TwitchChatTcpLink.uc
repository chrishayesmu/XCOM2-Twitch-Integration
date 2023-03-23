class TwitchChatTcpLink extends TcpLink
    config(TwitchIntegration);

`define SENDLINE(msg) SendText(`msg $ chr(13) $ chr(10)); `TILOG("Sending line:   " $ `msg, LogTraffic);

// ------------------------------------------
// Enums and struct definitions

enum eTwitchMessageType {
	eTwitchMessageType_ClearMessage, // A mod has deleted a single chat message
	eTwitchMessageType_Chat,         // Someone has sent a message in the channel's chat
	eTwitchMessageType_Irrelevant,   // Any message type that we aren't concerned with
	eTwitchMessageType_MOTD,         // MOTD is sent when first connecting to chat
	eTwitchMessageType_Ping,         // Ping is sent periodically and requires a pong response to stay connected
	eTwitchMessageType_UserJoin,     // User has joined the stream chat
	eTwitchMessageType_UserPart,     // User has left the stream chat
	eTwitchMessageType_Whisper,      // Someone has sent a whisper to the logged-in account
};

struct MessageTag {
    var string Key;
    var string Value;
};

struct TwitchMessage {
	var ETwitchMessageType MessageType;

    var string Body;                   // Parsed body of the message; will be blank for many message types
    var string MsgId;                  // Unique GUID for the message, needed in case the message is deleted later; if MessageType is ClearMessage, this is the ID of the target message
    var string SenderLogin;            // Unique ID of the individual sending the message
    var int NumBits;                   // How many bits the viewer spent in this message
};

struct TwitchViewer {
    var string ChatColor;    // The hex color this viewer uses for their chat messages (includes the leading #)
    var string Login;        // The login of the viewer (should be same as Name but all lowercase)
	var string DisplayName;  // The name the viewer uses in chat
    var int LastSeenTime;    // Unix timestamp (seconds) of when this viewer was last seen to be active
    var int OwnedObjectID;   // If > 0, the ID of an object this viewer has raffled as owner of

    var bool bHasSentChat;   // Has this user ever sent a chat message?
    var bool bIsMod;         // Is this user a moderator?
    var bool bIsSub;         // Is this user subbed to the channel?
    var bool bIsVip;         // Is this user a channel VIP?
};

struct QueuedOutboundMessage {
    var string ViewerNameToWhisper;     // If empty, this message is not a whisper
    var string Message;
    var float TimeoutInSeconds;         // How long to keep this message valid in the queue
    var float SubmittedRealTimeSeconds; // WorldInfo.RealTimeSeconds when this message was queued

    // TODO support message priority
};

struct QueuedInboundMessage {
    var TwitchMessage Message;
    var TwitchViewer FromViewer;
};

// ------------------------------------------
// Config vars

var privatewrite string TwitchChannel;
var privatewrite string TwitchUsername;
var private string OAuthToken;

var config(TwitchDebug) bool LogTraffic;

// ------------------------------------------
// Publicly visible state

var array<TwitchViewer> Viewers;
var privatewrite bool bConnectedAsBroadcaster;
var privatewrite bool bConnectedAsMod;

// ------------------------------------------
// Private state

var private int NumConnectAttempts;

var private string TargetHost;
var private int TargetPort;

var private string MessagePrefix;
var private array<QueuedOutboundMessage> OutboundMessageQueue;
var private array<QueuedInboundMessage> InboundMessageQueue;

var private delegate<MessageListener> OnMessageReceived;
var private delegate<ConnectionListener> OnConnectSuccessful;

const BaseReconnectWaitInSeconds = 1;

const MessageQueueProcessingFrequencySeconds = 1.0;
const RateLimit_MessagesPer30s_Normal = 20;
const RateLimit_MessagesPer30s_ModOrBroadcaster = 100;
const RateLimit_WhispersPerSecond = 3;
const RateLimit_WhispersPerMinute = 100;
const ViewerPurgeFrequencySeconds = 120.0;

delegate ConnectionListener();
delegate MessageListener(TwitchMessage Chat, TwitchViewer FromViewer);

function Initialize(delegate<ConnectionListener> OnConnect = none, delegate<MessageListener> OnMessage = none) {
	TwitchChannel = Locs(`TI_CFG(TwitchChannel));
    TwitchUsername = Locs(`TI_CFG(TwitchUsername));
    OAuthToken = `TI_CFG(OAuthToken);

    `TILOG("Initializing Twitch connection with channel = " $ TwitchChannel $ ", username = " $ TwitchUsername);

	OnMessageReceived = OnMessage;
    OnConnectSuccessful = OnConnect;

    bConnectedAsBroadcaster = (TwitchChannel == TwitchUsername);

    if (Left(OAuthToken, 6) != "oauth:") {
        OAuthToken = "oauth:" $ OAuthToken;
    }

    MessagePrefix = ":" $ TwitchUsername $ "!" $ TwitchUsername $ "@" $ TwitchUsername $ ".tmi.twitch.tv ";

    LinkMode = MODE_Line;
    Connect();
}

// DEBUG USE ONLY - sends a message to Twitch's IRC endpoint exactly as it is sent to this method, plus a CRLF.
function DebugSendRawIrc(string IrcMessage) {
    `TILOG("Sending debug IRC message with text: " $ IrcMessage);
    `SENDLINE(IrcMessage);
}

// Retrieves the viewer with the given login, if connected. Returns their index in the
// Viewers array if found, or INDEX_NONE if not.
function int GetViewer(string Login, out TwitchViewer Viewer) {
    local TwitchViewer Empty;
    local int Index;

    Index = Viewers.Find('Login', Login);

    if (Index == INDEX_NONE) {
        Viewer = Empty;
        Viewer.Login = Login;
        return INDEX_NONE;
    }

    Viewer = Viewers[Index];
    return Index;
}

// Queues a chat message to be sent to the channel. Due to rate limiting, it may take
// some time for the message to be sent; if it is not sent before the specified timeout,
// the message will be unqueued and never sent. Messages will also not be sent if they
// are still in queue when the current mission ends.
function QueueChat(string Message, float TimeoutInSeconds) {
    local QueuedOutboundMessage QueueMsg;

    QueueMsg.Message = Message;
    QueueMsg.TimeoutInSeconds = TimeoutInSeconds;
    QueueMsg.SubmittedRealTimeSeconds = WorldInfo.RealTimeSeconds;

    OutboundMessageQueue.AddItem(QueueMsg);
}

// Queues a whisper to be sent to the target viewer. Due to rate limiting, it may take
// some time for the whisper to be sent; if it is not sent before the specified timeout,
// the message will be unqueued and never sent. Messages will also not be sent if they
// are still in queue when the current mission ends.
function QueueWhisper(string TargetViewerName, string Message, float TimeoutInSeconds) {
    local QueuedOutboundMessage QueueMsg;

    QueueMsg.Message = Message;
    QueueMsg.TimeoutInSeconds = TimeoutInSeconds;
    QueueMsg.ViewerNameToWhisper = TargetViewerName;
    QueueMsg.SubmittedRealTimeSeconds = WorldInfo.RealTimeSeconds;

    OutboundMessageQueue.AddItem(QueueMsg);
}

// ------------------------------------------
// Functions for maintaining internal state and handling messages

function Connect() {
    if (TwitchChannel == "") {
        `WARN("No Twitch channel name has been configured! Unable to connect.");
        return;
    }

    if (IsConnected()) {
        `TILOG("Connection already established to Twitch. Not reconnecting.");
        return;
    }

    NumConnectAttempts++;
    `TILOG("Beginning connection attempt #" $ NumConnectAttempts, LogTraffic);

    `TILOG("Resolving host: " $ TargetHost, LogTraffic);
    Resolve(TargetHost);
}

event Resolved(IpAddr Addr) {
    local int PortNum;

    PortNum = BindPort();

    `TILOG(TargetHost $ " resolved to " $ IpAddrToString(Addr), LogTraffic);
    `TILOG("Bound to port: " $ PortNum, LogTraffic);

    Addr.Port = TargetPort;

    if (!Open(Addr))
    {
        `TILOG("Failed to open connection to Twitch");
    }
}

event ResolveFailed() {
    `TILOG("Unable to resolve address " $ TargetHost);
}

event Opened() {
    `TILOG("Sending IRC connect request", LogTraffic);

	// Note that channel name needs to be all lowercase
    `SENDLINE("CAP REQ :twitch.tv/commands");
    `SENDLINE("CAP REQ :twitch.tv/membership");
    `SENDLINE("CAP REQ :twitch.tv/tags");
    `SENDLINE("PASS " $ OAuthToken);
    `SENDLINE("NICK " $ TwitchUsername);
    `SENDLINE("JOIN #" $ TwitchChannel);

    `TILOG("IRC connect request sent", LogTraffic);
}

event Closed() {
    local int Index;
    local int ReconnectExponent;
    local float ReconnectWaitTime;

    `TILOG("Connection closed", LogTraffic);

    ClearTimer(nameof(ProcessMessageQueue));
    ClearTimer(nameof(PurgeStaleViewers));

    // Attempt to reconnect with exponential backoff
    ReconnectExponent = Clamp(NumConnectAttempts - 1, 0, 5);
    ReconnectWaitTime = BaseReconnectWaitInSeconds;

    for (Index = 0; Index < ReconnectExponent; Index++) {
        ReconnectWaitTime *= 2;
    }

    SetTimer(ReconnectWaitTime, /* inBLoop */ false, 'Connect');

    // We want to notify the player that connection's been lost, but if you have a spotty connection,
    // you shouldn't get spammed every time it drops. We'll trigger the event on the first failed retry,
    // since that means you'll probably be disconnected long enough to notice.
    if (NumConnectAttempts == 2) {
        `WARN("[TwitchChatTcpLink] Connection temporarily closed, notifying player");
	    `XEVENTMGR.TriggerEvent('TwitchChatConnectionClosed');
    }
}

event ReceivedLine(string MessageStr) {
	local TwitchMessage Message;
	local TwitchViewer Viewer;

    `TILOG("Received message: " $ MessageStr, LogTraffic);

    Message = ParseMessage(MessageStr, Viewer);
    HandleMessage(Message, Viewer);
}

event Tick(float DeltaTime) {
    local int I;

    for (I = 0; I < InboundMessageQueue.Length; I++) {
        OnMessageReceived(InboundMessageQueue[I].Message, InboundMessageQueue[I].FromViewer);
    }

    InboundMessageQueue.Length = 0;
}

private function HandleMessage(TwitchMessage Message, TwitchViewer FromViewer) {
    local QueuedInboundMessage InboundMessage;

    bEnqueueMessage = true;

	if (Message.MessageType == eTwitchMessageType_Irrelevant) {
		bEnqueueMessage = false;
	}
	else if (Message.MessageType == eTwitchMessageType_MOTD) {
        bEnqueueMessage = false;

		`TILOG("Successfully connected to Twitch chat on attempt #" $ NumConnectAttempts, LogTraffic);
        NumConnectAttempts = 0;

        SetTimer(MessageQueueProcessingFrequencySeconds, /* inbLoop */ true, nameof(ProcessMessageQueue));
        SetTimer(ViewerPurgeFrequencySeconds, /* inbLoop */ true, nameof(PurgeStaleViewers));

		`XEVENTMGR.TriggerEvent('TwitchChatConnectionSuccessful');

        OnConnectSuccessful();
	}
	else if (Message.MessageType == eTwitchMessageType_Ping) {
		// Need to respond to pings as a connection keep-alive
		`TILOG("Replying to PING with PONG", LogTraffic);
		`SENDLINE("PONG :tmi.twitch.tv");
	}
    else {
        // Our connection seems to run in a separate thread from the game logic, so we don't process most messages immediately.
        // They're queued up until the connection's Tick function runs in the game thread.
        InboundMessage.Message = Message;
        InboundMessage.FromViewer = FromViewer;

        InboundMessageQueue.AddItem(InboundMessage);
    }
}

private function ETwitchMessageType MapMessageType(string MessageType) {
    switch (MessageType) {
        case "001":
            return eTwitchMessageType_MOTD;
        case "CLEARMSG":
            return eTwitchMessageType_ClearMessage;
        case "JOIN":
            return eTwitchMessageType_UserJoin;
        case "PART":
            return eTwitchMessageType_UserPart;
        case "PING":
            return eTwitchMessageType_Ping;
        case "PRIVMSG":
            return eTwitchMessageType_Chat;
        case "WHISPER":
            return eTwitchMessageType_Whisper;
        default:
        	return eTwitchMessageType_Irrelevant;
    }
}

private function TwitchMessage ParseMessage(string Message, out TwitchViewer Viewer) {
	// ----------------------------
	// Message examples:
	//
	//     :tmi.twitch.tv 001 swfdelicious :Welcome, GLHF!
    //     @badges=;color=;display-name=swfDelicious;emotes=;message-id=1;thread-id=112511437_714298636;turbo=0;user-id=112511437;user-type= :swfdelicious!swfdelicious@swfdelicious.tmi.twitch.tv WHISPER swfdeliciousbot :sup
	// ----------------------------
	local string MessageType;
	local string Sender;
	local int index;
	local TwitchMessage MessageStruct;
    local array<MessageTag> DataTags;

    // Special message: indicates a connection keep-alive from Twitch's end
	if (Message == "PING :tmi.twitch.tv") {
		MessageStruct.MessageType = eTwitchMessageType_Ping;
		return MessageStruct;
	}

    // ParseTags handles removing the data tag string if it's present
    DataTags = ParseTags(Message);

    Index = Instr(Message, " ");
    Sender = Left(Message, Index); // raw sender field, e.g. :tmi.twitch.tv or :swfdelicious!swfdelicious@swfdelicious.tmi.twitch.tv
    Message = Mid(Message, Index + 1);

    // Pull out message type field next
    Index = Instr(Message, " ");
    MessageType = Left(Message, Index);
    Message = Mid(Message, Index + 1);

    // Next is the room ID; we don't care about it so we just skip past
    Index = Instr(Message, " ");
    Message = Mid(Message, Index + 2); // +2 because the message body starts with a colon that we don't want

    // All that's left now should be the message body
	MessageStruct.MessageType = MapMessageType(MessageType);
    PopulateMessageMetadataFromTags(MessageStruct, DataTags);

    if (MessageStruct.MessageType == eTwitchMessageType_Irrelevant) {
        // Stop processing here; if it's irrelevant then the message isn't from a real person and we don't
        // want to upsert a system user
        `TILOG("Final message struct (irrelevant): " $ MessageToString(MessageStruct), LogTraffic);
        return MessageStruct;
    }

    if (MessageStruct.MessageType == eTwitchMessageType_ClearMessage) {
        // Stop processing these because they don't have proper user info for UpsertViewer
        `TILOG("Final message struct (ClearMessage): " $ MessageToString(MessageStruct), LogTraffic);
        return MessageStruct;
    }

    if (`TISTATEMGR.BlacklistedViewerNames.Find(Locs(Sender)) != INDEX_NONE) {
        `TILOG("Not upserting viewer " $ Sender $ " because they're blacklisted", LogTraffic);
        return MessageStruct;
    }

    Viewer = UpsertViewer(Sender, DataTags, MessageStruct.MessageType);
    MessageStruct.SenderLogin = Viewer.Login;

    // Need to do this after UpsertViewer since that sets the viewer's login
    if (MessageStruct.MessageType == eTwitchMessageType_UserPart) {
        Index = Viewers.Find('Login', Viewer.Login);

        if (Index != INDEX_NONE) {
            `TILOG("Removing viewer " $ Viewer.Login $ " due to PART message", LogTraffic);
            Viewers.Remove(Index, 1);
        }
    }

    // Only store the body for messages where it matters, to save on memory
	if (MessageStruct.MessageType == eTwitchMessageType_Chat || MessageStruct.MessageType == eTwitchMessageType_Whisper) {
    	MessageStruct.Body = Message;
	}

    `TILOG("Final message struct: " $ MessageToString(MessageStruct), LogTraffic);

	return MessageStruct;
}

// Parses the tags from the beginning of the message (if any) and returns the remaining part of the message.
private function array<MessageTag> ParseTags(out string Message) {
    local int Index;
    local array<string> Parts;
    local string AllTags;
    local string TagString, Key, Value;
    local MessageTag TagStruct;
    local array<MessageTag> TagStructs;

    // Messages containing tags will always start with @
    if (Left(Message, 1) != "@") {
        return TagStructs;
    }

    // Tag string runs up until the first space, and individual tags are separated by semicolons
    Index = InStr(Message, " ");
    AllTags = Mid(Message, 1, Index - 1);
    Message = Mid(Message, Index + 1);

    Parts = SplitString(AllTags, ";", /* bCullEmpty */ true);

    foreach Parts(TagString) {
        Index = Instr(TagString, "=");
        Key = Locs(Left(TagString, Index));
        Value = Mid(TagString, Index + 1);

        TagStruct.Key = Key;
        TagStruct.Value = Value;

        TagStructs.AddItem(TagStruct);
    }

    return TagStructs;
}

private function PopulateMessageMetadataFromTags(out TwitchMessage Message, out array<MessageTag> tags) {
    local MessageTag MsgTag;

    foreach Tags(MsgTag) {
        switch (MsgTag.Key) {
            case "bits":
                Message.NumBits = int(MsgTag.Value);
                break;
            case "id":
                Message.MsgId = MsgTag.Value;
                break;
            case "target-msg-id":
                Message.MsgId = MsgTag.Value; // this is the message being deleted
                break;
            default: // bunch of keys we don't care about
                break;
        }
    }
}

private function ProcessMessageQueue() {
    local bool bIsWhisper;
    local QueuedOutboundMessage Message;
    local int NumChatMessagesSent, NumWhispersSent;
    local int Index;
    local string IrcCommand;

    if (OutboundMessageQueue.Length == 0) {
        return;
    }

    // TODO: implement rate limiting
    `TILOG("Processing message queue. There are currently " $ OutboundMessageQueue.Length $ " messages pending", LogTraffic);

    for (Index = 0; Index < OutboundMessageQueue.Length; Index++) {
        Message = OutboundMessageQueue[Index];

        bIsWhisper = (Message.ViewerNameToWhisper != "");

        IrcCommand = MessagePrefix $ "PRIVMSG #" $ TwitchChannel;

        if (bIsWhisper) {
            IrcCommand $= " :/w " $ Message.ViewerNameToWhisper @ Message.Message;
            NumWhispersSent++;
        }
        else {
            IrcCommand $= " :" $ Message.Message;
            NumChatMessagesSent++;
        }

        `SENDLINE(IrcCommand);

        OutboundMessageQueue.Remove(Index, 1);
        Index--;
    }

    `TILOG("Sent " $ NumChatMessagesSent $ " chat messages and " $ NumWhispersSent $ " whispers", LogTraffic);
}

private function PurgeStaleViewers() {
    local int Index;
    local int EarliestValidTime;
    local int ViewerTTLInMinutes;

    ViewerTTLInMinutes = Clamp(`TI_CFG(ViewerTTLInMinutes), 10, 60);

    EarliestValidTime = class'XComGameState_TimerData'.static.GetUTCTimeInSeconds() - ViewerTTLInMinutes * 60;

    for (Index = 0; Index < Viewers.Length; Index++) {
        // Remove this viewer if they're stale, but never remove the user we're connected as
        if (Viewers[Index].LastSeenTime < EarliestValidTime && Viewers[Index].Login != TwitchUsername) {
            Viewers.Remove(Index, 1);
            Index--;
        }
    }
}

private function TwitchViewer UpsertViewer(string SenderField, const array<MessageTag> Tags, eTwitchMessageType MessageType) {
    local int Index;
    local string Login;
    local MessageTag MsgTag;
    local TwitchViewer Viewer;
    local XComGameState_TwitchObjectOwnership Ownership;

    // SenderField looks like this:
    //
    //    :swfdelicious!swfdelicious@swfdelicious.tmi.twitch.tv
    //
    // We just want to pull the viewer's login and then upsert based on the tags.

    Index = Instr(SenderField, "!");
    Login = Mid(SenderField, 1, Index - 1);

    // Real accounts can't have periods but system accounts can; don't insert those
    if (Instr(Login, ".") >= 0) {
        return Viewer;
    }

    Index = GetViewer(Login, Viewer);
    Viewer.Login = Login;
    Viewer.LastSeenTime = class'XComGameState_TimerData'.static.GetUTCTimeInSeconds();

    foreach Tags(MsgTag) {
        switch (MsgTag.Key) {
            case "badges":
                Viewer.bIsVip = (Instr(MsgTag.Value, "vip/1") >= 0);
                break;
            case "color":
                Viewer.ChatColor = MsgTag.Value;
                break;
            case "display-name":
                Viewer.DisplayName = MsgTag.Value;
                break;
            case "mod":
                Viewer.bIsMod = (MsgTag.Value == "1");
                break;
            case "subscriber":
                Viewer.bIsSub = (MsgTag.Value == "1");
                break;
            default: // bunch of keys we don't care about
                break;
        }
    }

    if (MessageType == eTwitchMessageType_Chat) {
        Viewer.bHasSentChat = true;
    }

    if (Index == INDEX_NONE) {
        // For inserting viewers for the first time, find out if they own an object
        Ownership = class'XComGameState_TwitchObjectOwnership'.static.FindForUser(Viewer.Login);

        if (Ownership != none) {
            Viewer.OwnedObjectID = Ownership.OwnedObjectRef.ObjectID;
        }

        Viewers.AddItem(Viewer);
    }
    else {
        Viewers[Index] = Viewer;
    }

    `TILOG("Upserted viewer (previous index " $ Index $ "). " $ ViewerToString(Viewer), LogTraffic);

    return Viewer;
}

private function string MessageToString(TwitchMessage Message) {
    return "Message: ("       $
           "Type="            $ Message.MessageType     $
         ", MsgId="           $ Message.MsgId           $
         ", SenderLogin="     $ Message.SenderLogin     $
         ", NumBits="         $ Message.NumBits         $
         ")";
}

private function string ViewerToString(TwitchViewer Viewer) {
    return "Viewer: ("     $
           "DisplayName="  $ Viewer.DisplayName    $
         ", Login="        $ Viewer.Login          $
         ", ChatColor="    $ Viewer.ChatColor      $
         ", LastSeenTime=" $ Viewer.LastSeenTime   $
         ", bIsMod="       $ Viewer.bIsMod         $
         ", bIsSub="       $ Viewer.bIsSub         $
         ", bIsVip="       $ Viewer.bIsVip         $
         ")";
}

defaultproperties
{
    TargetHost="irc.chat.twitch.tv"
    TargetPort=6667
    LinkMode=MODE_Line
}
