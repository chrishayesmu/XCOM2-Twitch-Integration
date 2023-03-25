class TwitchCommandHandler_ExecuteAction extends TwitchCommandHandler;

struct TCH_ActionTuple {
    var array<string> Aliases;
    var name ActionName;

    var bool bMustBeSub;
    var int CostInBits;
};

var config array<TCH_ActionTuple> ActionTuples;

function Initialize(TwitchStateManager StateMgr) {
    local TCH_ActionTuple Tuple;
    local array<string> Aliases;
    local string Alias;

    // This command ignores any aliases set in config, in favor of ones defined in ActionTuples
    CommandAliases.Length = 0;

    foreach ActionTuples(Tuple) {
        foreach Tuple.Aliases(Alias) {
            `TILOG("Tuple: ActionName = " $ Tuple.ActionName $ ", Alias = " $ Alias);
            Aliases.AddItem(Alias);
        }
    }

    CommandAliases = Aliases;
}

function Handle(TwitchStateManager StateMgr, TwitchMessage Command, TwitchViewer Viewer) {
    local bool bMatchesTuple;
    local string Alias, CmdAlias;
    local TCH_ActionTuple Tuple;
    local X2TwitchEventActionTemplate Action;
    local XComGameState_Unit ViewerOwnedUnit;

    // Remove leading exclamation point and find the alias we were invoked with
    Alias = Mid(Command.Body, 1, Instr(Command.Body, " ") - 1);

    // Figure out which tuple is being invoked
    foreach ActionTuples(Tuple) {
        bMatchesTuple = false;

        // Can't just use .Find due to case-sensitivity
        foreach Tuple.Aliases(CmdAlias) {
            if (CmdAlias ~= Alias) {
                bMatchesTuple = true;
                break;
            }
        }

        if (!bMatchesTuple) {
            continue;
        }

        if (Tuple.bMustBeSub && !Viewer.bIsSub) {
            `TILOG("Viewer is not a sub and cannot use this command");
            return;
        }

        if (Tuple.CostInBits > Command.NumBits) {
            `TILOG("Not enough bits sent to use command; require " $ Tuple.CostInBits $ " but received " $ Command.NumBits);
            return;
        }

        Action = class'X2TwitchUtils'.static.GetTwitchEventActionTemplate(Tuple.ActionName);

        if (Action == none) {
            `TILOG("Didn't find an action called " $ Tuple.ActionName $ ". This command may be misconfigured.");
            return;
        }

        break;
    }

    if (Action == none) {
        `TILOG("Never found an alias matching " $ Alias $ ", which should be impossible");
        return;
    }

    ViewerOwnedUnit = class'X2TwitchUtils'.static.FindUnitOwnedByViewer(Viewer.Login);

    if (!Action.IsValid(ViewerOwnedUnit)) {
        `TILOG("Action '" $ Tuple.ActionName $ "' is not presently valid. Not executing. Action class is " $ Action.Class);
        return;
    }

    `TILOG("Executing action '" $ Tuple.ActionName $ "'");
    Action.Apply(ViewerOwnedUnit, none);
}