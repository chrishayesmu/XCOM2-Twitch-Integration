class X2TwitchEventActionTemplate_ActivateAbility extends X2TwitchEventActionTemplate_TargetsUnits;

var config Name AbilityName;
var config int TurnsUntilAbilityExpires;

function Apply(optional XComGameState_Unit InvokingUnit, optional bool ForceUseProvidedUnit = false) {
    local array<XComGameState_Unit> Targets;
    local XComGameState_Unit Unit;
    local array<Vector> TargetLocations;

    Targets = FindTargets(InvokingUnit, ForceUseProvidedUnit);

    `TILOG("Applying ActivateAbility action to " $ Targets.Length $ " targets");

    foreach Targets(Unit) {
        TargetLocations.Length = 0;
        TargetLocations.AddItem(Unit.GetVisualizer().Location);

        class'X2TwitchUtils'.static.GiveAbilityToUnit(AbilityName, Unit, /* NewGameState */ none, TurnsUntilAbilityExpires);

        class'XComGameStateContext_Ability'.static.ActivateAbilityByTemplateName(Unit.GetReference(), AbilityName, Unit.GetReference(), TargetLocations);
    }
}