class X2Effect_Twitch_ScaleUnit extends X2Effect_Persistent;

var float ChangeInScale;

static function X2Effect_Twitch_ScaleUnit CreateScaleUnitEffect(float ChangeInScale) {
	local X2Effect_Twitch_ScaleUnit ScaleUnitEffect;
	local X2Condition_UnitProperty UnitPropCondition;

	ScaleUnitEffect = new class'X2Effect_Twitch_ScaleUnit';
	ScaleUnitEffect.EffectName = 'ScaleUnitMesh';
    ScaleUnitEffect.ChangeInScale = ChangeInScale;
	ScaleUnitEffect.BuildPersistentEffect(1,, false,,eGameRule_PlayerTurnBegin);
	ScaleUnitEffect.SetDisplayInfo(ePerkBuff_Bonus, "Scale Changed", "TODO", "img:///UILibrary_PerkIcons.UIPerk_absorption_fields");
	ScaleUnitEffect.VisualizationFn = ScaleUnitVisualization;
	ScaleUnitEffect.bRemoveWhenTargetDies = false;
	ScaleUnitEffect.DuplicateResponse = eDupe_Ignore;
	ScaleUnitEffect.EffectAppliedEventName = 'ScaleUnitEffectAdded';

	UnitPropCondition = new class'X2Condition_UnitProperty';
	UnitPropCondition.ExcludeFriendlyToSource = false;
	ScaleUnitEffect.TargetConditions.AddItem(UnitPropCondition);

	return ScaleUnitEffect;
}

static function ScaleUnitVisualization(XComGameState VisualizeGameState, out VisualizationActionMetadata ActionMetadata, const name EffectApplyResult) {
    local X2Action_Twitch_SetUnitScale ScaleAction;
    local X2Effect_Twitch_ScaleUnit ScaleEffect;
	local XComGameState_Effect EffectState;

	if (EffectApplyResult != 'AA_Success') {
		return;
    }

	if (!ActionMetadata.StateObject_NewState.IsA('XComGameState_Unit')) {
		return;
    }

	foreach VisualizeGameState.IterateByClassType(class'XComGameState_Effect', EffectState) {
        ScaleEffect = X2Effect_Twitch_ScaleUnit(EffectState.GetX2Effect());

        if (ScaleEffect != none) {
            break;
        }
    }

    if (ScaleEffect == none) {
        return;
    }

    // Add scale action
    ScaleAction = X2Action_Twitch_SetUnitScale(class'X2Action_Twitch_SetUnitScale'.static.AddToVisualizationTree(ActionMetadata, VisualizeGameState.GetContext(), false, ActionMetadata.LastActionAdded));
    ScaleAction.AddedScale = ScaleEffect.ChangeInScale;
}