class TwitchChatCommand extends TwitchEventHandler
    dependson(TwitchStateManager)
    abstract;

// Which commands the class can handle, without the leading exclamation point
// (i.e. "xsay" rather than "!xsay")
var config array<string> CommandAliases;

var config bool bEnableInStrategy;
var config bool bEnableInTactical;

function Initialize(TwitchStateManager StateMgr) {
    local int I;

    // Lowercase all aliases to simplify things
    for (I = 0; I < CommandAliases.Length; I++) {
        CommandAliases[I] = Locs(CommandAliases[I]);
    }
}

function Invoke(string CommandAlias, string Body, string MessageId, TwitchChatter Viewer);