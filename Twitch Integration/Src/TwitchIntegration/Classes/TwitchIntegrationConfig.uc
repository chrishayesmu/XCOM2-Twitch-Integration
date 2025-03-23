class TwitchIntegrationConfig extends UIScreenListener
    config(TwitchConfig);

`include(TwitchIntegration/Src/ModConfigMenuAPI/MCM_API_Includes.uci)
`include(TwitchIntegration/Src/ModConfigMenuAPI/MCM_API_CfgHelpers.uci)

// #region Enum/struct definitions

enum eTwitchConfig_ChatLogColorScheme {
    ETC_DefaultColorScheme,
    ETC_TeamColors,
    ETC_TwitchColors
};

enum eTwitchConfig_ChatLogNameFormat {
    ETC_TwitchNameOnly,
    ETC_UnitNameOnly
};

// #endregion

// #region Localization

var localized string strChangeButtonLabel;

// #region Chat log strings

var localized string strChatLogSettingsGroupTitle;
var localized string strShowChatLogLabel;
var localized string strShowChatLogTooltip;

var localized string strChatLogColorSchemeLabel;
var localized string strChatLogColorSchemeTooltip;
var localized string strChatLogColorScheme_Default;
var localized string strChatLogColorScheme_Team;
var localized string strChatLogColorScheme_Twitch;

var localized string strChatLogEnemyNameFormatLabel;
var localized string strChatLogEnemyNameFormatTooltip;
var localized string strChatLogFriendlyNameFormatLabel;
var localized string strChatLogFriendlyNameFormatTooltip;
var localized string strChatLogNameFormat_TwitchName;
var localized string strChatLogNameFormat_UnitName;

var localized string strChatLogFormatDeadMessagesLabel;
var localized string strChatLogFormatDeadMessagesTooltip;

// #endregion

// #region Poll strings

var localized string strPollSettingsGroupTitle;
var localized string strEnablePollsLabel;
var localized string strEnablePollsTooltip;
var localized string strPollDurationLabel;
var localized string strPollDurationTooltip;
var localized string strMinTurnsBeforeFirstPollLabel;
var localized string strMinTurnsBeforeFirstPollTooltip;
var localized string strMinTurnsBetweenPollsLabel;
var localized string strMinTurnsBetweenPollsTooltip;
var localized string strChanceToStartPollLabel;
var localized string strChanceToStartPollTooltip;
var localized string strAllowChannelPointVotesLabel;
var localized string strAllowChannelPointVotesTooltip;
var localized string strChannelPointsPerVoteLabel;
var localized string strChannelPointsPerVoteTooltip;

// #endregion

// #region Raffle strings

var localized string strRaffleSettingsGroupTitle;
var localized string strAssignUnitNamesLabel;
var localized string strAssignUnitNamesTooltip;
var localized string strAssignChosenNamesLabel;
var localized string strAssignChosenNamesTooltip;
var localized string strExcludeBroadcasterLabel;
var localized string strExcludeBroadcasterTooltip;

// #endregion

// #endregion

// #region Config variables

var config int ConfigVersion;

// #region Chat log settings

var config bool                             bShowChatLog;
var config bool                             bFormatDeadMessages;
var config eTwitchConfig_ChatLogColorScheme ChatLogColorScheme;
var config eTwitchConfig_ChatLogNameFormat  ChatLogEnemyNameFormat;
var config eTwitchConfig_ChatLogNameFormat  ChatLogFriendlyNameFormat;

// #endregion

// #region Nameplate settings

var config bool bPermanentNameplatesEnabled;

// #endregion

// #region Poll settings

var config bool bEnablePolls;
var config int  PollDurationInTurns;
var config int  MinTurnsBeforeFirstPoll;
var config int  MinTurnsBetweenPolls;
var config int  ChanceToStartPoll;
var config bool bAllowChannelPointVotes;
var config int  ChannelPointsPerVote;

// #endregion

// #region Raffle settings

var config bool bAssignUnitNames;
var config bool bAssignChosenNames;
var config bool bExcludeBroadcaster;

// #endregion

// #endregion

event OnInit(UIScreen Screen) {
	if (MCM_API(Screen) != none) {
		`MCM_API_Register(Screen, ClientModCallback);
	}
}

function ClientModCallback(MCM_API_Instance ConfigAPI, int GameMode) {
    local array<string> ChatLogColorSchemeOptions;
    local array<string> ChatLogNameFormatOptions;
    local MCM_API_Setting Setting;
    local MCM_API_SettingsPage Page;
    local MCM_API_SettingsGroup Group;

    LoadSavedSettings();

    Page = ConfigAPI.NewSettingsPage("Twitch Integration");
    Page.SetSaveHandler(SaveButtonClicked);

    Group = Page.AddGroup('TwitchChatLogSettings', strChatLogSettingsGroupTitle);
    Setting = Group.AddCheckbox(nameof(bShowChatLog), strShowChatLogLabel, strShowChatLogTooltip, bShowChatLog, ShowChatLogSaveHandler, DisableGroupWhenFalseHandler);

    ChatLogColorSchemeOptions.Length = 3;
    ChatLogColorSchemeOptions[0] = strChatLogColorScheme_Default;
    ChatLogColorSchemeOptions[1] = strChatLogColorScheme_Team;
    ChatLogColorSchemeOptions[2] = strChatLogColorScheme_Twitch;
    Group.AddDropdown(nameof(ChatLogColorScheme), strChatLogColorSchemeLabel, strChatLogColorSchemeTooltip, ChatLogColorSchemeOptions, ColorSchemeToString(ChatLogColorScheme), ChatLogColorSchemeSaveHandler);

    ChatLogNameFormatOptions.Length = 2;
    ChatLogNameFormatOptions[0] = strChatLogNameFormat_TwitchName;
    ChatLogNameFormatOptions[1] = strChatLogNameFormat_UnitName;
    Group.AddDropdown(nameof(ChatLogEnemyNameFormat), strChatLogEnemyNameFormatLabel, strChatLogEnemyNameFormatTooltip, ChatLogNameFormatOptions, ChatLogNameFormatToString(ChatLogEnemyNameFormat), SaveChatLogEnemyNameFormat);
    Group.AddDropdown(nameof(ChatLogFriendlyNameFormat), strChatLogFriendlyNameFormatLabel, strChatLogFriendlyNameFormatTooltip, ChatLogNameFormatOptions, ChatLogNameFormatToString(ChatLogFriendlyNameFormat), SaveChatLogFriendlyNameFormat);

    Group.AddCheckbox(nameof(bFormatDeadMessages), strChatLogFormatDeadMessagesLabel, strChatLogFormatDeadMessagesTooltip, bFormatDeadMessages, FormatDeadMessagesSaveHandler);

    DisableGroupWhenFalseHandler(Setting, bShowChatLog);

    Group = Page.AddGroup('TwitchPollSettings', strPollSettingsGroupTitle);
    Setting = Group.AddCheckbox(nameof(bEnablePolls), strEnablePollsLabel, strEnablePollsTooltip, bEnablePolls, EnablePollsSaveHandler, DisableGroupWhenFalseHandler);
    Group.AddSlider(nameof(PollDurationInTurns), strPollDurationLabel, strPollDurationTooltip, 1, 5, 1, PollDurationInTurns, PollDurationInTurnsSaveHandler);
    Group.AddSlider(nameof(MinTurnsBeforeFirstPoll), strMinTurnsBeforeFirstPollLabel, strMinTurnsBeforeFirstPollTooltip, 0, 10, 1, MinTurnsBeforeFirstPoll, MinTurnsBeforeFirstPollSaveHandler);
    Group.AddSlider(nameof(MinTurnsBetweenPolls), strMinTurnsBetweenPollsLabel, strMinTurnsBetweenPollsTooltip, 0, 10, 1, MinTurnsBetweenPolls, MinTurnsBetweenPollsSaveHandler);
    Group.AddSlider(nameof(ChanceToStartPoll), strChanceToStartPollLabel, strChanceToStartPollTooltip, 1, 100, 1, ChanceToStartPoll, ChanceToStartPollSaveHandler);
    Group.AddCheckbox(nameof(bAllowChannelPointVotes), strAllowChannelPointVotesLabel, strAllowChannelPointVotesTooltip, bAllowChannelPointVotes, AllowChannelPointVotesSaveHandler);
    Group.AddSlider(nameof(ChannelPointsPerVote), strChannelPointsPerVoteLabel, strChannelPointsPerVoteTooltip, 1, 1000000, 1, ChannelPointsPerVote, ChannelPointsPerVoteSaveHandler);

    DisableGroupWhenFalseHandler(Setting, bEnablePolls);


    Group = Page.AddGroup('TwitchRaffleSettings', strRaffleSettingsGroupTitle);
    Setting = Group.AddCheckbox(nameof(bAssignUnitNames), strAssignUnitNamesLabel, strAssignUnitNamesTooltip, bAssignUnitNames, AssignUnitNamesSaveHandler, DisableGroupWhenFalseHandler);
    Group.AddCheckbox(nameof(bAssignChosenNames), strAssignChosenNamesLabel, strAssignChosenNamesTooltip, bAssignChosenNames, AssignChosenNamesSaveHandler);
    Group.AddCheckbox(nameof(bExcludeBroadcaster), strExcludeBroadcasterLabel, strExcludeBroadcasterTooltip, bExcludeBroadcaster, ExcludeBroadcasterSaveHandler);

    DisableGroupWhenFalseHandler(Setting, bAssignUnitNames);

    Page.ShowSettings();
}

private function DisableGroupWhenFalseHandler(MCM_API_Setting Setting, bool Value) {
    local int Index, NumSettings;
    local MCM_API_Setting CurrentSetting;
    local MCM_API_SettingsGroup ParentGroup;

    ParentGroup = Setting.GetParentGroup();
    NumSettings = ParentGroup.GetNumberOfSettings();

    for (Index = 0; Index < NumSettings; Index++) {
        CurrentSetting = ParentGroup.GetSettingByIndex(Index);

        // Make sure we don't modify the checkbox that's controlling things
        if (CurrentSetting.GetName() == Setting.GetName()) {
            continue;
        }

        CurrentSetting.SetEditable(Value);
    }
}

private function LoadSavedSettings() {
    bShowChatLog = `TI_CFG(bShowChatLog);
    ChatLogColorScheme = `TI_CFG(ChatLogColorScheme);
    ChatLogEnemyNameFormat = `TI_CFG(ChatLogEnemyNameFormat);
    ChatLogFriendlyNameFormat = `TI_CFG(ChatLogFriendlyNameFormat);

    bEnablePolls = `TI_CFG(bEnablePolls);
    PollDurationInTurns = `TI_CFG(PollDurationInTurns);
    MinTurnsBeforeFirstPoll = `TI_CFG(MinTurnsBeforeFirstPoll);
    MinTurnsBetweenPolls = `TI_CFG(MinTurnsBetweenPolls);
    ChanceToStartPoll = `TI_CFG(ChanceToStartPoll);

    bAssignUnitNames = `TI_CFG(bAssignUnitNames);
    bAssignChosenNames = `TI_CFG(bAssignChosenNames);

    if (class'TwitchIntegrationConfigDefaults'.default.ConfigVersion > default.ConfigVersion) {
        default.ConfigVersion = class'TwitchIntegrationConfigDefaults'.default.ConfigVersion;
        self.SaveConfig();
    }
}

private function ChatLogColorSchemeSaveHandler(MCM_API_Setting _Setting, string Value) {
    switch (Value) {
        case strChatLogColorScheme_Default:
            ChatLogColorScheme = ETC_DefaultColorScheme;
            break;
        case strChatLogColorScheme_Team:
            ChatLogColorScheme = ETC_TeamColors;
            break;
        case strChatLogColorScheme_Twitch:
            ChatLogColorScheme = ETC_TwitchColors;
            break;
        default:
            `TILOG("WARNING: Unknown string value in ChatLogColorSchemeSaveHandler: " $ Value);
            break;
    }
}

private function eTwitchConfig_ChatLogNameFormat ChatLogNameFormatFromString(string ChatLogNameFormat) {
    switch (ChatLogNameFormat) {
        case strChatLogNameFormat_TwitchName:
            return ETC_TwitchNameOnly;
        case strChatLogNameFormat_UnitName:
            return ETC_UnitNameOnly;
        default:
            `TILOG("WARNING: Unknown string value in ChatLogNameFormatFromString: " $ ChatLogNameFormat);
            return 0;
    }
}

private function string ChatLogNameFormatToString(eTwitchConfig_ChatLogNameFormat ChatLogNameFormat) {
    switch (ChatLogNameFormat) {
        case ETC_TwitchNameOnly:
            return strChatLogNameFormat_TwitchName;
        case ETC_UnitNameOnly:
            return strChatLogNameFormat_UnitName;
        default:
            `TILOG("WARNING: Unknown enum value in ChatLogNameFormatToString: " $ ChatLogNameFormat);
            return "";
    }
}

private function string ColorSchemeToString(eTwitchConfig_ChatLogColorScheme ColorScheme) {
    switch (ColorScheme) {
        case ETC_DefaultColorScheme:
            return strChatLogColorScheme_Default;
        case ETC_TeamColors:
            return strChatLogColorScheme_Team;
        case ETC_TwitchColors:
            return strChatLogColorScheme_Twitch;
        default:
            `TILOG("WARNING: Unhandled enum value value in ColorSchemeToString: " $ ColorScheme);
            break;
    }
}

private function SaveButtonClicked(MCM_API_SettingsPage Page) {
    self.ConfigVersion = `MCM_CH_GetCompositeVersion();
    self.SaveConfig();

    `XEVENTMGR.TriggerEvent('TwitchModConfigSaved');
}

private function SaveChatLogEnemyNameFormat(MCM_API_Setting _Setting, string Value) {
    ChatLogEnemyNameFormat = ChatLogNameFormatFromString(Value);
}

private function SaveChatLogFriendlyNameFormat(MCM_API_Setting _Setting, string Value) {
    ChatLogFriendlyNameFormat = ChatLogNameFormatFromString(Value);
}

`MCM_CH_VersionChecker(class'TwitchIntegrationConfigDefaults'.default.ConfigVersion, ConfigVersion);
`MCM_API_BasicCheckboxSaveHandler(AllowChannelPointVotesSaveHandler, bAllowChannelPointVotes);
`MCM_API_BasicCheckboxSaveHandler(AssignChosenNamesSaveHandler, bAssignChosenNames);
`MCM_API_BasicCheckboxSaveHandler(AssignUnitNamesSaveHandler, bAssignUnitNames);
`MCM_API_BasicCheckboxSaveHandler(EnablePollsSaveHandler, bEnablePolls);
`MCM_API_BasicCheckboxSaveHandler(ExcludeBroadcasterSaveHandler, bExcludeBroadcaster);
`MCM_API_BasicCheckboxSaveHandler(FormatDeadMessagesSaveHandler, bFormatDeadMessages);
`MCM_API_BasicCheckboxSaveHandler(ShowChatLogSaveHandler, bShowChatLog);
`MCM_API_BasicSliderSaveHandler(ChanceToStartPollSaveHandler, ChanceToStartPoll);
`MCM_API_BasicSliderSaveHandler(ChannelPointsPerVoteSaveHandler, ChannelPointsPerVote);
`MCM_API_BasicSliderSaveHandler(MinTurnsBeforeFirstPollSaveHandler, MinTurnsBeforeFirstPoll);
`MCM_API_BasicSliderSaveHandler(MinTurnsBetweenPollsSaveHandler, MinTurnsBetweenPolls);
`MCM_API_BasicSliderSaveHandler(PollDurationInTurnsSaveHandler, PollDurationInTurns);