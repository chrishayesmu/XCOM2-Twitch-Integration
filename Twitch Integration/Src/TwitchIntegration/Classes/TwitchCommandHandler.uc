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

    return Mid(Command.Body, Index + 1);
}

protected function XComGameState_Unit GetViewerUnitOnMission(string TwitchLogin) {
	local XComGameState_Unit Unit;
    local XGUnit UnitActor;

    if (`TI_IS_STRAT_GAME) {
        return none;
    }

    Unit = class'X2TwitchUtils'.static.FindUnitOwnedByViewer(TwitchLogin);

    if (Unit == none) {
        return none;
    }

    // Make sure they're on the current mission
    foreach `XCOMGAME.AllActors(class'XGUnit', UnitActor) {
        if (UnitActor.ObjectID == Unit.GetReference().ObjectID) {
            return Unit;
        }
    }

    return none;
}