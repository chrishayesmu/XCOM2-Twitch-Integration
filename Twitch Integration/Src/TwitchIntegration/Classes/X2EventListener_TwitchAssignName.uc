class X2EventListener_TwitchAssignName extends X2EventListener
    config(TwitchIntegration);

var config bool bAssignNames;

static function array<X2DataTemplate> CreateTemplates() {
	local array<X2DataTemplate> Templates;

    if (default.bAssignNames) {
	    Templates.AddItem(UnitAssignName());
    }

	return Templates;
}

static function X2EventListenerTemplate UnitAssignName() {
	local X2EventListenerTemplate Template;

	`CREATE_X2TEMPLATE(class'X2EventListenerTemplate', Template, 'AssignTwitchName');

    // TODO: units that exist at the start of tactical play are not getting names
	Template.RegisterInTactical = true;
	Template.AddEvent('OnUnitBeginPlay', ChooseViewerName);
	Template.AddEvent('UnitSpawned', ChooseViewerName);
    Template.AddEvent('OnTacticalBeginPlay', AssignNamesToUnits);
	Template.AddEvent('TwitchAssignUnitNames', AssignNamesToUnits);

	return Template;
}

/// <summary>
/// Assigns viewer names to any units in the current mission that don't already have names.
/// </summary>
static protected function EventListenerReturn AssignNamesToUnits(Object EventData, Object EventSource, XComGameState GameState, Name Event, Object CallbackData) {
    local XComGameState_TwitchObjectOwnership OwnershipState;
	local XComGameState_Unit Unit;

    foreach `XCOMHISTORY.IterateByClassType(class'XComGameState_Unit', Unit) {
        // Make sure someone doesn't already own this unit
        OwnershipState = class'XComGameState_TwitchObjectOwnership'.static.FindForObject(Unit.ObjectID);

        if (OwnershipState != none) {
            continue;
        }

        `LOG("Choosing viewer for unit " $ Unit.GetFullName());
        ChooseViewerName(Unit, Unit, GameState, Event, none);
    }

    return ELR_NoInterrupt;
}

static protected function EventListenerReturn ChooseViewerName(Object EventData, Object EventSource, XComGameState GameState, Name Event, Object CallbackData) {
    local int ViewerIndex;
    local TwitchStateManager TwitchMgr;
    local XComGameState NewGameState;
	local XComGameState_Unit Unit;
    local XComGameState_TwitchObjectOwnership OwnershipState;
	local string FirstName, LastName;

	local XComPresentationLayer Pres;
	local UIUnitFlag UnitFlag;
    local UIUnitFlag_Twitch TwitchFlag;

	Pres = `PRES;
    TwitchMgr = class'X2TwitchUtils'.static.GetStateManager();
	Unit = XComGameState_Unit(EventSource);

	if (Unit == none || Pres == none) {
		return ELR_NoInterrupt;
    }

    OwnershipState = class'XComGameState_TwitchObjectOwnership'.static.FindForObject(Unit.ObjectID);

    if (OwnershipState != none) {
        // Someone already owns this unit
        return ELR_NoInterrupt;
    }

    // Don't give Twitch names to XCOM soldiers, they should have persistent names assigned by the streamer
    if (Unit.IsSoldier()) {
        return ELR_NoInterrupt;
    }

    // Don't give names to player Avatars
    // TODO: make this configurable
    if (Unit.GetTeam() == eTeam_XCom && Unit.GetMyTemplate().CharacterGroupName == 'AdventPsiWitch') {
        return ELR_NoInterrupt;
    }

    // Pick a viewer at random, if any available
    ViewerIndex = TwitchMgr.RaffleViewer();

    if (ViewerIndex < 0) {
        return ELR_NoInterrupt;
    }

	NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Assign Twitch Owner");

    // TODO: maybe we can make this game state transient if it's a non-Chosen enemy who will never be seen again
	OwnershipState = XComGameState_TwitchObjectOwnership(NewGameState.CreateStateObject(class'XComGameState_TwitchObjectOwnership'));
    OwnershipState.TwitchUsername = TwitchMgr.ConnectedViewers[ViewerIndex].Name;
    OwnershipState.OwnedObjectRef = Unit.GetReference();

    if (Unit.IsCivilian()) {
        // For civilians, we only show the viewer name. We want to make sure it's in the LastName slot,
        // because the name shows as "First Last", so if LastName is empty there's two spaces in a row,
        // which is noticeable.
        FirstName = "";
        LastName = OwnershipState.TwitchUsername;
    }
    else {
        FirstName = OwnershipState.TwitchUsername;
        LastName = "(" $ Unit.GetName(eNameType_Full) $ ")";
    }

    Unit.SetUnitName(FirstName, LastName, "");
    UnitFlag = Pres.m_kUnitFlagManager.GetFlagForObjectID(Unit.GetReference().ObjectID);

    if (UnitFlag != none) {
        UnitFlag.UpdateFromUnitState(Unit, true);
    }
    else {
        Pres.m_kUnitFlagManager.AddFlag(Unit.GetReference());
    }

    TwitchFlag = `XCOMGAME.Spawn(class'UIUnitFlag_Twitch', Pres.m_kUnitFlagManager);
    TwitchFlag.InitFlag(Unit.GetReference());

    `GAMERULES.SubmitGameState(NewGameState);

	return ELR_NoInterrupt;
}