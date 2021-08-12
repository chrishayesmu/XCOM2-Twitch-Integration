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
        `LOG("Adding alias " $ Tuple.Alias, , 'TwitchIntegration');

        Aliases.AddItem(Tuple.Alias);
    }

    CommandAliases = Aliases;
    `LOG("CommandAliases length: " $ CommandAliases.Length);
}

function Handle(TwitchStateManager StateMgr, TwitchMessage Command, TwitchViewer Viewer) {
    local string Alias;

    local TCH_ActionTuple Tuple;
    local X2TwitchEventActionTemplate Action;
    local XComGameState_Unit ViewerOwnedUnit;

    // Remove leading exclamation point and find the alias we were invoked with
    Alias = Mid(Command.Body, 1, Instr(Command.Body, " ") - 1);
    `LOG("Looking for ActionTuple with the alias: " $ Alias, , 'TwitchIntegration');

    // Figure out which tuple is being invoked
    foreach ActionTuples(Tuple) {
        if (Tuple.Alias != Alias) {
            continue;
        }

        `LOG("Found a matching ActionTuple with the action name " $ Tuple.ActionName);

        if (Tuple.bMustBeSub && !Viewer.bIsSub) {
            `LOG("Viewer is not a sub and cannot use this command", , 'TwitchIntegration');
            return;
        }

        if (Tuple.CostInBits > Command.NumBits) {
            `LOG("Not enough bits sent to use command; require " $ Tuple.CostInBits $ " but received " $ Command.NumBits, , 'TwitchIntegration');
            return;
        }

        Action = class'X2TwitchUtils'.static.GetTwitchEventActionTemplate(Tuple.ActionName);

        if (Action == none) {
            `LOG("Didn't find an action called " $ Tuple.ActionName $ ". This command may be misconfigured.", , 'TwitchIntegration');
            return;
        }

        break;
    }

    if (Action == none) {
        `LOG("Never found an alias matching " $ Alias $ ", which should be impossible", , 'TwitchIntegration');
        return;
    }

    ViewerOwnedUnit = class'X2TwitchUtils'.static.FindUnitOwnedByViewer(Viewer.Login);

    if (!Action.IsValid(ViewerOwnedUnit)) {
        `LOG("Action '" $ Tuple.ActionName $ "' is not presently valid. Not executing.", , 'TwitchIntegration');
        return;
    }

    `LOG("Executing action '" $ Tuple.ActionName $ "'");
    Action.Apply(ViewerOwnedUnit, none);
}