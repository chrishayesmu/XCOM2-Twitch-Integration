class TwitchIntegrationConfigDefaults extends Object
    config(TwitchConfigDefaults)
    dependson(TwitchIntegrationConfig);

// #region Config variables

var config int ConfigVersion;

// #region Chat log settings

var config bool                             bEnableXSay;
var config bool                             bShowXSayInCommLink;
var config bool                             bShowChatLog;
var config eTwitchConfig_ChatLogColorScheme ChatLogColorScheme;
var config eTwitchConfig_ChatLogNameFormat  ChatLogEnemyNameFormat;
var config eTwitchConfig_ChatLogNameFormat  ChatLogFriendlyNameFormat;

// #endregion

// #region Poll settings

var config bool bEnablePolls;
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

// #region Roll the Dice settings

var config bool bRtdBalanceOptions;
var config bool bRtdQuickMode;

// #endregion


// #endregion