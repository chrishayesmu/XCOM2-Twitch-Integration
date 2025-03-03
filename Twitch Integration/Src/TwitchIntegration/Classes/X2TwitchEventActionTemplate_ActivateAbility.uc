class X2TwitchEventActionTemplate_ActivateAbility extends X2TwitchEventActionTemplate_TargetsUnits;

var config Name AbilityName;

function Apply(optional XComGameState_Unit InvokingUnit) {
    local array<XComGameState_Unit> Targets;
    local XComGameState_Unit Unit;
    local array<Vector> TargetLocations;

    Targets = FindTargets(InvokingUnit);

    `TILOG("Applying ActivateAbility action to " $ Targets.Length $ " targets");
    foreach Targets(Unit) {
        `TILOG("Target: " $ Unit.GetFullName());
        TargetLocations.Length = 0;
        TargetLocations.AddItem(Unit.GetVisualizer().Location);

        class'X2TwitchUtils'.static.GiveAbilityToUnit(AbilityName, Unit, /* NewGameState */, /* TurnsUntilAbilityExpires */ 1);
        class'XComGameStateContext_Ability'.static.ActivateAbilityByTemplateName(Unit.GetReference(), AbilityName, Unit.GetReference(), TargetLocations);
    }
}