class TwitchCommandHandler extends Object
    config (TwitchChatCommands)
    abstract;

// Which commands the class can handle, without the leading exclamation point
// (i.e. "xsay" rather than "!xsay")
var config array<string> CommandAliases;

function Handle(TwitchStateManager StateMgr, string CommandAlias, string CommandBody, string Sender);