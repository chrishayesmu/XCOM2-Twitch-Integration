class TwitchCommandHandler_ExecuteAction extends TwitchCommandHandler;

struct TCH_ActionTuple {
    var string Alias;
    var name ActionName;

    var bool bMustBeSub;
    var int CostInBits;
};

var config array<TCH_ActionTuple> ActionTuples;

function Initialize(TwitchStateManager StateMgr) {
    local TCH_ActionTuple Tuple;
    local array<string> Aliases;

    // This command ignores any aliases set in config, in favor of ones defined in ActionTuples
    CommandAliases.Length = 0;

    foreach ActionTuples(Tuple) {
        Aliases.AddItem(Tuple.Alias);
    }

    CommandAliases = Aliases;
}

function Handle(TwitchStateManager StateMgr, TwitchMessage Command, TwitchViewer Viewer) {
    local string Alias;

    local TCH_ActionTuple Tuple;
    local X2TwitchEventActionTemplate Action;
    local XComGameState_Unit ViewerOwnedUnit;

    // Remove leading exclamation point and find the alias we were invoked with
    Alias = Mid(Command.Body, 1, Instr(Command.Body, " ") - 1);

    // Figure out which tuple is being invoked
    foreach ActionTuples(Tuple) {
        if (Tuple.Alias != Alias) {
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
        `TILOG("Action '" $ Tuple.ActionName $ "' is not presently valid. Not executing.");
        return;
    }

    `TILOG("Executing action '" $ Tuple.ActionName $ "'");
    Action.Apply(ViewerOwnedUnit, none);
}