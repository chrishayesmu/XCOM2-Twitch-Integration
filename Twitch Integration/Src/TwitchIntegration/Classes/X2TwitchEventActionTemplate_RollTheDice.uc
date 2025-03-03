class X2TwitchEventActionTemplate_RollTheDice extends X2TwitchEventActionTemplate_TargetsUnits;

struct WeightedActionCfg {
    var name Action;
    var int Weight;
};

struct WeightedAction {
    var X2TwitchEventActionTemplate Template;
    var int Weight;
};

var config array<WeightedActionCfg> PossibleActionsCfg;

var privatewrite array<WeightedAction> PossibleActions;

// This action is valid as long as any of its subactions are valid
function bool IsValid(optional XComGameState_Unit InvokingUnit) {
    local WeightedAction Action;

    `TILOG("IsValid");

    CacheTemplates();

    foreach PossibleActions(Action) {
        if (Action.Template.IsValid(InvokingUnit)) {
            return true;
        }
    }

    `TILOG("No action templates were valid");
    return false;
}

function Apply(optional XComGameState_Unit InvokingUnit) {
    local int CurWeight, TargetWeight, TotalWeight;
    local WeightedAction Action, RolledAction;
    local array<WeightedAction> ValidActions;

    CacheTemplates();

    `TILOG("RollTheDice: Apply");

    TotalWeight = 0;

    // RollTheDice always targets the unit that invoked it
    foreach PossibleActions(Action) {
        if (Action.Template.IsValid(InvokingUnit)) {
            ValidActions.AddItem(Action);
            TotalWeight += Action.Weight;
        }
    }

    if (ValidActions.Length == 0) {
        `TILOG("No valid templates were found for unit " $ InvokingUnit);
        return;
    }

    TargetWeight = Rand(TotalWeight);

    foreach ValidActions(Action) {
        if (CurWeight <= TargetWeight && TargetWeight < CurWeight + Action.Weight) {
            RolledAction = Action;
            break;
        }

        CurWeight += Action.Weight;
    }

    if (RolledAction.Template == none) {
        RolledAction = ValidActions[ValidActions.Length - 1];
    }

    `TILOG("Applying template " $ RolledAction.Template.DataName);
    RolledAction.Template.Apply(InvokingUnit);
}

private function CacheTemplates() {
    local WeightedAction Action;
    local X2TwitchEventActionTemplateManager TemplateMgr;
    local int Index;

    // Check if they're already cached
    if (PossibleActions.Length > 0) {
        `TILOG("Templates already cached, returning");
        return;
    }

    TemplateMgr = class'X2TwitchEventActionTemplateManager'.static.GetTwitchEventActionTemplateManager();

    for (Index = 0; Index < PossibleActionsCfg.Length; Index++) {
        // Don't bother caching templates that will never be drawn
        if (PossibleActionsCfg[Index].Weight <= 0) {
            `TILOG("Possible action " $ PossibleActionsCfg[Index].Action $ " has no weight, skipping");
            continue;
        }

        Action.Template = TemplateMgr.FindTwitchEventActionTemplate(PossibleActionsCfg[Index].Action);
        Action.Weight = PossibleActionsCfg[Index].Weight;

        if (Action.Template == none) {
            `TILOG("ERROR: Could not load action named '" $ PossibleActionsCfg[Index].Action $ "'. This is likely a configuration error.");
            continue;
        }

        `TILOG("Added possible action " $ PossibleActionsCfg[Index].Action);
        PossibleActions.AddItem(Action);
    }
}