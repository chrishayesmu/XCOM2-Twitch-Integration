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
var config array<name> RequireNotImmuneToDamageTypes;
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

    `TILOG("BuildDefaultVisualization");

	foreach VisualizeGameState.IterateByClassType(class'XComGameState_Unit', UnitCurrentState) {
        UnitPreviousState = XComGameState_Unit(History.GetGameStateForObjectID(UnitCurrentState.ObjectID, eReturnType_Reference, VisualizeGameState.HistoryIndex - 1));
        `TILOG("BuildDefaultVisualization: UnitCurrentState = " $ UnitCurrentState $ "; UnitPreviousState = " $ UnitPreviousState);

        ActionMetadata = EmptyMetaData;

        ActionMetadata.StateObject_OldState = UnitPreviousState;
        ActionMetadata.StateObject_NewState = UnitCurrentState;
        ActionMetadata.VisualizeActor = History.GetVisualizer(UnitCurrentState.ObjectID);

        if (bHasPerUnitFlyover) {
            GetFlyoverParams(VisualizeGameState, UnitPreviousState, UnitCurrentState, FlyoverParams);

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
    local int I;

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
    if (SelectBasedOn == eTwitchUSC_Random) {
        while (Targets.Length < NumTargets && ValidTargets.Length > 0) {
            I = Rand(ValidTargets.Length);
            Targets.AddItem(ValidTargets[I]);
            ValidTargets.Remove(I, 1);
        }
    }
    else if (SelectBasedOn == eTwitchUSC_HighestHP || SelectBasedOn == eTwitchUSC_LowestHP) {
        ValidTargets.Sort(SortUnitsByCurrentHp);

        I = (SelectBasedOn == eTwitchUSC_LowestHP) ? 0 : ValidTargets.Length - 1;

        while (Targets.Length < NumTargets && ValidTargets.Length > 0) {
            Targets.AddItem(ValidTargets[I]);
            ValidTargets.Remove(I, 1);
        }
    }
    else if (SelectBasedOn == eTwitchUSC_LeastHPMissing || SelectBasedOn == eTwitchUSC_MostHPMissing) {
        ValidTargets.Sort(SortUnitsByMissingHp);

        I = (SelectBasedOn == eTwitchUSC_LeastHPMissing) ? 0 : ValidTargets.Length - 1;

        while (Targets.Length < NumTargets && ValidTargets.Length > 0) {
            Targets.AddItem(ValidTargets[I]);
            ValidTargets.Remove(I, 1);
        }
    }

    return Targets;
}

protected function GetFlyoverParams(XComGameState VisualizeGameState, XComGameState_Unit PreviousUnitState, XComGameState_Unit CurrentUnitState, out TwitchActionFlyoverParams FlyoverParams) {
}

protected function bool GiveAndActivateAbility(Name AbilityName, XComGameState_Unit TargetUnit) {
    class'X2TwitchUtils'.static.GiveAbilityToUnit(AbilityName, TargetUnit);

    return class'XComGameStateContext_Ability'.static.ActivateAbilityByTemplateName(TargetUnit.GetReference(), AbilityName, TargetUnit.GetReference());
}

// Override this function in child classes for custom targeting logic
protected function bool IsValidTarget(XComGameState_Unit Unit) {
    local int I;

    if (Unit.GetMyTemplate().bIsCosmetic) {
        `TILOG("Unit is cosmetic");
        return false;
    }

    if (!MatchesTeams(Unit)) {
        `TILOG("Unit team does not match: " $ `SHOWVAR(Unit.GetTeam()));
        return false;
    }

    if (Unit.IsCivilian() && !IncludeCivilians) {
        `TILOG("Unit civilian status does not match: " $ `SHOWVAR(Unit.IsCivilian()));
        return false;
    }

    if (Unit.IsDead() && !IncludeDead) {
        `TILOG("Unit IsDead does not match: " $ `SHOWVAR(Unit.IsDead()) $ ", " $ `SHOWVAR(IncludeDead));
        return false;
    }

    if (!Unit.IsDead() && !IncludeLiving) {
        `TILOG("Unit IsDead does not match: " $ `SHOWVAR(Unit.IsDead()) $ ", " $ `SHOWVAR(IncludeLiving));
        return false;
    }

    if (Unit.IsConcealed() && !IncludeConcealed) {
        `TILOG("Unit IsConcealed does not match: " $ `SHOWVAR(Unit.IsConcealed()) $ ", " $ `SHOWVAR(IncludeConcealed));
        return false;
    }

    for (I = 0; I < RequireNotImmuneToDamageTypes.Length; I++) {
        if (Unit.IsImmuneToDamage(RequireNotImmuneToDamageTypes[I])) {
            `TILOG("Unit is immune to " $ RequireNotImmuneToDamageTypes[I] $ " damage");
            return false;
        }
    }

    return true;
}

private function bool MatchesTeams(XComGameState_Unit Unit) {
    return UnitTeams.Length == 0 || UnitTeams.Find(Unit.GetTeam()) != INDEX_NONE;
}

// Sorts units so that lower HP means a lower index in the array.
private function int SortUnitsByCurrentHp(XComGameState_Unit A, XComGameState_Unit B) {
    local int HpA, HpB;

    HpA = A.GetCurrentStat(eStat_HP);
    HpB = B.GetCurrentStat(eStat_HP);

	if (HpA < HpB) {
		return 1;
	}
	else if (HpA > HpB) {
		return -1;
	}
	else {
		return 0;
	}
}

// Sorts units so that less missing HP means a lower index in the array.
private function int SortUnitsByMissingHp(XComGameState_Unit A, XComGameState_Unit B) {
    local int MissingHpA, MissingHpB;

    MissingHpA = Max(0, A.GetMaxStat(eStat_HP) - A.GetCurrentStat(eStat_HP));
    MissingHpB = Max(0, B.GetMaxStat(eStat_HP) - B.GetCurrentStat(eStat_HP));

	if (MissingHpA < MissingHpB) {
		return 1;
	}
	else if (MissingHpA > MissingHpB) {
		return -1;
	}
	else {
		return 0;
	}
}