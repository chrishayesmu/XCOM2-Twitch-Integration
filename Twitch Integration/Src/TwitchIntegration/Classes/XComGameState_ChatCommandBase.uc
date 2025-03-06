class XComGameState_ChatCommandBase extends XComGameState_BaseObject;

var string MessageBody; // Body of the message (not including the command itself)
var string SenderLogin; // Twitch login of the viewer who sent this command
var int SendingUnitObjectID; // Object ID of the unit owned by the sender, if any
var string TwitchMessageId; // Unique message ID within Twitch
