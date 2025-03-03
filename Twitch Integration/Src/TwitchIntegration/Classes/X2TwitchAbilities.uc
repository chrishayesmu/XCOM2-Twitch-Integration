/**
 * This class defines abilities which are used throughout Twitch Integration. Most of them are self-targeting
 * buffs or debuffs that are triggered by polls or chat commands.
 */
class X2TwitchAbilities extends X2Ability;

static function array<X2DataTemplate> CreateTemplates()
{
	local array<X2DataTemplate> Templates;

    Templates.AddItem(CreateAimBuffSmallSelfAbility());
    Templates.AddItem(CreateBurnSelfAbility());
    Templates.AddItem(CreateDetonateSelfAbility('Twitch_DetonateSelf_Small', 1, 2, 50));
    Templates.AddItem(CreateDetonateSelfAbility('Twitch_DetonateSelf_Medium', 2, 4, 100));
    Templates.AddItem(CreateDetonateSelfAbility('Twitch_DetonateSelf_Large', 3, 7, 250));
    Templates.AddItem(CreateDetonateSelfAbility('Twitch_DetonateSelf_Gigantic', 7, 10000, 10000));
    Templates.AddItem(CreateDisorientSelfAbility());
    Templates.AddItem(CreateKnockSelfUnconsciousAbility());
    Templates.AddItem(CreateInvincibleAbility());
    Templates.AddItem(CreatePanicSelfAbility());
    Templates.AddItem(CreateScaleSelfLargeAbility());
    Templates.AddItem(CreateScaleSelfSmallAbility());
    Templates.AddItem(CreateStunSelfAbility());

    return Templates;
}

static function X2DataTemplate CreateAimBuffSmallSelfAbility() {
    local X2AbilityTemplate Template;
	local X2Effect_PersistentStatChange PersistentStatChangeEffect;

    Template = CreateSelfTargetingAbility('Twitch_AimBuffSmall');
    Template.FrameAbilityCameraType = eCameraFraming_Always;

    PersistentStatChangeEffect = CreateAimBuffStatusEffect(10, 2);
    PersistentStatChangeEffect.VisualizationFn = AimBuffVisualization;

    Template.AddTargetEffect(PersistentStatChangeEffect);

    return Template;
}

static function X2DataTemplate CreateBurnSelfAbility() {
    local X2AbilityTemplate Template;
	local X2Effect_Persistent BurningEffect;

    Template = CreateSelfTargetingAbility('Twitch_BurnSelf');

    BurningEffect = class'X2StatusEffects'.static.CreateBurningStatusEffect(1, 0); // TODO: use config values
	BurningEffect.VisualizationFn = BurningVisualization;

    Template.AddTargetEffect(BurningEffect);

    return Template;
}

static function X2DataTemplate CreateDisorientSelfAbility() {
    local X2AbilityTemplate Template;
	local X2Effect_Persistent DisorientedEffect;

    Template = CreateSelfTargetingAbility('Twitch_DisorientSelf');

    DisorientedEffect = class'X2StatusEffects'.static.CreateDisorientedStatusEffect(false, , false);
    Template.AddTargetEffect(DisorientedEffect);

    return Template;
}

static function X2DataTemplate CreateKnockSelfUnconsciousAbility() {
    local X2AbilityTemplate Template;
	local X2Effect_Persistent UnconsciousEffect;

    Template = CreateSelfTargetingAbility('Twitch_KnockSelfUnconscious');

    UnconsciousEffect = class'X2StatusEffects'.static.CreateUnconsciousStatusEffect();
    Template.AddTargetEffect(UnconsciousEffect);

    return Template;
}

static function X2DataTemplate CreatePanicSelfAbility() {
    local X2AbilityTemplate Template;
	local X2Effect_Panicked PanickedEffect;

    Template = CreateSelfTargetingAbility('Twitch_PanicSelf');

    PanickedEffect = class'X2StatusEffects'.static.CreatePanickedStatusEffect();
    Template.AddTargetEffect(PanickedEffect);

    return Template;
}

static function X2DataTemplate CreateScaleSelfLargeAbility() {
    local X2AbilityTemplate Template;
	local X2Effect_Twitch_ScaleUnit ScaleEffect;

    Template = CreateSelfTargetingAbility('Twitch_ScaleSelfLarge');

    ScaleEffect = class'X2Effect_Twitch_ScaleUnit'.static.CreateScaleUnitEffect(0.5);
    Template.AddTargetEffect(ScaleEffect);

    return Template;
}

static function X2DataTemplate CreateScaleSelfSmallAbility() {
    local X2AbilityTemplate Template;
	local X2Effect_Twitch_ScaleUnit ScaleEffect;

    Template = CreateSelfTargetingAbility('Twitch_ScaleSelfSmall');

    ScaleEffect = class'X2Effect_Twitch_ScaleUnit'.static.CreateScaleUnitEffect(-0.5);
    Template.AddTargetEffect(ScaleEffect);

    return Template;
}

static function X2DataTemplate CreateStunSelfAbility() {
    local X2AbilityTemplate Template;
	local X2Effect_Stunned StunnedEffect;

    Template = CreateSelfTargetingAbility('Twitch_StunSelf');

    StunnedEffect = class'X2StatusEffects'.static.CreateStunnedStatusEffect(2, 100, false);
    Template.AddTargetEffect(StunnedEffect);

    return Template;
}

static function X2DataTemplate CreateInvincibleAbility() {
    local X2AbilityTemplate Template;
	local X2Effect_Twitch_Invincible InvincibleEffect;

    Template = CreateSelfTargetingAbility('Twitch_BecomeInvincible');

    InvincibleEffect = class'X2Effect_Twitch_Invincible'.static.CreateInvincibleStatusEffect();
    Template.AddTargetEffect(InvincibleEffect);

    return Template;
}

protected static function X2DataTemplate CreateDetonateSelfAbility(name TemplateName, int RadiusInTiles, int UnitDamage, int EnvironmentDamage) {
	local X2Effect_ApplyWeaponDamage DamageEffect;
	local X2AbilityMultiTarget_Radius MultiTarget;
	local X2Condition_UnitProperty UnitPropertyCondition;
    local X2AbilityTemplate Template;
    local WeaponDamageValue DamageValue;

    Template = CreateSelfTargetingAbility(TemplateName);

	MultiTarget = new class'X2AbilityMultiTarget_Radius';
	MultiTarget.fTargetRadius = `TILESTOMETERS(RadiusInTiles);
	Template.AbilityMultiTargetStyle = MultiTarget;

    DamageValue.Damage = UnitDamage;
    DamageValue.DamageType = 'Explosion';

	DamageEffect = new class'X2Effect_ApplyWeaponDamage';
	DamageEffect.EffectDamageValue = DamageValue;
	DamageEffect.EnvironmentalDamageAmount = EnvironmentDamage;
	DamageEffect.bExplosiveDamage = true;
    DamageEffect.bIgnoreBaseDamage = true;

    Template.AddTargetEffect(DamageEffect);
	Template.AddMultiTargetEffect(DamageEffect);

    UnitPropertyCondition = new class'X2Condition_UnitProperty';
	UnitPropertyCondition.ExcludeDead = true;
	UnitPropertyCondition.ExcludeFriendlyToSource = false;
	UnitPropertyCondition.ExcludeHostileToSource = false;
	UnitPropertyCondition.FailOnNonUnits = false;
	Template.AbilityMultiTargetConditions.AddItem(UnitPropertyCondition);

	Template.FrameAbilityCameraType = eCameraFraming_Always;

	Template.SuperConcealmentLoss = 100;
	Template.LostSpawnIncreasePerUse = 250; // huge

	Template.BuildVisualizationFn = DetonateSelf_BuildVisualization;

    return Template;
}

protected static function X2AbilityTemplate CreateSelfTargetingAbility(Name AbilityName)
{
	local X2AbilityTemplate Template;

	`CREATE_X2ABILITY_TEMPLATE(Template, AbilityName);

	Template.AbilitySourceName = 'eAbilitySource_Standard';
	Template.eAbilityIconBehaviorHUD = eAbilityIconBehavior_NeverShow;
	Template.bDontDisplayInAbilitySummary = true;

	Template.AbilityTargetStyle = default.SelfTarget;

    // No target/shooter conditions; we manage all that ourselves
    // No ability trigger for the same reason
	Template.AbilityTriggers.AddItem(new class'X2AbilityTrigger_Placeholder');

	Template.AbilityToHitCalc = default.DeadEye;
	Template.bFrameEvenWhenUnitIsHidden = false;
	Template.bSkipFireAction = true;
    Template.ConcealmentRule = eConceal_AlwaysEvenWithObjective;

	Template.BuildNewGameStateFn = TypicalAbility_BuildGameState;
	Template.BuildVisualizationFn = TypicalAbility_BuildVisualization;

	return Template;
}

static function X2Effect_PersistentStatChange CreateAimBuffStatusEffect(int AimBonus, int NumTurns)
{
	local X2Effect_PersistentStatChange PersistentStatChangeEffect;

	PersistentStatChangeEffect = new class'X2Effect_PersistentStatChange';
    PersistentStatChangeEffect.EffectName = 'Twitch_AimBuffEffect';
	PersistentStatChangeEffect.DuplicateResponse = eDupe_Refresh;
    PersistentStatChangeEffect.BuildPersistentEffect(NumTurns, /* _bInfiniteDuration */ false, /* _bRemoveWhenSourceDies */ false, , eGameRule_PlayerTurnBegin);
	PersistentStatChangeEffect.SetDisplayInfo(ePerkBuff_Bonus, "Aim Boost", "Aim Boost Description", "img:///UILibrary_PerkIcons.UIPerk_advent_marktarget");
	PersistentStatChangeEffect.AddPersistentStatChange(eStat_Offense, AimBonus);
	PersistentStatChangeEffect.bRemoveWhenTargetDies = true;

	return PersistentStatChangeEffect;
}

static function AimBuffVisualization(XComGameState VisualizeGameState, out VisualizationActionMetadata ActionMetadata, const name EffectApplyResult)
{
	local XComGameState_Unit UnitState;

	if (EffectApplyResult != 'AA_Success')
	{
		return;
	}

	UnitState = XComGameState_Unit(ActionMetadata.StateObject_NewState);

	if (UnitState != none)
	{
		class'X2StatusEffects'.static.AddEffectSoundAndFlyOverToTrack(ActionMetadata, VisualizeGameState.GetContext(), "Aim Buff", '', eColor_Good, class'UIUtilities_Image'.const.UnitStatus_Marked);
		class'X2StatusEffects'.static.AddEffectMessageToTrack(
			ActionMetadata,
			"Twitch Buff Acquired",
			VisualizeGameState.GetContext(),
			"Twitch Buff",
			class'UIUtilities_Image'.const.UnitStatus_Marked,
			eUIState_Good);
	}
}

protected static function BurningVisualization(XComGameState VisualizeGameState, out VisualizationActionMetadata ActionMetadata, const name EffectApplyResult)
{
    // Copied from X2StatusEffects.BurningVisualization to add LookAtDuration
	if (EffectApplyResult != 'AA_Success')
		return;
	if (!ActionMetadata.StateObject_NewState.IsA('XComGameState_Unit'))
		return;

	class'X2StatusEffects'.static.AddEffectSoundAndFlyOverToTrack(
        ActionMetadata,
        VisualizeGameState.GetContext(),
        class'X2StatusEffects'.default.BurningFriendlyName,
        'Burning',
        eColor_Bad,
        class'UIUtilities_Image'.const.UnitStatus_Burning,
        /* LookAtDuration */ 1.0f); // TODO this isn't helping

	class'X2StatusEffects'.static.AddEffectMessageToTrack(
		ActionMetadata,
		class'X2StatusEffects'.default.BurningEffectAcquiredString,
		VisualizeGameState.GetContext(),
		class'UIEventNoticesTactical'.default.BurningTitle,
		"img:///UILibrary_PerkIcons.UIPerk_burn",
		eUIState_Bad);

	class'X2StatusEffects'.static.UpdateUnitFlag(ActionMetadata, VisualizeGameState.GetContext());
}

protected static function DetonateSelf_BuildVisualization(XComGameState VisualizeGameState) {
    local XComGameStateVisualizationMgr VisMgr;
	local X2Action_ApplyWeaponDamageToUnit UnitDamage;

	local XComGameStateContext_Ability AbilityContext;
	local X2Action_PlayEffect EffectAction;
	local VisualizationActionMetadata VisTrack;

	VisMgr = `XCOMVISUALIZATIONMGR;

    // TODO: this visualization needs to be parallel with the explosion effect, instead of queuing after
    TypicalAbility_BuildVisualization(VisualizeGameState);

	UnitDamage = X2Action_ApplyWeaponDamageToUnit( VisMgr.GetNodeOfType( VisMgr.BuildVisTree, class'X2Action_ApplyWeaponDamageToUnit' ) );

	AbilityContext = XComGameStateContext_Ability(VisualizeGameState.GetContext());

	VisTrack.StateObjectRef = AbilityContext.InputContext.SourceObject;
	VisTrack.VisualizeActor = `XCOMHISTORY.GetVisualizer(VisTrack.StateObjectRef.ObjectID);

	EffectAction = X2Action_PlayEffect(class'X2Action_PlayEffect'.static.AddToVisualizationTree(VisTrack, AbilityContext, false, UnitDamage.ParentActions[0]));
    EffectAction.EffectName = "FX_Explosion_Claymore.P_Claymore_Shrapnel_Explosion";
	`CONTENT.RequestGameArchetype(EffectAction.EffectName);

	EffectAction.EffectLocation = AbilityContext.InputContext.TargetLocations[0];
	EffectAction.EffectRotation = Rotator(vect(0, 0, 1));
	EffectAction.bWaitForCompletion = false;
	EffectAction.bWaitForCameraCompletion = false;
}