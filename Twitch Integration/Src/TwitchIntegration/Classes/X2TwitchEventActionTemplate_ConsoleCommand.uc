class X2TwitchEventActionTemplate_ConsoleCommand extends X2TwitchEventActionTemplate;

var config string ConsoleCommand;

function Apply(optional XComGameState_Unit InvokingUnit, optional bool ForceUseProvidedUnit = false) {
    local string Command;

    Command = ConsoleCommand;

    Command = Repl(Command, "<UnitObjectID/>", InvokingUnit != none ? InvokingUnit.GetReference().ObjectID : 0);

    `TILOG("Executing console command " $ Command);

    `XCOMGAME.GetALocalPlayerController().ConsoleCommand(Command);
}

function bool IsValid(optional XComGameState_Unit InvokingUnit, optional bool ForceUseProvidedUnit = false) {
    return true;
}