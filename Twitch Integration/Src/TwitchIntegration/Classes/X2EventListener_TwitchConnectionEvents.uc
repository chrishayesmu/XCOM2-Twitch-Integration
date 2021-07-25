class X2EventListener_TwitchConnectionEvents extends X2EventListener;

static function array<X2DataTemplate> CreateTemplates()
{
    local array<X2DataTemplate> Templates;

    Templates.AddItem(Create_Listener_Template());

    return Templates;
}

static function X2EventListenerTemplate Create_Listener_Template()
{
    local X2EventListenerTemplate Template;

    `CREATE_X2TEMPLATE(class'X2EventListenerTemplate', Template, 'UniqueEventListenerTemplateName');

    Template.RegisterInTactical = true;
    Template.RegisterInStrategy = true;
    Template.AddEvent('TwitchChatConnectionSuccessful', OnConnectedToTwitch);
    Template.AddEvent('TwitchChatConnectionClosed', OnTwitchChatConnectionLost);

    return Template;
}

static protected function EventListenerReturn OnConnectedToTwitch(Object EventData, Object EventSource, XComGameState GameState, Name Event, Object CallbackData)
{
	local VisualizationActionMetadata ActionMetadata;
	local X2Action_PlayMessageBanner MessageAction;

	// Notify that connection succeeded
	MessageAction = X2Action_PlayMessageBanner(class'X2Action_PlayMessageBanner'.static.AddToVisualizationTree(ActionMetadata, GameState.GetContext()));
	MessageAction.AddMessageBanner("Twitch Integration", "", "Connection Successful", "Connection to Twitch chat established.", eUIState_Good);
	MessageAction.bDontPlaySoundEvent = true;

    class'X2TwitchUtils'.static.AddMessageToChatLog("SYSTEM", "Connection to Twitch chat established");

    return ELR_NoInterrupt;
}

static protected function EventListenerReturn OnTwitchChatConnectionLost(Object EventData, Object EventSource, XComGameState GameState, Name Event, Object CallbackData)
{
	local VisualizationActionMetadata ActionMetadata;
	local X2Action_PlayMessageBanner MessageAction;

	`LOG("EventListener acting on Twitch disconnection");

	MessageAction = X2Action_PlayMessageBanner(class'X2Action_PlayMessageBanner'.static.AddToVisualizationTree(ActionMetadata, GameState.GetContext()));
	MessageAction.AddMessageBanner("Twitch Integration", "", "Connection Lost", "Connection to Twitch chat lost unexpectedly.", eUIState_Warning);
	MessageAction.bDontPlaySoundEvent = true;

    return ELR_NoInterrupt;
}