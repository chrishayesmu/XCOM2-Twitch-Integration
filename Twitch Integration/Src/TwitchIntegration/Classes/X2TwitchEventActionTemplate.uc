class X2TwitchEventActionTemplate extends X2DataTemplate
    config(TwitchActions)
    abstract;

function Apply(optional XComGameState_Unit InvokingUnit, optional bool ForceUseProvidedUnit = false);

/// <summary>
/// Determines if this Action is valid based on the current game state. If a unit is provided, that unit's state
/// should be checked; otherwise the Action should use its own logic for deciding which (if any) units are relevant.
/// </summary>
/// <param name="InvokingUnit">The unit to apply this action to, if any.</param>
/// <param name="ForceUseProvidedUnit">If true, this action should NOT select any other unit than InvokingUnit as its
/// target, even if it would ordinarily do so, and even if InvokingUnit is none.</param>
/// <returns>True if this Action is valid and could be executed right now.</returns>
function bool IsValid(optional XComGameState_Unit InvokingUnit, optional bool ForceUseProvidedUnit = false);