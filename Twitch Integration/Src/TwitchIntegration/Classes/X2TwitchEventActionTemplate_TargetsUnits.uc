class X2TwitchEventActionTemplate_TargetsUnits extends X2TwitchEventActionTemplate
    abstract;

enum eTwitch_UnitSelectionCriteria {
    //eTwitchUSC_ClosestToObjective,
    //eTwitchUSC_FurthestFromObjective,

    eTwitchUSC_HighestHP,
    eTwitchUSC_LowestHP,

    eTwitchUSC_LeastHPMissing,
    eTwitchUSC_MostHPMissing,

    eTwitchUSC_Random
};

struct TwitchActionFlyoverParams {
    var string Icon;
    var string Text;
    var float Duration;
    var SoundCue Sound;
    var EWidgetColor Color;

    structdefaultproperties
    {
        Icon=""
        Text=""
        Duration=1.0
        Sound=none
        Color=eColor_XCom
    }
};

var config array<eTeam> UnitTeams;
var config eTwitch_UnitSelectionCriteria SelectBasedOn;
var config bool IncludeCivilians;
var config bool IncludeConcealed;
var config bool IncludeDead;
var config bool IncludeLiving;
var config int NumTargets;

var protectedwrite bool bHasPerUnitFlyover; // Set to true in subclasses to have flyovers automatically created

function bool IsValid(optional XComGameState_Unit InvokingUnit) {
    local array<XComGameState_Unit> Targets;
    Targets = FindTargets(InvokingUnit);
    return Targets.Length > 0;
}

protected function BuildDefaultVisualization(XComGameState VisualizeGameState) {
    local TwitchActionFlyoverParams FlyoverParams;
    local VisualizationActionMetadata ActionMetadata, EmptyMetadata;
	local X2Action_PlaySoundAndFlyOver SoundAndFlyover;
    local XComGameStateContext Context;
	local XComGameStateHistory History;
    local XComGameState_Unit UnitCurrentState, UnitPreviousState;

    History = `XCOMHISTORY;
	Context = VisualizeGameState.GetContext();

	foreach VisualizeGameState.IterateByClassType(class'XComGameState_Unit', UnitCurrentState) {
        UnitPreviousState = XComGameState_Unit(History.GetGameStateForObjectID(UnitCurrentState.ObjectID, eReturnType_Reference, VisualizeGameState.HistoryIndex - 1));

        ActionMetadata = EmptyMetaData;

        ActionMetadata.StateObject_OldState = UnitPreviousState;
        ActionMetadata.StateObject_NewState = UnitCurrentState;
        ActionMetadata.VisualizeActor = History.GetVisualizer(UnitCurrentState.ObjectID);

        if (bHasPerUnitFlyover) {
            GetFlyoverParams(UnitPreviousState, UnitCurrentState, FlyoverParams);

            if (FlyoverParams.Text != "") {
                SoundAndFlyOver = X2Action_PlaySoundAndFlyOver(class'X2Action_PlaySoundAndFlyOver'.static.AddToVisualizationTree(ActionMetadata, Context));
                SoundAndFlyOver.SetSoundAndFlyOverParameters(FlyoverParams.Sound, FlyoverParams.Text, '', FlyoverParams.Color, FlyoverParams.Icon, FlyoverParams.Duration);
            }
        }
    }
}

protected function array<XComGameState_Unit> FindTargets(XComGameState_Unit InvokingUnit) {
    local array<XComGameState_Unit> ValidTargets;
    local array<XComGameState_Unit> Targets;
    local XComGameState_Unit Unit;

    // If an invoking unit is provided (e.g. through a chat command),
    // it is always the only target
    if (InvokingUnit != none) {
        if (IsValidTarget(InvokingUnit)) {
            Targets.AddItem(InvokingUnit);
        }

        return Targets;
    }

    // Find every unit which is possible as a target
    foreach `XCOMHISTORY.IterateByClassType(class'XComGameState_Unit', Unit) {
        if (!IsValidTarget(Unit)) {
            continue;
        }

        ValidTargets.AddItem(Unit);
    }

    // Prioritize targets
    // TODO: use SelectBasedOn and actually prioritize
    foreach ValidTargets(Unit) {
        Targets.AddItem(Unit);

        if (Targets.Length == NumTargets) {
            break;
        }
    }

    return Targets;
}

protected function GetFlyoverParams(XComGameState_Unit PreviousUnitState, XComGameState_Unit CurrentUnitState, out TwitchActionFlyoverParams FlyoverParams) {
}

protected function bool GiveAndActivateAbility(Name AbilityName, XComGameState_Unit TargetUnit) {
    class'X2TwitchUtils'.static.GiveAbilityToUnit(AbilityName, TargetUnit);

    return class'XComGameStateContext_Ability'.static.ActivateAbilityByTemplateName(TargetUnit.GetReference(), AbilityName, TargetUnit.GetReference());
}

// Override this function in child classes for custom targeting logic
protected function bool IsValidTarget(XComGameState_Unit Unit) {
    if (!MatchesTeams(Unit)) {
        `TILOGCLS("Unit team does not match: " $ `SHOWVAR(Unit.GetTeam()));
        return false;
    }

    if (Unit.IsCivilian() && !IncludeCivilians) {
        `TILOGCLS("Unit civilian status does not match: " $ `SHOWVAR(Unit.IsCivilian()));
        return false;
    }

    if (Unit.IsDead() && !IncludeDead) {
        `TILOGCLS("Unit IsDead does not match: " $ `SHOWVAR(Unit.IsDead()) $ ", " $ `SHOWVAR(IncludeDead));
        return false;
    }

    if (!Unit.IsDead() && !IncludeLiving) {
        `TILOGCLS("Unit IsDead does not match: " $ `SHOWVAR(Unit.IsDead()) $ ", " $ `SHOWVAR(IncludeLiving));
        return false;
    }

    if (Unit.IsConcealed() && !IncludeConcealed) {
        `TILOGCLS("Unit IsConcealed does not match: " $ `SHOWVAR(Unit.IsConcealed()) $ ", " $ `SHOWVAR(IncludeConcealed));
        return false;
    }

    return true;
}

private function bool MatchesTeams(XComGameState_Unit Unit) {
    return UnitTeams.Length == 0 || UnitTeams.Find(Unit.GetTeam()) != INDEX_NONE;
}