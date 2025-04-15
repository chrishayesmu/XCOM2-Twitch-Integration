/**
 * This class defines abilities which are used throughout Twitch Integration. Most of them are self-targeting
 * buffs or debuffs that are triggered by polls or chat commands.
 */
class X2TwitchAbilities extends X2Ability
    config(TwitchAbilities);

const AIM_BUFF_ICON = "img:///UILibrary_Common.status_default";
const CRIT_CHANCE_BUFF_ICON = "img:///UILibrary_Common.status_default";
const DEFENSE_BUFF_ICON = "img:///UILibrary_Common.status_default";
const DODGE_BUFF_ICON = "img:///UILibrary_Common.status_default";
const MOBILITY_BUFF_ICON = "img:///UILibrary_Common.status_default";
const SHIELD_HP_BUFF_ICON = "img:///UILibrary_Common.status_default";
const WILL_BUFF_ICON = "img:///UILibrary_Common.status_default";

var config int AimBuffSmallBonus;
var config int AimBuffSmallNumTurns;
var config int AimBuffMediumBonus;
var config int AimBuffMediumNumTurns;
var config int AimBuffLargeBonus;
var config int AimBuffLargeNumTurns;
var config int CritChanceBuffSmallBonus;
var config int CritChanceBuffSmallNumTurns;
var config int CritChanceBuffMediumBonus;
var config int CritChanceBuffMediumNumTurns;
var config int CritChanceBuffLargeBonus;
var config int CritChanceBuffLargeNumTurns;
var config int DefenseBuffSmallBonus;
var config int DefenseBuffSmallNumTurns;
var config int DefenseBuffMediumBonus;
var config int DefenseBuffMediumNumTurns;
var config int DefenseBuffLargeBonus;
var config int DefenseBuffLargeNumTurns;
var config int DodgeBuffSmallBonus;
var config int DodgeBuffSmallNumTurns;
var config int DodgeBuffMediumBonus;
var config int DodgeBuffMediumNumTurns;
var config int DodgeBuffLargeBonus;
var config int DodgeBuffLargeNumTurns;
var config int MobilityBuffSmallBonus;
var config int MobilityBuffSmallNumTurns;
var config int MobilityBuffMediumBonus;
var config int MobilityBuffMediumNumTurns;
var config int MobilityBuffLargeBonus;
var config int MobilityBuffLargeNumTurns;
var config int ShieldHpBuffSmallBonus;
var config int ShieldHpBuffSmallNumTurns;
var config int ShieldHpBuffMediumBonus;
var config int ShieldHpBuffMediumNumTurns;
var config int ShieldHpBuffLargeBonus;
var config int ShieldHpBuffLargeNumTurns;
var config int WillBuffSmallBonus;
var config int WillBuffSmallNumTurns;
var config int WillBuffMediumBonus;
var config int WillBuffMediumNumTurns;
var config int WillBuffLargeBonus;
var config int WillBuffLargeNumTurns;

var config int BurningDamage;
var config int BurningNumTurns;
var config int DetonateSelfSmallEnvironmentDamage;
var config int DetonateSelfSmallTileRadius;
var config int DetonateSelfSmallUnitDamage;
var config int DetonateSelfMediumEnvironmentDamage;
var config int DetonateSelfMediumTileRadius;
var config int DetonateSelfMediumUnitDamage;
var config int DetonateSelfLargeEnvironmentDamage;
var config int DetonateSelfLargeTileRadius;
var config int DetonateSelfLargeUnitDamage;
var config int DetonateSelfGiganticEnvironmentDamage;
var config int DetonateSelfGiganticTileRadius;
var config int DetonateSelfGiganticUnitDamage;
var config int PanicNumTurns;
var config float ScaleSelfLargeSizeChange;
var config float ScaleSelfSmallSizeChange;

var const localized string strAimBuffEffectDescription;
var const localized string strAimBuffEffectFlyoverText;
var const localized string strAimBuffEffectTitle;
var const localized string strCritChanceBuffEffectDescription;
var const localized string strCritChanceBuffEffectFlyoverText;
var const localized string strCritChanceBuffEffectTitle;
var const localized string strDefenseBuffEffectDescription;
var const localized string strDefenseBuffEffectFlyoverText;
var const localized string strDefenseBuffEffectTitle;
var const localized string strDodgeBuffEffectDescription;
var const localized string strDodgeBuffEffectFlyoverText;
var const localized string strDodgeBuffEffectTitle;
var const localized string strMobilityBuffEffectDescription;
var const localized string strMobilityBuffEffectFlyoverText;
var const localized string strMobilityBuffEffectTitle;
var const localized string strShieldHpBuffEffectDescription;
var const localized string strShieldHpBuffEffectFlyoverText;
var const localized string strShieldHpBuffEffectTitle;
var const localized string strWillBuffEffectDescription;
var const localized string strWillBuffEffectFlyoverText;
var const localized string strWillBuffEffectTitle;

static function array<X2DataTemplate> CreateTemplates()
{
	local array<X2DataTemplate> Templates;

    Templates.AddItem(CreateAimBuffSmallSelfAbility());
    Templates.AddItem(CreateAimBuffMediumSelfAbility());
    Templates.AddItem(CreateAimBuffLargeSelfAbility());
    Templates.AddItem(CreateCritChanceBuffSmallSelfAbility());
    Templates.AddItem(CreateCritChanceBuffMediumSelfAbility());
    Templates.AddItem(CreateCritChanceBuffLargeSelfAbility());
    Templates.AddItem(CreateDefenseBuffSmallSelfAbility());
    Templates.AddItem(CreateDefenseBuffMediumSelfAbility());
    Templates.AddItem(CreateDefenseBuffLargeSelfAbility());
    Templates.AddItem(CreateDodgeBuffSmallSelfAbility());
    Templates.AddItem(CreateDodgeBuffMediumSelfAbility());
    Templates.AddItem(CreateDodgeBuffLargeSelfAbility());
    Templates.AddItem(CreateMobilityBuffSmallSelfAbility());
    Templates.AddItem(CreateMobilityBuffMediumSelfAbility());
    Templates.AddItem(CreateMobilityBuffLargeSelfAbility());
    Templates.AddItem(CreateShieldHpBuffSmallSelfAbility());
    Templates.AddItem(CreateShieldHpBuffMediumSelfAbility());
    Templates.AddItem(CreateShieldHpBuffLargeSelfAbility());
    Templates.AddItem(CreateWillBuffSmallSelfAbility());
    Templates.AddItem(CreateWillBuffMediumSelfAbility());
    Templates.AddItem(CreateWillBuffLargeSelfAbility());

    Templates.AddItem(CreateBurnSelfAbility());
    Templates.AddItem(CreateDetonateSelfAbility('Twitch_DetonateSelf_Small', default.DetonateSelfSmallTileRadius, default.DetonateSelfSmallUnitDamage, default.DetonateSelfSmallEnvironmentDamage));
    Templates.AddItem(CreateDetonateSelfAbility('Twitch_DetonateSelf_Medium', default.DetonateSelfMediumTileRadius, default.DetonateSelfMediumUnitDamage, default.DetonateSelfMediumEnvironmentDamage));
    Templates.AddItem(CreateDetonateSelfAbility('Twitch_DetonateSelf_Large', default.DetonateSelfLargeTileRadius, default.DetonateSelfLargeUnitDamage, default.DetonateSelfLargeEnvironmentDamage));
    Templates.AddItem(CreateDetonateSelfAbility('Twitch_DetonateSelf_Gigantic', default.DetonateSelfGiganticTileRadius, default.DetonateSelfGiganticUnitDamage, default.DetonateSelfGiganticEnvironmentDamage));
    Templates.AddItem(CreateDisorientSelfAbility());
    Templates.AddItem(CreateFullHealSelfAbility());
    Templates.AddItem(CreateKnockSelfUnconsciousAbility());
    Templates.AddItem(CreateInvincibleAbility());
    Templates.AddItem(CreatePanicSelfAbility());
    Templates.AddItem(CreateScaleSelfLargeAbility());
    Templates.AddItem(CreateScaleSelfSmallAbility());
    Templates.AddItem(CreateStunSelfAbility());

    return Templates;
}

static function X2DataTemplate CreateAimBuffLargeSelfAbility() {
    local X2AbilityTemplate Template;
	local X2Effect_PersistentStatChange PersistentStatChangeEffect;

    Template = CreateSelfTargetingAbility('Twitch_AimBuffLarge');
    Template.FrameAbilityCameraType = eCameraFraming_Always;

    PersistentStatChangeEffect = CreateStatChangeStatusEffect('Twitch_AimBuffEffect',
                                                              eStat_Offense,
                                                              default.AimBuffLargeBonus,
                                                              default.AimBuffLargeNumTurns,
                                                              default.strAimBuffEffectTitle,
                                                              default.strAimBuffEffectDescription,
                                                              default.strAimBuffEffectFlyoverText,
                                                              AIM_BUFF_ICON);
    PersistentStatChangeEffect.EffectRank = 3;

    Template.AddTargetEffect(PersistentStatChangeEffect);

    return Template;
}

static function X2DataTemplate CreateAimBuffMediumSelfAbility() {
    local X2AbilityTemplate Template;
	local X2Effect_PersistentStatChange PersistentStatChangeEffect;

    Template = CreateSelfTargetingAbility('Twitch_AimBuffMedium');
    Template.FrameAbilityCameraType = eCameraFraming_Always;

    PersistentStatChangeEffect = CreateStatChangeStatusEffect('Twitch_AimBuffEffect',
                                                              eStat_Offense,
                                                              default.AimBuffMediumBonus,
                                                              default.AimBuffMediumNumTurns,
                                                              default.strAimBuffEffectTitle,
                                                              default.strAimBuffEffectDescription,
                                                              default.strAimBuffEffectFlyoverText,
                                                              AIM_BUFF_ICON);
    PersistentStatChangeEffect.EffectRank = 2;

    Template.AddTargetEffect(PersistentStatChangeEffect);

    return Template;
}

static function X2DataTemplate CreateAimBuffSmallSelfAbility() {
    local X2AbilityTemplate Template;
	local X2Effect_PersistentStatChange PersistentStatChangeEffect;

    Template = CreateSelfTargetingAbility('Twitch_AimBuffSmall');
    Template.FrameAbilityCameraType = eCameraFraming_Always;

    PersistentStatChangeEffect = CreateStatChangeStatusEffect('Twitch_AimBuffEffect',
                                                              eStat_Offense,
                                                              default.AimBuffSmallBonus,
                                                              default.AimBuffSmallNumTurns,
                                                              default.strAimBuffEffectTitle,
                                                              default.strAimBuffEffectDescription,
                                                              default.strAimBuffEffectFlyoverText,
                                                              AIM_BUFF_ICON);
    PersistentStatChangeEffect.EffectRank = 1;

    Template.AddTargetEffect(PersistentStatChangeEffect);

    return Template;
}

static function X2DataTemplate CreateCritChanceBuffLargeSelfAbility() {
    local X2AbilityTemplate Template;
	local X2Effect_PersistentStatChange PersistentStatChangeEffect;

    Template = CreateSelfTargetingAbility('Twitch_CritChanceBuffLarge');
    Template.FrameAbilityCameraType = eCameraFraming_Always;

    PersistentStatChangeEffect = CreateStatChangeStatusEffect('Twitch_CritChanceBuffEffect',
                                                              eStat_CritChance,
                                                              default.CritChanceBuffLargeBonus,
                                                              default.CritChanceBuffLargeNumTurns,
                                                              default.strCritChanceBuffEffectTitle,
                                                              default.strCritChanceBuffEffectDescription,
                                                              default.strCritChanceBuffEffectFlyoverText,
                                                              CRIT_CHANCE_BUFF_ICON);
    PersistentStatChangeEffect.EffectRank = 3;

    Template.AddTargetEffect(PersistentStatChangeEffect);

    return Template;
}

static function X2DataTemplate CreateCritChanceBuffMediumSelfAbility() {
    local X2AbilityTemplate Template;
	local X2Effect_PersistentStatChange PersistentStatChangeEffect;

    Template = CreateSelfTargetingAbility('Twitch_CritChanceBuffMedium');
    Template.FrameAbilityCameraType = eCameraFraming_Always;

    PersistentStatChangeEffect = CreateStatChangeStatusEffect('Twitch_CritChanceBuffEffect',
                                                              eStat_CritChance,
                                                              default.CritChanceBuffMediumBonus,
                                                              default.CritChanceBuffMediumNumTurns,
                                                              default.strCritChanceBuffEffectTitle,
                                                              default.strCritChanceBuffEffectDescription,
                                                              default.strCritChanceBuffEffectFlyoverText,
                                                              CRIT_CHANCE_BUFF_ICON);
    PersistentStatChangeEffect.EffectRank = 2;

    Template.AddTargetEffect(PersistentStatChangeEffect);

    return Template;
}

static function X2DataTemplate CreateCritChanceBuffSmallSelfAbility() {
    local X2AbilityTemplate Template;
	local X2Effect_PersistentStatChange PersistentStatChangeEffect;

    Template = CreateSelfTargetingAbility('Twitch_CritChanceBuffSmall');
    Template.FrameAbilityCameraType = eCameraFraming_Always;

    PersistentStatChangeEffect = CreateStatChangeStatusEffect('Twitch_CritChanceBuffEffect',
                                                              eStat_CritChance,
                                                              default.CritChanceBuffSmallBonus,
                                                              default.CritChanceBuffSmallNumTurns,
                                                              default.strCritChanceBuffEffectTitle,
                                                              default.strCritChanceBuffEffectDescription,
                                                              default.strCritChanceBuffEffectFlyoverText,
                                                              CRIT_CHANCE_BUFF_ICON);
    PersistentStatChangeEffect.EffectRank = 1;

    Template.AddTargetEffect(PersistentStatChangeEffect);

    return Template;
}

static function X2DataTemplate CreateDefenseBuffLargeSelfAbility() {
    local X2AbilityTemplate Template;
	local X2Effect_PersistentStatChange PersistentStatChangeEffect;

    Template = CreateSelfTargetingAbility('Twitch_DefenseBuffLarge');
    Template.FrameAbilityCameraType = eCameraFraming_Always;

    PersistentStatChangeEffect = CreateStatChangeStatusEffect('Twitch_DefenseBuffEffect',
                                                              eStat_Defense,
                                                              default.DefenseBuffLargeBonus,
                                                              default.DefenseBuffLargeNumTurns,
                                                              default.strDefenseBuffEffectTitle,
                                                              default.strDefenseBuffEffectDescription,
                                                              default.strDefenseBuffEffectFlyoverText,
                                                              DEFENSE_BUFF_ICON);
    PersistentStatChangeEffect.EffectRank = 3;

    Template.AddTargetEffect(PersistentStatChangeEffect);

    return Template;
}

static function X2DataTemplate CreateDefenseBuffMediumSelfAbility() {
    local X2AbilityTemplate Template;
	local X2Effect_PersistentStatChange PersistentStatChangeEffect;

    Template = CreateSelfTargetingAbility('Twitch_DefenseBuffMedium');
    Template.FrameAbilityCameraType = eCameraFraming_Always;

    PersistentStatChangeEffect = CreateStatChangeStatusEffect('Twitch_DefenseBuffEffect',
                                                              eStat_Defense,
                                                              default.DefenseBuffMediumBonus,
                                                              default.DefenseBuffMediumNumTurns,
                                                              default.strDefenseBuffEffectTitle,
                                                              default.strDefenseBuffEffectDescription,
                                                              default.strDefenseBuffEffectFlyoverText,
                                                              DEFENSE_BUFF_ICON);
    PersistentStatChangeEffect.EffectRank = 2;

    Template.AddTargetEffect(PersistentStatChangeEffect);

    return Template;
}

static function X2DataTemplate CreateDefenseBuffSmallSelfAbility() {
    local X2AbilityTemplate Template;
	local X2Effect_PersistentStatChange PersistentStatChangeEffect;

    Template = CreateSelfTargetingAbility('Twitch_DefenseBuffSmall');
    Template.FrameAbilityCameraType = eCameraFraming_Always;

    PersistentStatChangeEffect = CreateStatChangeStatusEffect('Twitch_DefenseBuffEffect',
                                                              eStat_Defense,
                                                              default.DefenseBuffSmallBonus,
                                                              default.DefenseBuffSmallNumTurns,
                                                              default.strDefenseBuffEffectTitle,
                                                              default.strDefenseBuffEffectDescription,
                                                              default.strDefenseBuffEffectFlyoverText,
                                                              DEFENSE_BUFF_ICON);
    PersistentStatChangeEffect.EffectRank = 1;

    Template.AddTargetEffect(PersistentStatChangeEffect);

    return Template;
}

static function X2DataTemplate CreateDodgeBuffLargeSelfAbility() {
    local X2AbilityTemplate Template;
	local X2Effect_PersistentStatChange PersistentStatChangeEffect;

    Template = CreateSelfTargetingAbility('Twitch_DodgeBuffLarge');
    Template.FrameAbilityCameraType = eCameraFraming_Always;

    PersistentStatChangeEffect = CreateStatChangeStatusEffect('Twitch_DodgeBuffEffect',
                                                              eStat_Dodge,
                                                              default.DodgeBuffLargeBonus,
                                                              default.DodgeBuffLargeNumTurns,
                                                              default.strDodgeBuffEffectTitle,
                                                              default.strDodgeBuffEffectDescription,
                                                              default.strDodgeBuffEffectFlyoverText,
                                                              DODGE_BUFF_ICON);
    PersistentStatChangeEffect.EffectRank = 3;

    Template.AddTargetEffect(PersistentStatChangeEffect);

    return Template;
}

static function X2DataTemplate CreateDodgeBuffMediumSelfAbility() {
    local X2AbilityTemplate Template;
	local X2Effect_PersistentStatChange PersistentStatChangeEffect;

    Template = CreateSelfTargetingAbility('Twitch_DodgeBuffMedium');
    Template.FrameAbilityCameraType = eCameraFraming_Always;

    PersistentStatChangeEffect = CreateStatChangeStatusEffect('Twitch_DodgeBuffEffect',
                                                              eStat_Dodge,
                                                              default.DodgeBuffMediumBonus,
                                                              default.DodgeBuffMediumNumTurns,
                                                              default.strDodgeBuffEffectTitle,
                                                              default.strDodgeBuffEffectDescription,
                                                              default.strDodgeBuffEffectFlyoverText,
                                                              DODGE_BUFF_ICON);
    PersistentStatChangeEffect.EffectRank = 2;

    Template.AddTargetEffect(PersistentStatChangeEffect);

    return Template;
}

static function X2DataTemplate CreateDodgeBuffSmallSelfAbility() {
    local X2AbilityTemplate Template;
	local X2Effect_PersistentStatChange PersistentStatChangeEffect;

    Template = CreateSelfTargetingAbility('Twitch_DodgeBuffSmall');
    Template.FrameAbilityCameraType = eCameraFraming_Always;

    PersistentStatChangeEffect = CreateStatChangeStatusEffect('Twitch_DodgeBuffEffect',
                                                              eStat_Dodge,
                                                              default.DodgeBuffSmallBonus,
                                                              default.DodgeBuffSmallNumTurns,
                                                              default.strDodgeBuffEffectTitle,
                                                              default.strDodgeBuffEffectDescription,
                                                              default.strDodgeBuffEffectFlyoverText,
                                                              DODGE_BUFF_ICON);
    PersistentStatChangeEffect.EffectRank = 1;

    Template.AddTargetEffect(PersistentStatChangeEffect);

    return Template;
}

static function X2DataTemplate CreateMobilityBuffLargeSelfAbility() {
    local X2AbilityTemplate Template;
	local X2Effect_PersistentStatChange PersistentStatChangeEffect;

    Template = CreateSelfTargetingAbility('Twitch_MobilityBuffLarge');
    Template.FrameAbilityCameraType = eCameraFraming_Always;

    PersistentStatChangeEffect = CreateStatChangeStatusEffect('Twitch_MobilityBuffEffect',
                                                              eStat_Mobility,
                                                              default.MobilityBuffLargeBonus,
                                                              default.MobilityBuffLargeNumTurns,
                                                              default.strMobilityBuffEffectTitle,
                                                              default.strMobilityBuffEffectDescription,
                                                              default.strMobilityBuffEffectFlyoverText,
                                                              MOBILITY_BUFF_ICON);
    PersistentStatChangeEffect.EffectRank = 3;

    Template.AddTargetEffect(PersistentStatChangeEffect);

    return Template;
}

static function X2DataTemplate CreateMobilityBuffMediumSelfAbility() {
    local X2AbilityTemplate Template;
	local X2Effect_PersistentStatChange PersistentStatChangeEffect;

    Template = CreateSelfTargetingAbility('Twitch_MobilityBuffMedium');
    Template.FrameAbilityCameraType = eCameraFraming_Always;

    PersistentStatChangeEffect = CreateStatChangeStatusEffect('Twitch_MobilityBuffEffect',
                                                              eStat_Mobility,
                                                              default.MobilityBuffMediumBonus,
                                                              default.MobilityBuffMediumNumTurns,
                                                              default.strMobilityBuffEffectTitle,
                                                              default.strMobilityBuffEffectDescription,
                                                              default.strMobilityBuffEffectFlyoverText,
                                                              MOBILITY_BUFF_ICON);
    PersistentStatChangeEffect.EffectRank = 2;

    Template.AddTargetEffect(PersistentStatChangeEffect);

    return Template;
}

static function X2DataTemplate CreateMobilityBuffSmallSelfAbility() {
    local X2AbilityTemplate Template;
	local X2Effect_PersistentStatChange PersistentStatChangeEffect;

    Template = CreateSelfTargetingAbility('Twitch_MobilityBuffSmall');
    Template.FrameAbilityCameraType = eCameraFraming_Always;

    PersistentStatChangeEffect = CreateStatChangeStatusEffect('Twitch_MobilityBuffEffect',
                                                              eStat_Mobility,
                                                              default.MobilityBuffSmallBonus,
                                                              default.MobilityBuffSmallNumTurns,
                                                              default.strMobilityBuffEffectTitle,
                                                              default.strMobilityBuffEffectDescription,
                                                              default.strMobilityBuffEffectFlyoverText,
                                                              MOBILITY_BUFF_ICON);
    PersistentStatChangeEffect.EffectRank = 1;

    Template.AddTargetEffect(PersistentStatChangeEffect);

    return Template;
}

static function X2DataTemplate CreateShieldHpBuffLargeSelfAbility() {
    local X2AbilityTemplate Template;
	local X2Effect_PersistentStatChange PersistentStatChangeEffect;

    Template = CreateSelfTargetingAbility('Twitch_ShieldHpBuffLarge');
    Template.FrameAbilityCameraType = eCameraFraming_Always;

    PersistentStatChangeEffect = CreateStatChangeStatusEffect('Twitch_ShieldHpBuffEffect',
                                                              eStat_ShieldHp,
                                                              default.ShieldHpBuffLargeBonus,
                                                              default.ShieldHpBuffLargeNumTurns,
                                                              default.strShieldHpBuffEffectTitle,
                                                              default.strShieldHpBuffEffectDescription,
                                                              default.strShieldHpBuffEffectFlyoverText,
                                                              SHIELD_HP_BUFF_ICON);
    PersistentStatChangeEffect.EffectRank = 3;

    Template.AddTargetEffect(PersistentStatChangeEffect);

    return Template;
}

static function X2DataTemplate CreateShieldHpBuffMediumSelfAbility() {
    local X2AbilityTemplate Template;
	local X2Effect_PersistentStatChange PersistentStatChangeEffect;

    Template = CreateSelfTargetingAbility('Twitch_ShieldHpBuffMedium');
    Template.FrameAbilityCameraType = eCameraFraming_Always;

    PersistentStatChangeEffect = CreateStatChangeStatusEffect('Twitch_ShieldHpBuffEffect',
                                                              eStat_ShieldHp,
                                                              default.ShieldHpBuffMediumBonus,
                                                              default.ShieldHpBuffMediumNumTurns,
                                                              default.strShieldHpBuffEffectTitle,
                                                              default.strShieldHpBuffEffectDescription,
                                                              default.strShieldHpBuffEffectFlyoverText,
                                                              SHIELD_HP_BUFF_ICON);
    PersistentStatChangeEffect.EffectRank = 2;

    Template.AddTargetEffect(PersistentStatChangeEffect);

    return Template;
}

static function X2DataTemplate CreateShieldHpBuffSmallSelfAbility() {
    local X2AbilityTemplate Template;
	local X2Effect_PersistentStatChange PersistentStatChangeEffect;

    Template = CreateSelfTargetingAbility('Twitch_ShieldHpBuffSmall');
    Template.FrameAbilityCameraType = eCameraFraming_Always;

    PersistentStatChangeEffect = CreateStatChangeStatusEffect('Twitch_ShieldHpBuffEffect',
                                                              eStat_ShieldHp,
                                                              default.ShieldHpBuffSmallBonus,
                                                              default.ShieldHpBuffSmallNumTurns,
                                                              default.strShieldHpBuffEffectTitle,
                                                              default.strShieldHpBuffEffectDescription,
                                                              default.strShieldHpBuffEffectFlyoverText,
                                                              SHIELD_HP_BUFF_ICON);
    PersistentStatChangeEffect.EffectRank = 1;

    Template.AddTargetEffect(PersistentStatChangeEffect);

    return Template;
}

static function X2DataTemplate CreateWillBuffLargeSelfAbility() {
    local X2AbilityTemplate Template;
	local X2Effect_PersistentStatChange PersistentStatChangeEffect;

    Template = CreateSelfTargetingAbility('Twitch_WillBuffLarge');
    Template.FrameAbilityCameraType = eCameraFraming_Always;

    PersistentStatChangeEffect = CreateStatChangeStatusEffect('Twitch_WillBuffEffect',
                                                              eStat_Will,
                                                              default.WillBuffLargeBonus,
                                                              default.WillBuffLargeNumTurns,
                                                              default.strWillBuffEffectTitle,
                                                              default.strWillBuffEffectDescription,
                                                              default.strWillBuffEffectFlyoverText,
                                                              WILL_BUFF_ICON);
    PersistentStatChangeEffect.EffectRank = 3;

    Template.AddTargetEffect(PersistentStatChangeEffect);

    return Template;
}

static function X2DataTemplate CreateWillBuffMediumSelfAbility() {
    local X2AbilityTemplate Template;
	local X2Effect_PersistentStatChange PersistentStatChangeEffect;

    Template = CreateSelfTargetingAbility('Twitch_WillBuffMedium');
    Template.FrameAbilityCameraType = eCameraFraming_Always;

    PersistentStatChangeEffect = CreateStatChangeStatusEffect('Twitch_WillBuffEffect',
                                                              eStat_Will,
                                                              default.WillBuffMediumBonus,
                                                              default.WillBuffMediumNumTurns,
                                                              default.strWillBuffEffectTitle,
                                                              default.strWillBuffEffectDescription,
                                                              default.strWillBuffEffectFlyoverText,
                                                              WILL_BUFF_ICON);
    PersistentStatChangeEffect.EffectRank = 2;

    Template.AddTargetEffect(PersistentStatChangeEffect);

    return Template;
}

static function X2DataTemplate CreateWillBuffSmallSelfAbility() {
    local X2AbilityTemplate Template;
	local X2Effect_PersistentStatChange PersistentStatChangeEffect;

    Template = CreateSelfTargetingAbility('Twitch_WillBuffSmall');
    Template.FrameAbilityCameraType = eCameraFraming_Always;

    PersistentStatChangeEffect = CreateStatChangeStatusEffect('Twitch_WillBuffEffect',
                                                              eStat_Will,
                                                              default.WillBuffSmallBonus,
                                                              default.WillBuffSmallNumTurns,
                                                              default.strWillBuffEffectTitle,
                                                              default.strWillBuffEffectDescription,
                                                              default.strWillBuffEffectFlyoverText,
                                                              WILL_BUFF_ICON);
    PersistentStatChangeEffect.EffectRank = 1;

    Template.AddTargetEffect(PersistentStatChangeEffect);

    return Template;
}

static function X2DataTemplate CreateBurnSelfAbility() {
    local X2AbilityTemplate Template;
	local X2Effect_Persistent BurningEffect;

    Template = CreateSelfTargetingAbility('Twitch_BurnSelf');

    BurningEffect = class'X2StatusEffects'.static.CreateBurningStatusEffect(default.BurningDamage, 0);
    BurningEffect.iNumTurns = default.BurningNumTurns;
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

static function X2DataTemplate CreateFullHealSelfAbility() {
    local X2AbilityTemplate Template;
	local X2Effect_Twitch_Heal HealEffect;

    Template = CreateSelfTargetingAbility('Twitch_FullHealSelf');

    HealEffect = new class'X2Effect_Twitch_Heal';
    HealEffect.HealAmount = 100000;
    Template.AddTargetEffect(HealEffect);

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
    PanickedEffect.iNumTurns = default.PanicNumTurns;
    Template.AddTargetEffect(PanickedEffect);

    return Template;
}

static function X2DataTemplate CreateScaleSelfLargeAbility() {
    local X2AbilityTemplate Template;
	local X2Effect_Twitch_ScaleUnit ScaleEffect;

    Template = CreateSelfTargetingAbility('Twitch_ScaleSelfLarge');

    ScaleEffect = class'X2Effect_Twitch_ScaleUnit'.static.CreateScaleUnitEffect(default.ScaleSelfLargeSizeChange);
    Template.AddTargetEffect(ScaleEffect);

    return Template;
}

static function X2DataTemplate CreateScaleSelfSmallAbility() {
    local X2AbilityTemplate Template;
	local X2Effect_Twitch_ScaleUnit ScaleEffect;

    Template = CreateSelfTargetingAbility('Twitch_ScaleSelfSmall');

    ScaleEffect = class'X2Effect_Twitch_ScaleUnit'.static.CreateScaleUnitEffect(default.ScaleSelfSmallSizeChange);
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
	Template.LostSpawnIncreasePerUse = 100;

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

static function X2Effect_PersistentStatChange CreateStatChangeStatusEffect(name EffectName, ECharStatType StatType, int StatChange, int NumTurns, string EffectTitle, string EffectDesc, string EffectFlyoverText, string IconPath)
{
    local EPerkBuffCategory PerkBuffCategory;
    local X2TwitchAbilities_StatChangeEffectVisClosure VisClosure;
	local X2Effect_PersistentStatChange PersistentStatChangeEffect;
    local string Desc;

    PerkBuffCategory = StatChange > 0 ? ePerkBuff_Bonus : ePerkBuff_Penalty;
    Desc = Repl(EffectDesc, "<Amount/>", StatChange);

    VisClosure = new class'X2TwitchAbilities_StatChangeEffectVisClosure';
    VisClosure.StatChangeAmount = StatChange;
    VisClosure.FlyoverText = EffectFlyoverText;

	PersistentStatChangeEffect = new class'X2Effect_PersistentStatChange';
    PersistentStatChangeEffect.EffectName = EffectName;
	PersistentStatChangeEffect.DuplicateResponse = eDupe_Refresh;
    PersistentStatChangeEffect.BuildPersistentEffect(NumTurns, /* _bInfiniteDuration */ false, /* _bRemoveWhenSourceDies */ false, , eGameRule_PlayerTurnBegin);
	PersistentStatChangeEffect.SetDisplayInfo(PerkBuffCategory, EffectTitle, Desc, IconPath);
	PersistentStatChangeEffect.AddPersistentStatChange(StatType, StatChange);
	PersistentStatChangeEffect.bRemoveWhenTargetDies = true;
    PersistentStatChangeEffect.VisualizationFn = VisClosure.StatChangeEffectVisualization;

	return PersistentStatChangeEffect;
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