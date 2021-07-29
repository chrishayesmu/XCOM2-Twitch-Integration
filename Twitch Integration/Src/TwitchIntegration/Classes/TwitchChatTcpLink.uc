class TwitchChatTcpLink extends TcpLink;

enum eTwitchMessageType {
	eTwitchMessageType_Command, // someone has sent a message in the chat starting with !
	eTwitchMessageType_Irrelevant, // any message type that we aren't concerned with
	eTwitchMessageType_MOTD, // MOTD is sent when first connecting to chat
	eTwitchMessageType_Ping // ping is sent periodically and requires a pong response to stay connected
};

struct TwitchMessage {
	var string Body;
	var string Sender;
	var ETwitchMessageType MessageType;
};

var private int NumConnectAttempts;

var private string TargetChannel;
var private string TargetHost;
var private int TargetPort;

var private delegate<ChatListener> ChatHandler;

const LogMessages = false;

delegate ChatListener(TwitchMessage Chat);

function Initialize(string Channel, delegate<ChatListener> OnChat = none)
{
	TargetChannel = Locs(Channel);
	ChatHandler = OnChat;

    Connect();
}

function Connect() {
    if (TargetChannel == "") {
        `WARN("No Twitch channel name has been configured! Unable to connect.", , 'TwitchIntegration');
    }

    if (IsConnected()) {
        return;
    }

    NumConnectAttempts++;
    `LOG("[TwitchChatTcpLink] Beginning connection attempt #" $ NumConnectAttempts, , 'TwitchIntegration');

    `LOG("[TwitchChatTcpLink] Resolving host: " $ TargetHost, , 'TwitchIntegration');
    Resolve(TargetHost);
}

event Resolved(IpAddr Addr)
{
    `LOG("[TwitchChatTcpLink] " $ TargetHost $ " resolved to " $ IpAddrToString(Addr), , 'TwitchIntegration');
    `LOG("[TwitchChatTcpLink] Bound to port: " $ BindPort(), , 'TwitchIntegration');

    Addr.Port = TargetPort;

    if (!Open(Addr))
    {
        `LOG("[TwitchChatTcpLink] Open failed", , 'TwitchIntegration');
    }
}

event ResolveFailed()
{
    `LOG("[TwitchChatTcpLink] Unable to resolve address " $ TargetHost, , 'TwitchIntegration');
}

event Opened()
{
    `LOG("[TwitchChatTcpLink] Sending IRC connect request", , 'TwitchIntegration');

    // IRC connection request: using a justinfan nickname means we can use a
	// special password without needing OAuth, and enter chat in read-only mode.
	// Note that channel name needs to be all lowercase
    SendText("PASS SCHMOOPIIE" $ chr(13) $ chr(10));
    SendText("NICK justinfan19823" $ chr(13) $ chr(10));
    SendText("JOIN #" $ Locs(TargetChannel) $ chr(13) $ chr(10));

    `LOG("[TwitchChatTcpLink] IRC connect request sent", , 'TwitchIntegration');
}

event Closed()
{
    `LOG("[TwitchChatTcpLink] Connection closed", , 'TwitchIntegration');

    // TODO: attempt to reconnect with exponential backoff

    // We want to notify the player that connection's been lost, but if you have a spotty connection,
    // you shouldn't get spammed every time it drops. We'll trigger the event on the first failed retry,
    // since that means you'll probably be disconnected long enough to notice.
    if (NumConnectAttempts == 2) {
	    `XEVENTMGR.TriggerEvent('TwitchChatConnectionClosed');
    }
}

event ReceivedText(string Text)
{
	local array<string> messages;
	local string messageStr;
	local TwitchMessage message;

	// Split the text by newline into individual messages
	messages = SplitString(Text, chr(13) $ chr(10), true);

	foreach messages(messageStr) {
		 message = ParseMessage(messageStr);

		 HandleMessage(message);
	}
}

function HandleMessage(TwitchMessage Message) {
	if (Message.MessageType == eTwitchMessageType_Irrelevant) {
		return;
	}

	if (Message.MessageType == eTwitchMessageType_Command) {
		if (ChatHandler != none) {
			ChatHandler(Message);
		}
	}
	else if (Message.MessageType == eTwitchMessageType_MOTD) {
		`LOG("[TwitchChatTcpLink] Successfully connected to Twitch chat on attempt #" $ NumConnectAttempts, , 'TwitchIntegration');
        NumConnectAttempts = 0;

		`XEVENTMGR.TriggerEvent('TwitchChatConnectionSuccessful');
        class'X2TwitchUtils'.static.SubmitEmptyGameState();
	}
	else if (Message.MessageType == eTwitchMessageType_Ping) {
		// Need to respond to pings as a connection keep-alive
		`LOG("[TwitchChatTcpLink] Replying to PING with PONG", , 'TwitchIntegration');
		SendText("PONG :tmi.twitch.tv" $ chr(13) $ chr(10));
	}
}

function TwitchMessage ParseMessage(string Message) {
	// ----------------------------
	// Message examples:
	//
	//     :tmi.twitch.tv 001 justinfan19823 :Welcome, GLHF!
	//     :swfdelicious!swfdelicious@swfdelicious.tmi.twitch.tv PRIVMSG #gamesdonequick :gdqClap gdqClap gdqClap
	// ----------------------------
	local string currentSubstring;
	local string messageBody;
	local string messageType;
	local string sender;
	local int index;
	local TwitchMessage MessageStruct;

	`LOG("[TwitchChatTcpLink] Message: " $ Message, LogMessages, 'TwitchIntegration');

	if (Message == "PING :tmi.twitch.tv") {
		MessageStruct.MessageType = eTwitchMessageType_Ping;
		return MessageStruct;
	}

	// Everything up until the first space tells us who this message is from
	// Also, every message starts with :, so just dump it here
	index = InStr(Message, " ");
	sender = Mid(Message, 1, index - 1);
	currentSubstring = Mid(Message, index + 1);

	if (sender != "tmi.twitch.tv") {
		// Non-system messages have a lot of redundancy to fit the IRC protocol; we just strip that out
		index = InStr(Message, "!");
		sender = Mid(Message, 1, index - 1);

		// The only messages we care about from chatters have an exclamation point in front, and the message
		// body starts with a colon, so check for that combo before we bother with more parsing
		if (InStr(Message, ":!") < 0) {
			MessageStruct.Body = currentSubstring;
			MessageStruct.MessageType = eTwitchMessageType_Irrelevant;
			MessageStruct.Sender = sender;
			return MessageStruct;
		}
	}

	MessageStruct.Sender = sender;

	// Between the first and second space is the message type
	index = InStr(currentSubstring, " ");
	messageType = Left(currentSubstring, index);
	MessageStruct.MessageType = InterpretMessageType(messageType);

	if (MessageStruct.MessageType == eTwitchMessageType_Irrelevant) {
		// We don't care about this message so don't bother parsing more
		return MessageStruct;
	}

	// After the message type is the channel name, but we only ever connect to one channel at a time, so
	// we can just skip over that and get the message body, which starts with another colon
	index = InStr(currentSubstring, ":");
	messageBody = Mid(currentSubstring, index + 1);
	MessageStruct.Body = messageBody;

	return MessageStruct;
}

function ETwitchMessageType InterpretMessageType(string MessageType) {
	if (MessageType == "PRIVMSG") {
		return eTwitchMessageType_Command;
	}

	if (MessageType == "372") {
		return eTwitchMessageType_MOTD;
	}

	return eTwitchMessageType_Irrelevant;
}

defaultproperties
{
    TargetHost="irc.chat.twitch.tv"
    TargetPort=6667
}
