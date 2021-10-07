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

// #region General settings strings

var localized string strGeneralSettingsGroupTitle;
var localized string strTwitchChannelLabel;
var localized string strTwitchChannelTooltip;
var localized string strTwitchUsernameLabel;
var localized string strTwitchUsernameTooltip;
var localized string strOAuthTokenInputBoxTitle;
var localized string strOAuthTokenLabel;
var localized string strOAuthTokenTooltip;
var localized string strViewerTTLLabel;
var localized string strViewerTTLTooltip;

// #endregion

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

// #region Nameplate strings

var localized string strNameplateSettingsGroupTitle;
var localized string strPermanentNameplatesEnabledLabel;
var localized string strPermanentNameplatesEnabledTooltip;
var localized string strCivilianNameplatesEnabledLabel;
var localized string strCivilianNameplatesEnabledTooltip;
var localized string strEnemyNameplatesEnabledLabel;
var localized string strEnemyNameplatesEnabledTooltip;
var localized string strSoldierNameplatesEnabledLabel;
var localized string strSoldierNameplatesEnabledTooltip;

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

// #endregion

// #region Raffle strings

var localized string strRaffleSettingsGroupTitle;
var localized string strAssignUnitNamesLabel;
var localized string strAssignUnitNamesTooltip;
var localized string strAssignChosenNamesLabel;
var localized string strAssignChosenNamesTooltip;
var localized string strChosenNamesArePersistentLabel;
var localized string strChosenNamesArePersistentTooltip;

// #endregion

// #endregion

// #region Config variables

var config int ConfigVersion;

// #region General settings

var config string TwitchChannel;
var config string TwitchUsername;
var config string OAuthToken;
var config int    ViewerTTLInMinutes;

// #endregion

// #region Chat log settings

var config bool                             bShowChatLog;
var config bool                             bFormatDeadMessages;
var config eTwitchConfig_ChatLogColorScheme ChatLogColorScheme;
var config eTwitchConfig_ChatLogNameFormat  ChatLogEnemyNameFormat;
var config eTwitchConfig_ChatLogNameFormat  ChatLogFriendlyNameFormat;

// #endregion

// #region Nameplate settings

var config bool bPermanentNameplatesEnabled;
var config bool bCivilianNameplatesEnabled;
var config bool bEnemyNameplatesEnabled;
var config bool bSoldierNameplatesEnabled;

// #endregion

// #region Poll settings

var config bool bEnablePolls;
var config int  PollDurationInTurns;
var config int  MinTurnsBeforeFirstPoll;
var config int  MinTurnsBetweenPolls;
var config int  ChanceToStartPoll;

// #endregion

// #region Raffle settings

var config bool bAssignUnitNames;
var config bool bAssignChosenNames;
var config bool bChosenNamesArePersistent;

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

    // TODO: right now channel name will update even without the settings being saved; need a temporary storage for the channel value until save time
    Group = Page.AddGroup('TwitchGeneralSettings', strGeneralSettingsGroupTitle);
    Group.AddButton(nameof(TwitchChannel), strTwitchChannelLabel, strTwitchChannelTooltip, strChangeButtonLabel, OpenTwitchChannelInputBox);
    Group.AddButton(nameof(TwitchUsername), strTwitchUsernameLabel, strTwitchUsernameTooltip, strChangeButtonLabel, OpenTwitchUsernameInputBox);
    Group.AddButton(nameof(OAuthToken), strOAuthTokenLabel, strOAuthTokenTooltip, strChangeButtonLabel, OpenOAuthTokenInputBox);
    Group.AddSlider(nameof(ViewerTTLInMinutes), strViewerTTLLabel, strViewerTTLTooltip, 10, 60, 1, ViewerTTLInMinutes, ViewerTTLSaveHandler);



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



    Group = Page.AddGroup('TwitchNameplateSettings', strNameplateSettingsGroupTitle);
    Group.AddCheckbox(nameof(bPermanentNameplatesEnabled), strPermanentNameplatesEnabledLabel, strPermanentNameplatesEnabledTooltip, bPermanentNameplatesEnabled, PermanentNameplatesSaveHandler);
    Group.AddCheckbox(nameof(bCivilianNameplatesEnabled), strCivilianNameplatesEnabledLabel, strCivilianNameplatesEnabledTooltip, bCivilianNameplatesEnabled, CivilianNameplatesSaveHandler);
    Group.AddCheckbox(nameof(bEnemyNameplatesEnabled), strEnemyNameplatesEnabledLabel, strEnemyNameplatesEnabledTooltip, bEnemyNameplatesEnabled, EnemyNameplatesSaveHandler);
    Group.AddCheckbox(nameof(bSoldierNameplatesEnabled), strSoldierNameplatesEnabledLabel, strSoldierNameplatesEnabledTooltip, bSoldierNameplatesEnabled, SoldierNameplatesSaveHandler);



    Group = Page.AddGroup('TwitchPollSettings', strPollSettingsGroupTitle);
    Setting = Group.AddCheckbox(nameof(bEnablePolls), strEnablePollsLabel, strEnablePollsTooltip, bEnablePolls, EnablePollsSaveHandler, DisableGroupWhenFalseHandler);
    Group.AddSlider(nameof(PollDurationInTurns), strPollDurationLabel, strPollDurationTooltip, 1, 5, 1, PollDurationInTurns, PollDurationInTurnsSaveHandler);
    Group.AddSlider(nameof(MinTurnsBeforeFirstPoll), strMinTurnsBeforeFirstPollLabel, strMinTurnsBeforeFirstPollTooltip, 0, 10, 1, MinTurnsBeforeFirstPoll, MinTurnsBeforeFirstPollSaveHandler);
    Group.AddSlider(nameof(MinTurnsBetweenPolls), strMinTurnsBetweenPollsLabel, strMinTurnsBetweenPollsTooltip, 0, 10, 1, MinTurnsBetweenPolls, MinTurnsBetweenPollsSaveHandler);
    Group.AddSlider(nameof(ChanceToStartPoll), strChanceToStartPollLabel, strChanceToStartPollTooltip, 1, 100, 1, ChanceToStartPoll, ChanceToStartPollSaveHandler);

    DisableGroupWhenFalseHandler(Setting, bEnablePolls);



    Group = Page.AddGroup('TwitchRaffleSettings', strRaffleSettingsGroupTitle);
    Setting = Group.AddCheckbox(nameof(bAssignUnitNames), strAssignUnitNamesLabel, strAssignUnitNamesTooltip, bAssignUnitNames, AssignUnitNamesSaveHandler, DisableGroupWhenFalseHandler);
    Group.AddCheckbox(nameof(bAssignChosenNames), strAssignChosenNamesLabel, strAssignChosenNamesTooltip, bAssignChosenNames, AssignChosenNamesSaveHandler, OnAssignChosenNamesChanged);
    Group.AddCheckbox(nameof(bChosenNamesArePersistent), strChosenNamesArePersistentLabel, strChosenNamesArePersistentTooltip, bChosenNamesArePersistent, ChosenNamesArePersistentSaveHandler);

    DisableGroupWhenFalseHandler(Setting, bAssignUnitNames);
    OnAssignChosenNamesChanged(Setting, bAssignChosenNames);

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
    TwitchChannel = `TI_CFG(TwitchChannel);
    TwitchUsername = `TI_CFG(TwitchUsername);
    OAuthToken = `TI_CFG(OAuthToken);
    ViewerTTLInMinutes = `TI_CFG(ViewerTTLInMinutes);

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
    bChosenNamesArePersistent = `TI_CFG(bChosenNamesArePersistent);

    if (class'TwitchIntegrationConfigDefaults'.default.ConfigVersion > default.ConfigVersion) {
        default.ConfigVersion = class'TwitchIntegrationConfigDefaults'.default.ConfigVersion;
        self.SaveConfig();
    }
}

private function OnAssignChosenNamesChanged(MCM_API_Setting Setting, bool Value) {
    local MCM_API_SettingsGroup ParentGroup;

    ParentGroup = Setting.GetParentGroup();
    ParentGroup.GetSettingByName(nameof(bChosenNamesArePersistent)).SetEditable(Value);
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

private function OpenOAuthTokenInputBox(MCM_API_Setting _Setting) {
	local TInputDialogData kData;

    kData.strTitle = strOAuthTokenInputBoxTitle;
    kData.iMaxChars = 36; // token is 30 characters, plus 6 for the "oauth:" prefix
    kData.fnCallbackAccepted = OnOAuthTokenInputBoxClosed;
    kData.strInputBoxText = OAuthToken;
    kData.bIsPassword = true;

    `PRESBASE.UIInputDialog(kData);
}

private function OnOAuthTokenInputBoxClosed(string Text) {
    OAuthToken = Text;
}

private function OpenTwitchChannelInputBox(MCM_API_Setting _Setting) {
	local TInputDialogData kData;

    kData.strTitle = strTwitchChannelLabel;
    kData.iMaxChars = 40; // supposedly max Twitch name is 25 but it's not documented
    kData.fnCallbackAccepted = OnTwitchChannelInputBoxClosed;
    kData.strInputBoxText = TwitchChannel;

    `PRESBASE.UIInputDialog(kData);
}

private function OnTwitchChannelInputBoxClosed(string Text) {
    TwitchChannel = Text;
}

private function OpenTwitchUsernameInputBox(MCM_API_Setting _Setting) {
	local TInputDialogData kData;

    kData.strTitle = strTwitchUsernameLabel;
    kData.iMaxChars = 40; // supposedly max Twitch name is 25 but it's not documented
    kData.fnCallbackAccepted = OnTwitchUsernameInputBoxClosed;
    kData.strInputBoxText = TwitchUsername;

    `PRESBASE.UIInputDialog(kData);
}

private function OnTwitchUsernameInputBoxClosed(string Text) {
    TwitchUsername = Text;
}

`MCM_CH_VersionChecker(class'TwitchIntegrationConfigDefaults'.default.ConfigVersion, ConfigVersion);
`MCM_API_BasicCheckboxSaveHandler(PermanentNameplatesSaveHandler, bPermanentNameplatesEnabled);
`MCM_API_BasicCheckboxSaveHandler(CivilianNameplatesSaveHandler, bCivilianNameplatesEnabled);
`MCM_API_BasicCheckboxSaveHandler(EnemyNameplatesSaveHandler, bEnemyNameplatesEnabled);
`MCM_API_BasicCheckboxSaveHandler(SoldierNameplatesSaveHandler, bSoldierNameplatesEnabled);
`MCM_API_BasicCheckboxSaveHandler(EnablePollsSaveHandler, bEnablePolls);
`MCM_API_BasicCheckboxSaveHandler(ShowChatLogSaveHandler, bShowChatLog);
`MCM_API_BasicCheckboxSaveHandler(FormatDeadMessagesSaveHandler, bFormatDeadMessages);
`MCM_API_BasicCheckboxSaveHandler(AssignUnitNamesSaveHandler, bAssignUnitNames);
`MCM_API_BasicCheckboxSaveHandler(AssignChosenNamesSaveHandler, bAssignChosenNames);
`MCM_API_BasicCheckboxSaveHandler(ChosenNamesArePersistentSaveHandler, bChosenNamesArePersistent);
`MCM_API_BasicSliderSaveHandler(ViewerTTLSaveHandler, ViewerTTLInMinutes);
`MCM_API_BasicSliderSaveHandler(PollDurationInTurnsSaveHandler, PollDurationInTurns);
`MCM_API_BasicSliderSaveHandler(MinTurnsBeforeFirstPollSaveHandler, MinTurnsBeforeFirstPoll);
`MCM_API_BasicSliderSaveHandler(MinTurnsBetweenPollsSaveHandler, MinTurnsBetweenPolls);
`MCM_API_BasicSliderSaveHandler(ChanceToStartPollSaveHandler, ChanceToStartPoll);