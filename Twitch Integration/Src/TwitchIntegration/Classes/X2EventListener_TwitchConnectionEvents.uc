class X2EventListener_TwitchConnectionEvents extends X2EventListener;

static function array<X2DataTemplate> CreateTemplates()
{
    local array<X2DataTemplate> Templates;

    Templates.AddItem(Create_Listener_Template());

    return Templates;
}

static function X2EventListenerTemplate Create_Listener_Template()
{
    local CHEventListenerTemplate Template;

    `CREATE_X2TEMPLATE(class'CHEventListenerTemplate', Template, 'UniqueEventListenerTemplateName');

    Template.RegisterInTactical = true;
    Template.RegisterInStrategy = true;
    Template.AddCHEvent('TwitchChatConnectionSuccessful', OnConnectedToTwitch, ELD_Immediate);
    Template.AddCHEvent('TwitchChatConnectionClosed', OnTwitchChatConnectionLost, ELD_Immediate);

    return Template;
}

static private function EventListenerReturn OnConnectedToTwitch(Object EventData, Object EventSource, XComGameState GameState, Name Event, Object CallbackData)
{
    local XComGameState NewGameState;
    local XComGameState_TwitchConnection ConnectionState;
	local XComGameStateContext_ChangeContainer Context;

    NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Twitch Connection Made");

    ConnectionState = CreateOrModifyConnectionState(NewGameState);
    ConnectionState.bIsConnected = true;

    Context = XComGameStateContext_ChangeContainer(NewGameState.GetContext());
	Context.BuildVisualizationFn = BuildVisualization_OnConnectedToTwitch;

    `LOG("Submitting new game state for Twitch connection", , 'TwitchIntegration');
	`GAMERULES.SubmitGameState(NewGameState);

    return ELR_NoInterrupt;
}

static private function BuildVisualization_OnConnectedToTwitch(XComGameState VisualizeGameState) {
    local VisualizationActionMetadata ActionMetadata;
	local X2Action_PlayMessageBanner MessageAction;

	// Notify that connection succeeded
	MessageAction = X2Action_PlayMessageBanner(class'X2Action_PlayMessageBanner'.static.AddToVisualizationTree(ActionMetadata, VisualizeGameState.GetContext()));
	MessageAction.AddMessageBanner("Twitch Integration", "", "Connection Successful", "Connection to Twitch chat established.", eUIState_Good);
	MessageAction.bDontPlaySoundEvent = true;

    class'X2TwitchUtils'.static.AddMessageToChatLog("SYSTEM", "Connection to Twitch chat established");
}

static private function EventListenerReturn OnTwitchChatConnectionLost(Object EventData, Object EventSource, XComGameState GameState, Name Event, Object CallbackData) {
	local VisualizationActionMetadata ActionMetadata;
	local X2Action_PlayMessageBanner MessageAction;

    // TODO: need to submit a new game state sometimes
	MessageAction = X2Action_PlayMessageBanner(class'X2Action_PlayMessageBanner'.static.AddToVisualizationTree(ActionMetadata, GameState.GetContext()));
	MessageAction.AddMessageBanner("Twitch Integration", "", "Connection Lost", "Connection to Twitch chat lost unexpectedly.", eUIState_Warning);
	MessageAction.bDontPlaySoundEvent = true;

    return ELR_NoInterrupt;
}

static private function XComGameState_TwitchConnection CreateOrModifyConnectionState(XComGameState NewGameState) {
    local XComGameState_TwitchConnection ConnectionState;

    ConnectionState = XComGameState_TwitchConnection(`XCOMHISTORY.GetSingleGameStateObjectForClass(class'XComGameState_TwitchConnection', /* allowNULL */ true));

    if (ConnectionState != none) {
        ConnectionState = XComGameState_TwitchConnection(NewGameState.ModifyStateObject(class'XComGameState_TwitchConnection', ConnectionState.ObjectID));
    }
    else {
	    ConnectionState = XComGameState_TwitchConnection(NewGameState.CreateStateObject(class'XComGameState_TwitchConnection'));
    }

    return ConnectionState;
}