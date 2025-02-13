class X2EventListener_ConnectToTwitch extends X2EventListener;

static function array<X2DataTemplate> CreateTemplates()
{
    local array<X2DataTemplate> Templates;

    Templates.AddItem(CreateListenerTemplate());

    return Templates;
}

static function X2EventListenerTemplate CreateListenerTemplate()
{
    local X2EventListenerTemplate Template;

    `CREATE_X2TEMPLATE(class'X2EventListenerTemplate', Template, 'X2EventListener_ConnectToTwitch');

    Template.RegisterInTactical = true;
    Template.RegisterInStrategy = true;
    Template.AddEvent('OnTacticalBeginPlay', ConnectToTwitch);
    Template.AddEvent('PreCompleteStrategyFromTacticalTransfer', ConnectToTwitch);

    return Template;
}

static protected function EventListenerReturn ConnectToTwitch(Object EventData, Object EventSource, XComGameState GameState, Name Event, Object CallbackData)
{
	`TILOG("ConnectToTwitch called, event name " $ Event);

    if (`TISTATEMGR == none) {
	    `XCOMGAME.Spawn(class'TwitchStateManager').Initialize();
    }

    return ELR_NoInterrupt;
}