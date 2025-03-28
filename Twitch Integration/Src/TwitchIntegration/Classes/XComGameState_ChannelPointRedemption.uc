class XComGameState_ChannelPointRedemption extends XComGameState_BaseObject;

var string RedeemerLogin;     // Twitch login of the viewer who redeemed this reward
var string RedeemerName;      // Twitch display name of the viewer who redeemed this reward
var string RedeemerInput;     // Additional text added by the redeemer to some rewards
var int RedeemerUnitObjectID; // Object ID of the unit owned by the redeemer, if any
var string RewardId;          // Unique ID of the reward, assigned by Twitch
var string RewardTitle;       // Viewer-facing title of the reward, assigned by the streamer
var bool HadValidActions;     // Whether this redeem had any valid actions to trigger at the time it was used