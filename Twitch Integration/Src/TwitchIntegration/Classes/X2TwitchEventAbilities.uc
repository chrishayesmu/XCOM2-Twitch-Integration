/**
 * This class defines templates for all of the abilities which are needed by X2TwitchEventActionTemplates.
 */
class X2TwitchEventAbilities extends X2Ability;

var privatewrite name BurnSelfAbilityName;
var privatewrite name DisorientSelfAbilityName;
var privatewrite name KnockSelfUnconsciousAbilityName;
var privatewrite name PanicSelfAbilityName;
var privatewrite name StunSelfAbilityName;

static function array<X2DataTemplate> CreateTemplates()
{
	local array<X2DataTemplate> Templates;

    Templates.AddItem(CreateBurnSelfAbility());
    Templates.AddItem(CreateDisorientSelfAbility());
    Templates.AddItem(CreateKnockSelfUnconsciousAbility());
    Templates.AddItem(CreatePanicSelfAbility());
    Templates.AddItem(CreateStunSelfAbility());

    return Templates;
}

static function X2DataTemplate CreateBurnSelfAbility() {
    local X2AbilityTemplate Template;
	local X2Effect_Persistent BurningEffect;

    Template = CreateSelfTargetingAbility(default.BurnSelfAbilityName);

    BurningEffect = class'X2StatusEffects'.static.CreateBurningStatusEffect(1, 0); // TODO: use config values
    Template.AddTargetEffect(BurningEffect);

    return Template;
}

static function X2DataTemplate CreateDisorientSelfAbility() {
    local X2AbilityTemplate Template;
	local X2Effect_Persistent DisorientedEffect;

    Template = CreateSelfTargetingAbility(default.DisorientSelfAbilityName);

    DisorientedEffect = class'X2StatusEffects'.static.CreateDisorientedStatusEffect(false, , false);
    Template.AddTargetEffect(DisorientedEffect);

    return Template;
}

static function X2DataTemplate CreateKnockSelfUnconsciousAbility() {
    local X2AbilityTemplate Template;
	local X2Effect_Persistent UnconsciousEffect;

    Template = CreateSelfTargetingAbility(default.KnockSelfUnconsciousAbilityName);

    UnconsciousEffect = class'X2StatusEffects'.static.CreateUnconsciousStatusEffect();
    Template.AddTargetEffect(UnconsciousEffect);

    return Template;
}

static function X2DataTemplate CreatePanicSelfAbility() {
    local X2AbilityTemplate Template;
	local X2Effect_Panicked PanickedEffect;

    Template = CreateSelfTargetingAbility(default.PanicSelfAbilityName);

    PanickedEffect = class'X2StatusEffects'.static.CreatePanickedStatusEffect();
    Template.AddTargetEffect(PanickedEffect);

    return Template;
}

static function X2DataTemplate CreateStunSelfAbility() {
    local X2AbilityTemplate Template;
	local X2Effect_Stunned StunnedEffect;

    Template = CreateSelfTargetingAbility(default.StunSelfAbilityName);

    StunnedEffect = class'X2StatusEffects'.static.CreateStunnedStatusEffect(2, 100, false);
    Template.AddTargetEffect(StunnedEffect);

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
	Template.bFrameEvenWhenUnitIsHidden = true;
	Template.bSkipFireAction = true;
    Template.ConcealmentRule = eConceal_AlwaysEvenWithObjective;

	Template.BuildNewGameStateFn = TypicalAbility_BuildGameState;
	Template.BuildVisualizationFn = TypicalAbility_BuildVisualization;

	return Template;
}

defaultproperties
{
    BurnSelfAbilityName = "Twitch_BurnSelf"
    DisorientSelfAbilityName = "Twitch_DisorientSelf"
    KnockSelfUnconsciousAbilityName = "Twitch_KnockSelfUnconscious"
    PanicSelfAbilityName = "Twitch_PanicSelf"
    StunSelfAbilityName = "Twitch_StunSelf"
}