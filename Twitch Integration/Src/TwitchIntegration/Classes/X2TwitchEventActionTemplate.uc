class X2TwitchEventActionTemplate extends X2DataTemplate
    config(TwitchActions)
    abstract;

struct TwitchActionEntry {
    var name ActionName;  // Name of the action template to use
    var int Weight;       // Individual weight in a situation where the action is selected randomly from a pool
};

function Apply(optional XComGameState_Unit InvokingUnit);

/// <summary>
/// Determines if this Action is valid based on the current game state. If a unit is provided, that unit's state
/// should be checked; otherwise the Action should use its own logic for deciding which (if any) units are relevant.
/// </summary>
/// <returns>True if this Action is valid and could be executed right now.</returns>
function bool IsValid(optional XComGameState_Unit InvokingUnit);