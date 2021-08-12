class X2Effect_Twitch_Invincible extends X2Effect_Persistent;

static function X2Effect_Twitch_Invincible CreateInvincibleStatusEffect() {
	local X2Effect_Twitch_Invincible InvincibleEffect;
	local X2Condition_UnitProperty UnitPropCondition;

	InvincibleEffect = new class'X2Effect_Twitch_Invincible';
	InvincibleEffect.EffectName = 'Invincible';
	InvincibleEffect.BuildPersistentEffect(1,, false,,eGameRule_PlayerTurnBegin);
	InvincibleEffect.SetDisplayInfo(ePerkBuff_Bonus, "Invincible", "This unit is immune to all damage and negative status effects.", "img:///UILibrary_PerkIcons.UIPerk_absorption_fields");
	InvincibleEffect.VisualizationFn = InvincibleVisualization;
	InvincibleEffect.bRemoveWhenTargetDies = true;
	InvincibleEffect.DuplicateResponse = eDupe_Ignore;
	InvincibleEffect.EffectAppliedEventName = 'TI_InvincibleEffectAdded';

	UnitPropCondition = new class'X2Condition_UnitProperty';
	UnitPropCondition.ExcludeFriendlyToSource = false;
	InvincibleEffect.TargetConditions.AddItem(UnitPropCondition);

	return InvincibleEffect;
}

static function InvincibleVisualization(XComGameState VisualizeGameState, out VisualizationActionMetadata ActionMetadata, const name EffectApplyResult) {
	local X2Action_PlaySoundAndFlyOver SoundAndFlyOver;

	if (EffectApplyResult != 'AA_Success') {
		return;
    }

	if (!ActionMetadata.StateObject_NewState.IsA('XComGameState_Unit')) {
		return;
    }

    // TODO: localize strings, vary color based on unit team
	SoundAndFlyOver = X2Action_PlaySoundAndFlyOver(class'X2Action_PlaySoundAndFlyOver'.static.AddToVisualizationTree(ActionMetadata, VisualizeGameState.GetContext(), false, ActionMetadata.LastActionAdded));
	SoundAndFlyOver.SetSoundAndFlyOverParameters(None, "Invincible", '', eColor_Good);
}

function bool ChangeHitResultForTarget(XComGameState_Effect EffectState, XComGameState_Unit Attacker, XComGameState_Unit TargetUnit, XComGameState_Ability AbilityState,
                                       bool bIsPrimaryTarget, const EAbilityHitResult CurrentResult, out EAbilityHitResult NewHitResult) {
    NewHitResult = eHit_Success;

    return true;
}

function bool ProvidesDamageImmunity(XComGameState_Effect EffectState, name DamageType) {
    // Complete immunity to everything
    return true;
}
