class X2TwitchEventActionTemplate_TargetsUnits extends X2TwitchEventActionTemplate
    abstract;

enum eTwitch_UnitSelectionCriteria {
    //eTwitchUSC_ClosestToObjective,
    //eTwitchUSC_FurthestFromObjective,
    eTwitchUSC_HighestHP,
    eTwitchUSC_LowestHP,
    eTwitchUSC_Random
};

var config array<eTeam> UnitTeams;
var config eTwitch_UnitSelectionCriteria SelectBasedOn;
var config bool IncludeCivilians;
var config bool IncludeConcealed;
var config bool IncludeDead;
var config bool IncludeLiving;
var config int NumTargets;

function bool IsValid(optional XComGameState_Unit InvokingUnit) {
    local array<XComGameState_Unit> Targets;
    Targets = FindTargets(InvokingUnit);
    return Targets.Length > 0;
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

protected function bool GiveAndActivateAbility(Name AbilityName, XComGameState_Unit TargetUnit) {
    class'X2TwitchUtils'.static.GiveAbilityToUnit(AbilityName, TargetUnit);

    return class'XComGameStateContext_Ability'.static.ActivateAbilityByTemplateName(TargetUnit.GetReference(), AbilityName, TargetUnit.GetReference());
}

// Override this function in child classes for custom targeting logic
protected function bool IsValidTarget(XComGameState_Unit Unit) {
    if (!MatchesTeams(Unit)) {
        return false;
    }

    if (Unit.IsCivilian() && !IncludeCivilians) {
        return false;
    }

    if (Unit.IsDead() && !IncludeDead) {
        return false;
    }

    if (!Unit.IsDead() && !IncludeLiving) {
        return false;
    }

    if (Unit.IsConcealed() != IncludeConcealed) {
        return false;
    }

    return true;
}

private function bool MatchesTeams(XComGameState_Unit Unit) {
    return UnitTeams.Length == 0 || UnitTeams.Find(Unit.GetTeam()) != INDEX_NONE;
}