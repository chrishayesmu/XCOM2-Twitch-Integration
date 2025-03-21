class TwitchChatCommand_ExecuteAction extends TwitchChatCommand;

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
    local int I, J;

    // This command ignores any aliases set in config, in favor of ones defined in ActionTuples.
    // All aliases are lowercased, as expected by TwitchEventHandler_ChatCommand.
    CommandAliases.Length = 0;

    for (I = 0; I < ActionTuples.Length; I++) {
        for (J = 0; J < ActionTuples[I].Aliases.Length; J++) {
            ActionTuples[I].Aliases[J] = Locs(ActionTuples[I].Aliases[J]);

            `TILOG("Tuple: ActionName = " $ Tuple.ActionName $ ", Alias = " $ ActionTuples[I].Aliases[J]);
            Aliases.AddItem(ActionTuples[I].Aliases[J]);
        }
    }

    CommandAliases = Aliases;
}

function bool Invoke(string CommandAlias, string Body, array<EmoteData> Emotes, string MessageId, TwitchChatter Viewer) {
    local string Alias;
    local TCH_ActionTuple Tuple;
    local X2TwitchEventActionTemplate Action;
    local XComGameState_Unit ViewerOwnedUnit;

    // Remove leading exclamation point and find the alias we were invoked with
    Alias = Locs(CommandAlias);

    // Figure out which tuple is being invoked
    foreach ActionTuples(Tuple) {
        if (Tuple.Aliases.Find(Alias) == INDEX_NONE) {
            continue;
        }

        if (Tuple.bMustBeSub && Viewer.SubTier == 0) {
            `TILOG("Viewer is not a sub and cannot use this command");
            return false;
        }

        Action = class'X2TwitchUtils'.static.GetTwitchEventActionTemplate(Tuple.ActionName);

        if (Action == none) {
            `TILOG("Didn't find an action called " $ Tuple.ActionName $ ". This command may be misconfigured.");
            return false;
        }

        break;
    }

    if (Action == none) {
        `TILOG("Never found an alias matching " $ Alias $ ", which should be impossible");
        return false;
    }

    ViewerOwnedUnit = class'X2TwitchUtils'.static.FindUnitOwnedByViewer(Viewer.Login);

    if (!Action.IsValid(ViewerOwnedUnit)) {
        `TILOG("Action '" $ Tuple.ActionName $ "' is not presently valid. Not executing. Action class is " $ Action.Class);
        return false;
    }

    `TILOG("Executing action '" $ Tuple.ActionName $ "'");
    Action.Apply(ViewerOwnedUnit);

    return true;
}