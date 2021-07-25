class X2TwitchEventActionTemplate_ActivateAbility extends X2TwitchEventActionTemplate_TargetsUnits;

var config Name AbilityName;

function Apply(optional XComGameState_Unit InvokingUnit, optional XComGameState_TwitchEventPoll PollGameState) {
    local array<XComGameState_Unit> Targets;
    local XComGameState_Unit Unit;

    Targets = FindTargets(InvokingUnit);

    foreach Targets(Unit) {
        class'X2TwitchUtils'.static.GiveAbilityToUnit(AbilityName, Unit, /* NewGameState */, /* TurnsUntilAbilityExpires */ 1);
        class'XComGameStateContext_Ability'.static.ActivateAbilityByTemplateName(Unit.GetReference(), AbilityName, Unit.GetReference());
    }
}
