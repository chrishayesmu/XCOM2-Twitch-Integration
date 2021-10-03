class TwitchCommandHandler_XSay extends TwitchCommandHandler
    dependson(TwitchStateManager);

var config bool bRequireUnitInLOS;
var config bool bShowToast;
var config bool bShowFlyover;
var config float LookAtDuration;

const LookAtDurationMin = 1.5;
const LookAtDurationMax = 2.75; // after this point the text has faded anyway
const LookAtDurationPerChar = 0.02; // 1 second per 50 characters

const MaxFlyoverLength = 45;
const MaxToastLength = 40;

function Handle(TwitchStateManager StateMgr, TwitchMessage Command, TwitchViewer Viewer) {
    local bool bUnitIsVisibleToSquad;
    local XComGameState NewGameState;
	local XComGameStateContext_ChangeContainer NewContext;
	local XComGameState_TwitchXSay XSayGameState;
	local XComGameState_Unit Unit;

    if (`TI_IS_STRAT_GAME) {
        // Strat game: if you own a unit, you can chat
        Unit = class'X2TwitchUtils'.static.FindUnitOwnedByViewer(Viewer.Login);
    }
    else {
        // Tac game: your unit has to be on the mission
        Unit = GetViewerUnitOnMission(Viewer.Login);
    }

    if (Unit == none) {
        return;
    }

    bUnitIsVisibleToSquad = class'X2TacticalVisibilityHelpers'.static.CanXComSquadSeeTarget(Unit.ObjectID);

    if (bRequireUnitInLOS && !bUnitIsVisibleToSquad) {
        return;
    }

	NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("XSay From " $ Viewer.Login);

	XSayGameState = XComGameState_TwitchXSay(NewGameState.CreateNewStateObject(class'XComGameState_TwitchXSay'));
	XSayGameState.MessageBody = GetCommandBody(Command);
	XSayGameState.Sender = Viewer.Login;
    XSayGameState.TwitchMessageId = Command.MsgId;

    // Need to include a new game state for the unit or else the visualizer may think it's still
    // visualizing an old ability and fail to do the flyover
    Unit = XComGameState_Unit(NewGameState.ModifyStateObject(class'XComGameState_Unit', Unit.ObjectID));

	NewContext = XComGameStateContext_ChangeContainer(NewGameState.GetContext());
	NewContext.BuildVisualizationFn = XSay_BuildVisualization;

    `GAMERULES.SubmitGameState(NewGameState);
}

protected function XSay_BuildVisualization(XComGameState VisualizeGameState) {
    local bool bUnitIsVisibleToSquad;
    local string SanitizedMessageBody;
    local string ViewerName;
    local EWidgetColor MessageColor;
    local TwitchViewer Viewer;
	local VisualizationActionMetadata ActionMetadata;
    local X2Action_AddToChatLog ChatLogAction;
	local X2Action_PlayMessageBanner MessageAction;
	local X2Action_PlaySoundAndFlyOver SoundAndFlyover;
	local XComGameState_TwitchXSay XSayGameState;
	local XComGameState_Unit Unit;
	local XComGameStateHistory History;
	local XComTacticalController LocalController;

	History = `XCOMHISTORY;

	foreach VisualizeGameState.IterateByClassType(class'XComGameState_TwitchXSay', XSayGameState) {
		break;
	}

    `TISTATEMGR.TwitchChatConn.GetViewer(XSayGameState.Sender, Viewer);
    ViewerName = `TIVIEWERNAME(Viewer);
    Unit = class'X2TwitchUtils'.static.FindUnitOwnedByViewer(Viewer.Login);
    bUnitIsVisibleToSquad = class'X2TacticalVisibilityHelpers'.static.CanXComSquadSeeTarget(Unit.ObjectID);

    if (Unit.IsDead()) {
        MessageColor = eColor_Gray;
    }
    else {
        switch (Unit.GetTeam()) {
            case eTeam_Alien:
                MessageColor = eColor_Alien;
                break;
            case eTeam_TheLost:
                MessageColor = eColor_TheLost;
                break;
            default:
                MessageColor = eColor_Xcom;
                break;
        }
    }

	ActionMetadata.StateObject_OldState = Unit;
	ActionMetadata.StateObject_NewState = Unit;
	ActionMetadata.VisualizeActor = History.GetVisualizer(Unit.ObjectID);

    // Don't do the flyover if we can't see the unit, regardless of settings
    if (bShowFlyover && bUnitIsVisibleToSquad) {
        SanitizedMessageBody = class'TextUtilities_Twitch'.static.SanitizeText(TruncateMessage(XSayGameState.MessageBody, MaxFlyoverLength));

        // TODO: for ADVENT and Lost a generic talking sound cue would be cool
	    SoundAndFlyOver = X2Action_PlaySoundAndFlyOver(class'X2Action_PlaySoundAndFlyOver'.static.AddToVisualizationTree(ActionMetadata, VisualizeGameState.GetContext(), false, ActionMetadata.LastActionAdded));
	    SoundAndFlyOver.SetSoundAndFlyOverParameters(none, SanitizedMessageBody, '', MessageColor, /* _FlyOverIcon */,
                                                     CalcLookAtDuration(SanitizedMessageBody), /* _BlockUntilFinished */, /* _VisibleTeam */, class'UIWorldMessageMgr'.const.FXS_MSG_BEHAVIOR_FLOAT);
    }
    else {
        // If we aren't doing a flyover, we need to prevent the tactical controller from automatically panning back to the selected unit.
        // The only way to do that is to make it think the player selected a different unit while
        LocalController = XComTacticalController(class'WorldInfo'.static.GetWorldInfo().GetALocalPlayerController());
        LocalController.bManuallySwitchedUnitsWhileVisualizerBusy = true;
    }

    ChatLogAction = X2Action_AddToChatLog(class'X2Action_AddToChatLog'.static.AddToVisualizationTree(ActionMetadata, VisualizeGameState.GetContext(), , ActionMetadata.LastActionAdded));
    ChatLogAction.Sender = ViewerName;
    ChatLogAction.Message = XSayGameState.MessageBody; // no need to sanitize, chat log will do it
    ChatLogAction.MsgId = XSayGameState.TwitchMessageId;

    if (bShowToast) {
        SanitizedMessageBody = class'TextUtilities_Twitch'.static.SanitizeText(TruncateMessage(XSayGameState.MessageBody, MaxToastLength));

        MessageAction = X2Action_PlayMessageBanner(class'X2Action_PlayMessageBanner'.static.AddToVisualizationTree(ActionMetadata, VisualizeGameState.GetContext()));
        MessageAction.AddMessageBanner("Twitch Message", "", ViewerName, SanitizedMessageBody, eUIState_Normal);
        MessageAction.bDontPlaySoundEvent = true;
    }
}

private function float CalcLookAtDuration(string Message) {
    if (default.LookAtDuration > 0) {
        // User-configured value: just use it directly
        return default.LookAtDuration;
    }

    if (default.LookAtDuration < 0) {
        // Negative value: disable look-at
        return 0.0;
    }

    // Set to 0: automatically determine a duration based on message length
    return Clamp(Len(Message) * LookAtDurationPerChar, LookAtDurationMin, LookAtDurationMax);
}

private function string TruncateMessage(string Message, int MaxLength) {
    if (Len(Message) > MaxLength) {
        Message = Left(Message, MaxLength) $ " ...";
    }

    return Message;
}
