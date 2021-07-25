class TwitchCommandHandler extends Object abstract;

// Set this in subclasses to indicate which commands the class can handle,
// without the leading exclamation point (i.e. "xsay" rather than "!xsay")
var protectedwrite array<string> CommandAliases;

function Handle(TwitchStateManager StateMgr, string CommandAlias, string CommandBody, string Sender);