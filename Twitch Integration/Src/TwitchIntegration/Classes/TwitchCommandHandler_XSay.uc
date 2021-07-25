class TwitchCommandHandler_XSay extends TwitchCommandHandler
    dependson(TwitchStateManager)
    config (TwitchCommands);

var config bool bShowToast;
var config float LookAtDuration;

const LookAtDurationMin = 1.5;
const LookAtDurationMax = 2.75; // after this point the text has faded anyway
const LookAtDurationPerChar = 0.02; // 1 second per 50 characters

const MaxToastLength = 50;

function Handle(TwitchStateManager StateMgr, string CommandAlias, string CommandBody, string Sender) {
    local XComGameState NewGameState;
	local XComGameStateContext_ChangeContainer NewContext;
	local XComGameState_TwitchXSay XSayGameState;
	local XComGameState_Unit Unit;

    Unit = class'X2TwitchUtils'.static.FindUnitOwnedByViewer(Sender);

    if (Unit == none) {
        return;
    }

	NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("XSay From " $ Sender);

	XSayGameState = XComGameState_TwitchXSay(NewGameState.CreateStateObject(class'XComGameState_TwitchXSay'));
	XSayGameState.MessageBody = commandBody;
	XSayGameState.Sender = Sender;

    // Need to include a new game state for the unit or else the visualizer may think it's still
    // visualizing an old ability and fail to do the flyover
    Unit = XComGameState_Unit(NewGameState.ModifyStateObject(class'XComGameState_Unit', Unit.ObjectID));

	NewContext = XComGameStateContext_ChangeContainer(NewGameState.GetContext());
	NewContext.BuildVisualizationFn = XSay_BuildVisualization;

    `GAMERULES.SubmitGameState(NewGameState);
}

protected function XSay_BuildVisualization(XComGameState VisualizeGameState) {
    local EWidgetColor MessageColor;
	local VisualizationActionMetadata ActionMetadata;
	local X2Action_PlayMessageBanner MessageAction;
	local X2Action_PlaySoundAndFlyOver SoundAndFlyover;
	local XComGameState_TwitchXSay XSayGameState;
	local XComGameState_Unit Unit;
	local XComGameStateHistory History;

	History = `XCOMHISTORY;

	foreach VisualizeGameState.IterateByClassType(class'XComGameState_TwitchXSay', XSayGameState) {
		break;
	}

    Unit = class'X2TwitchUtils'.static.FindUnitOwnedByViewer(XSayGameState.Sender);

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

    // TODO: for ADVENT and Lost a generic talking sound would be cool
    // TODO: the flyover box doesn't get very big; limit characters?
	SoundAndFlyOver = X2Action_PlaySoundAndFlyOver(class'X2Action_PlaySoundAndFlyOver'.static.AddToVisualizationTree(ActionMetadata, VisualizeGameState.GetContext()));
	SoundAndFlyOver.SetSoundAndFlyOverParameters(none, XSayGameState.MessageBody, '', MessageColor, /* _FlyOverIcon */, /* _LookAtDuration */ CalcLookAtDuration(XSayGameState.MessageBody), /* _BlockUntilFinished */, /* _VisibleTeam */, class'UIWorldMessageMgr'.const.FXS_MSG_BEHAVIOR_FLOAT);

    class'X2Action_AddToChatLog'.static.AddToVisualizationTree(ActionMetadata, VisualizeGameState.GetContext(), , ActionMetadata.LastActionAdded);

    if (bShowToast) {
        MessageAction = X2Action_PlayMessageBanner(class'X2Action_PlayMessageBanner'.static.AddToVisualizationTree(ActionMetadata, VisualizeGameState.GetContext()));
        MessageAction.AddMessageBanner("Twitch Message", "", XSayGameState.Sender, Left(XSayGameState.MessageBody, MaxToastLength), eUIState_Normal);
        MessageAction.bDontPlaySoundEvent = true;
    }
}

protected function float CalcLookAtDuration(string Message) {
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

defaultproperties
{
	CommandAliases=("xsay", "say")
}