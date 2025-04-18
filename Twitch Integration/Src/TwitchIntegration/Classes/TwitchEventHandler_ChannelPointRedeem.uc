class TwitchEventHandler_ChannelPointRedeem extends TwitchEventHandler
    config(TwitchChannelPoints);

struct ChannelPointRedeemConfig {
    var string RewardId;
    var string RewardTitle;
    var array<name> Actions;
};

var localized const string BannerTitle;
var localized const string BannerText;

var config array<ChannelPointRedeemConfig> Redemptions;

function Handle(TwitchStateManager StateMgr, JsonObject Data) {
    local XComGameStateContext_ChangeContainer NewContext;
    local XComGameState NewGameState;
    local XComGameState_ChannelPointRedemption RedeemState;
    local array<X2TwitchEventActionTemplate> ValidActions;
    local X2TwitchEventActionTemplate Action;
    local XComGameState_Unit UnitState;
    local string RewardId, RewardTitle, ViewerLogin, ViewerName, ViewerInput;
    local int Index, RedemptionIndex;

    RewardId = Data.GetStringValue("reward_id");
    RewardTitle = Data.GetStringValue("reward_title");
    ViewerLogin = Data.GetStringValue("user_login");
    ViewerName = Data.GetStringValue("user_name");
    ViewerInput = Data.GetStringValue("user_input"); // unused, but potentially an extension point for later

    `TILOG("Channel point redemption by " $ ViewerLogin $ ": reward ID = " $ RewardId $ ", reward title = " $ RewardTitle);

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
            ValidActions.AddItem(Action);
        }
    }

    NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Twitch Channel Point Redeem");
    RedeemState = XComGameState_ChannelPointRedemption(NewGameState.CreateNewStateObject(class'XComGameState_ChannelPointRedemption'));

    RedeemState.RedeemerLogin = ViewerLogin;
    RedeemState.RedeemerName = ViewerName;
    RedeemState.RedeemerInput = ViewerInput;
    RedeemState.RedeemerUnitObjectID = UnitState != none ? UnitState.GetReference().ObjectID : 0;
    RedeemState.RewardId = RewardId;
    RedeemState.RewardTitle = RewardTitle;
    RedeemState.HadValidActions = ValidActions.Length > 0;

    NewContext = XComGameStateContext_ChangeContainer(NewGameState.GetContext());
    NewContext.BuildVisualizationFn = BuildVisualization;

    `GAMERULES.SubmitGameState(NewGameState);

    foreach ValidActions(Action) {
        Action.Apply(UnitState);
    }
}

protected function BuildVisualization(XComGameState VisualizeGameState) {
    local VisualizationActionMetadata ActionMetadata;
    local X2Action_PlayMessageBanner MessageAction;
    local XComGameState_ChannelPointRedemption RedeemState;
    local string BannerValue;

    foreach VisualizeGameState.IterateByClassType(class'XComGameState_ChannelPointRedemption', RedeemState) {
        break;
    }

    ActionMetadata.StateObject_OldState = RedeemState;
    ActionMetadata.StateObject_NewState = RedeemState;

    BannerValue = Repl(BannerText, "<ViewerName/>", RedeemState.RedeemerName);

    if (`TI_IS_TAC_GAME) {
        MessageAction = X2Action_PlayMessageBanner(class'X2Action_PlayMessageBanner'.static.AddToVisualizationTree(ActionMetadata, VisualizeGameState.GetContext()));
        MessageAction.AddMessageBanner(BannerTitle, /* IconPath */ "", RedeemState.RewardTitle, BannerValue, eUIState_Normal);
    }
    else {
        `HQPRES.NotifyBanner(BannerTitle, /* ImagePath */, RedeemState.RewardTitle, BannerValue, eUIState_Normal);
    }

    // TODO indicate an invalid redeem somehow so the streamer can refund the user their points
}

defaultproperties
{
    EventType="channelPointRedeem"
}