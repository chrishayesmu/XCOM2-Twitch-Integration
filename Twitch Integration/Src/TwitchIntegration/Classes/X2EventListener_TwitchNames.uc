class X2EventListener_TwitchNames extends X2EventListener
    config(TwitchIntegration);

var config bool bAssignNames;

static function array<X2DataTemplate> CreateTemplates() {
	local array<X2DataTemplate> Templates;

    if (default.bAssignNames) {
	    Templates.AddItem(UnitAssignName());
	    Templates.AddItem(UnitShowName());
    }

	return Templates;
}

static function X2EventListenerTemplate UnitAssignName() {
	local CHEventListenerTemplate Template;

	`CREATE_X2TEMPLATE(class'CHEventListenerTemplate', Template, 'AssignTwitchName');

	Template.RegisterInTactical = true;
	Template.AddEvent('OnUnitBeginPlay', ChooseViewerName);
	Template.AddEvent('UnitSpawned', ChooseViewerName);
	Template.AddCHEvent('TwitchAssignUnitNames', AssignNamesToUnits, ELD_Immediate);

	return Template;
}

static function X2EventListenerTemplate UnitShowName() {
	local CHEventListenerTemplate Template;

	`CREATE_X2TEMPLATE(class'CHEventListenerTemplate', Template, 'ShowTwitchName');

	Template.RegisterInTactical = true;
	Template.AddCHEvent('EnemyGroupSighted', OnEnemyGroupSighted, ELD_OnVisualizationBlockStarted);

	return Template;
}

/// <summary>
/// Assigns viewer names to any units in the current mission that don't already have names.
/// </summary>
static protected function EventListenerReturn AssignNamesToUnits(Object EventData, Object EventSource, XComGameState GameState, Name Event, Object CallbackData) {
    local XComGameState_TwitchObjectOwnership OwnershipState;
	local XComGameState_Unit Unit;

    `LOG("In AssignNamesToUnits");

    foreach `XCOMHISTORY.IterateByClassType(class'XComGameState_Unit', Unit) {
        // Make sure someone doesn't already own this unit
        OwnershipState = class'XComGameState_TwitchObjectOwnership'.static.FindForObject(Unit.ObjectID);

        if (OwnershipState != none) {
            continue;
        }

        ChooseViewerName(Unit, Unit, GameState, Event, none);
    }

    return ELR_NoInterrupt;
}

static protected function EventListenerReturn ChooseViewerName(Object EventData, Object EventSource, XComGameState GameState, Name Event, Object CallbackData) {
    local int ViewerIndex;
    local TwitchStateManager TwitchMgr;
	local UnitValue SpawnedUnitValue;
    local XComGameState NewGameState;
	local XComGameState_Unit Unit;
    local XComGameState_TwitchObjectOwnership OwnershipState;
	local string FirstName, LastName;

	local XComPresentationLayer Pres;
	local UIUnitFlag UnitFlag;

	Pres = `PRES;
    TwitchMgr = class'X2TwitchUtils'.static.GetStateManager();
	Unit = XComGameState_Unit(EventSource);

    // UnitBeginPlay events can fire before we have a chance to initialize the TwitchStateManager
	if (Pres == none || TwitchMgr == none || Unit == none) {
        `LOG("Skipping ChooseViewerName: Pres == none: " $ (Pres == none) $ "; TwitchMgr == none: " $ (TwitchMgr == none) $ "; Unit == none: " $ (Unit == none));
		return ELR_NoInterrupt;
    }

    OwnershipState = class'XComGameState_TwitchObjectOwnership'.static.FindForObject(Unit.ObjectID);

    if (OwnershipState != none) {
        // Someone already owns this unit
        return ELR_NoInterrupt;
    }

    // Don't give Twitch names to XCOM soldiers, they should have persistent names assigned by the streamer
    // (Non-XCOM soldiers are Resistance members, who should receive names)
    // TODO: when you rescue a Resistance member, do they join your roster?
    if (Unit.GetTeam() == eTeam_XCom && Unit.IsSoldier()) {
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
    `LOG("Assigning viewer " $ OwnershipState.TwitchUsername $ " at index " $ ViewerIndex $ " to unit " $ Unit.GetFullName(), , 'TwitchIntegration');

    if (Unit.IsCivilian() && Unit.IsAlien()) {
        `LOG("WARNING: This unit is a Faceless!", , 'TwitchIntegration');

	    //Unit.GetUnitValue(class'X2Effect_SpawnUnit'.default.SpawnedUnitValueName, SpawnedUnitValue);
        //`LOG("fValue: " $ SpawnedUnitValue.fValue);
    }

    if (Unit.IsCivilian() || Unit.IsSoldier()) {
        // For civilians and Resistance soldiers, we only show the viewer name. We want to make sure it's
        // in the LastName slot, because the name shows as "First Last", so if LastName is empty there's
        // two spaces in a row, which is noticeable.
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

    //TwitchFlag = `XCOMGAME.Spawn(class'UIUnitFlag_Twitch', Pres.m_kUnitFlagManager);
    //TwitchFlag.InitFlag(Unit.GetReference());

    `GAMERULES.SubmitGameState(NewGameState);

	return ELR_NoInterrupt;
}

static protected function EventListenerReturn OnEnemyGroupSighted(Object EventData, Object EventSource, XComGameState GameState, Name Event, Object CallbackData) {
    local XComGameState_AIGroup AIGroupState;
    local StateObjectReference UnitRef;

    `LOG("OnEnemyGroupSighted; Event name: " $ Event, , 'TwitchIntegration');
    AIGroupState = XComGameState_AIGroup(EventData);

    foreach AIGroupState.m_arrMembers(UnitRef) {
        `LOG("Sighted unit ID " $ UnitRef.ObjectID, , 'TwitchIntegration');

        // TODO: need to interrupt the scamper visualization to show our messages
        class'UIUtilities_Twitch'.static.ShowTwitchName(UnitRef.ObjectID, GameState);
    }

    return ELR_InterruptEvent;
}