/**
 * This class defines templates for all of the abilities which are needed by X2TwitchEventActionTemplates.
 */
class X2TwitchEventAbilities extends X2Ability;

static function array<X2DataTemplate> CreateTemplates()
{
	local array<X2DataTemplate> Templates;

    Templates.AddItem(CreateBurnSelfAbility());
    Templates.AddItem(CreateDisorientSelfAbility());
    Templates.AddItem(CreateKnockSelfUnconsciousAbility());
    Templates.AddItem(CreateInvincibleAbility());
    Templates.AddItem(CreatePanicSelfAbility());
    Templates.AddItem(CreateScaleSelfAbility());
    Templates.AddItem(CreateStunSelfAbility());

    return Templates;
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

static function X2DataTemplate CreateScaleSelfAbility() {
    local X2AbilityTemplate Template;
	local X2Effect_Twitch_ScaleUnit ScaleEffect;

    Template = CreateSelfTargetingAbility('Twitch_ScaleSelf');

    ScaleEffect = class'X2Effect_Twitch_ScaleUnit'.static.CreateScaleUnitEffect(0.5); // TODO use config value
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

static function X2AbilityTemplate CreateSelfTargetingAbility(Name AbilityName)
{
	local X2AbilityTemplate Template;
	local X2AbilityTarget_Self TargetSelf;

	`CREATE_X2ABILITY_TEMPLATE(Template, AbilityName);

	Template.AbilitySourceName = 'eAbilitySource_Standard';
	Template.eAbilityIconBehaviorHUD = eAbilityIconBehavior_NeverShow;
	Template.bDontDisplayInAbilitySummary = true;

	TargetSelf = new class'X2AbilityTarget_Self';
	Template.AbilityTargetStyle = TargetSelf;

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