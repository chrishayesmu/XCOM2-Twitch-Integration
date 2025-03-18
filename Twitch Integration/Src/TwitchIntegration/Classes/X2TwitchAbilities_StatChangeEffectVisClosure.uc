// Provides a closure for holding data about how to visualize stat change effects.
class X2TwitchAbilities_StatChangeEffectVisClosure extends Object;

var int StatChangeAmount;
var EWidgetColor FlyoverColor;
var string FlyoverIcon;
var string FlyoverText;

function StatChangeEffectVisualization(XComGameState VisualizeGameState, out VisualizationActionMetadata ActionMetadata, const name EffectApplyResult)
{
	local XComGameState_Unit UnitState;
    local string Text;

	if (EffectApplyResult != 'AA_Success')
	{
		return;
	}

	UnitState = XComGameState_Unit(ActionMetadata.StateObject_NewState);

	if (UnitState != none)
	{
        Text = Repl(FlyoverText, "<Amount/>", StatChangeAmount);
		class'X2StatusEffects'.static.AddEffectSoundAndFlyOverToTrack(ActionMetadata, VisualizeGameState.GetContext(), Text, '', FlyoverColor, FlyoverIcon);
	}
}

defaultproperties
{
    FlyoverColor=eColor_Good
    FlyoverIcon="img:///UILibrary_Common.status_default"
}