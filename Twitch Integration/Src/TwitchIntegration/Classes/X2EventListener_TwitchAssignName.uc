class X2EventListener_TwitchAssignName extends X2EventListener
    config(TwitchIntegration);

var config bool bAssignNames;

static function array<X2DataTemplate> CreateTemplates()
{
	local array<X2DataTemplate> Templates;

    if (default.bAssignNames) {
	    Templates.AddItem(UnitAssignName());
    }

	return Templates;
}

static function X2EventListenerTemplate UnitAssignName()
{
	local X2EventListenerTemplate Template;

	`CREATE_X2TEMPLATE(class'X2EventListenerTemplate', Template, 'AssignTwitchName');

    // TODO: units that exist at the start of tactical play are not getting names
	Template.RegisterInTactical = true;
	Template.AddEvent('OnUnitBeginPlay', ChooseViewerName);
	Template.AddEvent('UnitSpawned', ChooseViewerName);

	return Template;
}

static protected function EventListenerReturn ChooseViewerName(Object EventData, Object EventSource, XComGameState GameState, Name Event, Object CallbackData)
{
    local int ViewerIndex;
    local TwitchStateManager TwitchMgr;
	local XComGameState_Unit Unit;
	local string FirstName, LastName;
	local XComPresentationLayer Pres;
	local UIUnitFlag UnitFlag;

	Pres = `PRES;
    TwitchMgr = class'X2TwitchUtils'.static.GetStateManager();
	Unit = XComGameState_Unit(EventSource);

	if (Unit == none || Pres == none) {
		return ELR_NoInterrupt;
    }

    // Don't give Twitch names to XCOM soldiers, they should have persistent names assigned by the streamer
    if (Unit.IsSoldier()) {
        return ELR_NoInterrupt;
    }

    // Don't give names to player Avatars
    if (Unit.GetTeam() == eTeam_XCom && Unit.GetMyTemplate().CharacterGroupName == 'AdventPsiWitch') {
        return ELR_NoInterrupt;
    }

    // Pick a viewer at random, if any available
    ViewerIndex = TwitchMgr.RaffleViewer();

    if (ViewerIndex < 0) {
        return ELR_NoInterrupt;
    }

    TwitchMgr.ConnectedViewers[ViewerIndex].OwnedObjectRef = Unit.GetReference();

    if (Unit.IsCivilian()) {
        // For civilians, we only show the viewer name. We want to make sure it's in the LastName slot,
        // because the name shows as "First Last", so if LastName is empty there's two spaces in a row,
        // which is noticeable.
        FirstName = "";
        LastName = TwitchMgr.ConnectedViewers[ViewerIndex].Name;
    }
    else {
        FirstName = TwitchMgr.ConnectedViewers[ViewerIndex].Name;
        LastName = "(" $ Unit.GetName(eNameType_Full) $ ")";
    }

    Unit.SetUnitName(FirstName, LastName, "");
    UnitFlag = Pres.m_kUnitFlagManager.GetFlagForObjectID(Unit.GetReference().ObjectID);

    if (UnitFlag != none) {
        UnitFlag.UpdateFromUnitState(Unit, true);
    }
    else {
        PRES.m_kUnitFlagManager.AddFlag(Unit.GetReference());
    }

	return ELR_NoInterrupt;
}