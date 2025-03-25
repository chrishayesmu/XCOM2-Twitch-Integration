class TwitchEventHandler_ChannelPointRedeem extends TwitchEventHandler
    config(TwitchChannelPoints);

struct ChannelPointRedeemConfig {
    var string RewardId;
    var string RewardTitle;
    var array<name> Actions;
};

var config array<ChannelPointRedeemConfig> Redemptions;

function Handle(TwitchStateManager StateMgr, JsonObject Data) {
    local X2TwitchEventActionTemplate Action;
    local XComGameState_Unit UnitState;
    local string RewardId, RewardTitle, ViewerLogin, ViewerInput;
    local int Index, RedemptionIndex;

    RewardId = Data.GetStringValue("reward_id");
    RewardTitle = Data.GetStringValue("reward_title");
    ViewerLogin = Data.GetStringValue("user_login");
    ViewerInput = Data.GetStringValue("user_input"); // unused, but potentially an extension point for later

    `TILOG("Channel point redemption: reward ID = " $ RewardId $ ", reward title = " $ RewardTitle);

    RedemptionIndex = Redemptions.Find('RewardId', RewardId);

    if (RedemptionIndex == INDEX_NONE) {
        RedemptionIndex = Redemptions.Find('RewardTitle', RewardTitle);
    }

    if (RedemptionIndex == INDEX_NONE) {
        `TILOG("Didn't find any config entry matching the redemption; no action will be taken.");
        return;
    }

    UnitState = `TI_IS_STRAT_GAME ? class'X2TwitchUtils'.static.FindUnitOwnedByViewer(ViewerLogin) : class'X2TwitchUtils'.static.GetViewerUnitOnMission(ViewerLogin);

    `TILOG("Redemption is configured within the game. Viewer owns an eligible unit: " $ (UnitState != none));

    for (Index = 0; Index < Redemptions[RedemptionIndex].Actions.Length; Index++) {
        Action = class'X2TwitchUtils'.static.GetTwitchEventActionTemplate(Redemptions[RedemptionIndex].Actions[Index]);

        if (Action == none) {
            `TILOG("WARNING: couldn't find an action called " $ Redemptions[RedemptionIndex].Actions[Index]);
            continue;
        }

        if (Action.IsValid(UnitState)) {
            Action.Apply(UnitState);
        }
    }
}

defaultproperties
{
    EventType="channelPointRedeem"
}