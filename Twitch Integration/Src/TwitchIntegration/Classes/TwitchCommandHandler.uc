class TwitchCommandHandler extends Object
    config (TwitchChatCommands)
    abstract;

// Which commands the class can handle, without the leading exclamation point
// (i.e. "xsay" rather than "!xsay")
var config array<string> CommandAliases;

var config bool bEnableInStrategy;
var config bool bEnableInTactical;

function Initialize(TwitchStateManager StateMgr) {
}

function Handle(TwitchStateManager StateMgr, TwitchMessage Command, TwitchViewer Viewer);

protected function string GetCommandBody(TwitchMessage Command) {
    local int Index;
    Index = Instr(Command.Body, " ");

    if (Index == INDEX_NONE) {
        return "";
    }

    return Mid(Command.Body, Index + 1);
}