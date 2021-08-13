class X2EventListener_ConnectToTwitch extends X2EventListener
	dependson(TwitchChatTcpLink);

static function array<X2DataTemplate> CreateTemplates()
{
    local array<X2DataTemplate> Templates;

    Templates.AddItem(Create_Listener_Template());

    return Templates;
}

static function X2EventListenerTemplate Create_Listener_Template()
{
    local X2EventListenerTemplate Template;

    `CREATE_X2TEMPLATE(class'X2EventListenerTemplate', Template, 'X2EventListener_ConnectToTwitch');

    Template.RegisterInTactical = true;
    Template.RegisterInStrategy = false;
    Template.AddEvent('OnTacticalBeginPlay', ConnectToTwitch);

    return Template;
}

static protected function EventListenerReturn ConnectToTwitch(Object EventData, Object EventSource, XComGameState GameState, Name Event, Object CallbackData)
{
	`TILOG("Tactical play begun, event name " $ Event);

    if (`TISTATEMGR == none) {
	    `XCOMGAME.Spawn(class'TwitchStateManager').Initialize();
    }

    return ELR_NoInterrupt;
}