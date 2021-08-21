class TwitchIntegrationConfigDefaults extends Object
    config(TwitchConfigDefaults)
    dependson(TwitchIntegrationConfig);

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