class X2EventListener_TwitchNames extends X2EventListener
    config(TwitchIntegration);

const DetailedLogs = false;

static function array<X2DataTemplate> CreateTemplates() {
	local array<X2DataTemplate> Templates;

    Templates.AddItem(CleanUpOwnershipStates());
    Templates.AddItem(UnitAssignName());

	return Templates;
}

static function X2EventListenerTemplate CleanUpOwnershipStates() {
    local CHEventListenerTemplate Template;

    `CREATE_X2TEMPLATE(class'CHEventListenerTemplate', Template, 'CleanUpTwitchOwnership');

    Template.RegisterInStrategy = true;
    Template.RegisterInTactical = true;
    Template.AddEvent('OnTacticalBeginPlay', RemoveTransientOwnershipStates);
    Template.AddCHEvent('PreCompleteStrategyFromTacticalTransfer', OnPreCompleteStrategyFromTacticalTransfer, ELD_Immediate);

    return Template;
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

// Assigns ownership of an object (currently assumed to be an XComGameState_Unit) to a Twitch viewer. Will modify the
// unit as necessary to update its name or other attributes to match the viewer. If AllowMultipleOwnership is true,
// this will bypass the normal check to make sure each viewer doesn't own more than one unit. DO NOT DO THIS UNLESS
// YOU ARE ABOUT TO DELETE THE PREVIOUS OWNERSHIP.
//
// Returns the ownership state of the unit after this operation, which may not match the provided viewer if the object was
// already owned by somebody else. The return value will be none if the viewer already owns a different object.
static function XComGameState_TwitchObjectOwnership AssignOwnership(string ViewerLogin, int ObjID, optional XComGameState NewGameState, optional bool OverridePreviousOwnership = false, optional bool AllowMultipleOwnership = false) {
    local bool bCreatedGameState;
    local int ViewerIndex;
	local string FirstName, LastName;
    local TwitchStateManager StateMgr;
    local TwitchViewer Viewer;
    local XComGameState_TwitchObjectOwnership OwnershipState;
	local XComGameState_Unit Unit;

    StateMgr = `TISTATEMGR;
    ViewerIndex = StateMgr.TwitchChatConn.GetViewer(ViewerLogin, Viewer);
    Unit = XComGameState_Unit(`XCOMHISTORY.GetGameStateForObjectID(ObjID));

// #region Check if either unit or viewer already has associated ownership
    // Start by handling the Chosen units specially, because their ownership needs to persist between missions
    // but it needs separate logic to do so
    if (Unit.IsChosen()) {
        OwnershipState = class'XComGameState_TwitchObjectOwnership'.static.FindForChosen(Unit.GetMyTemplate().CharacterGroupName);

        if (OwnershipState != none) {
            // If the ownership is from a previous mission, we'll need to change object IDs
            if (Unit.GetReference().ObjectID != OwnershipState.OwnedObjectRef.ObjectID) {
                OwnershipState = OwnershipState.ChangeObjectRef(Unit.GetReference(), NewGameState);
            }

            class'X2TwitchUtils'.static.SyncUnitFlag(Unit);

            return OwnershipState;
        }
    }

    OwnershipState = class'XComGameState_TwitchObjectOwnership'.static.FindForUser(ViewerLogin, NewGameState);

    if (OwnershipState != none && !AllowMultipleOwnership) {
        `TILOG("Viewer " $ ViewerLogin $ " already owns something: " $ `SHOWVAR(OwnershipState.OwnedObjectRef.ObjectID));
        return OwnershipState.OwnedObjectRef.ObjectID == ObjID ? OwnershipState : none;
    }

    OwnershipState = class'XComGameState_TwitchObjectOwnership'.static.FindForObject(ObjID);

    if (OwnershipState != none && !OverridePreviousOwnership) {
        `TILOG("Object " $ ObjID $ " is already owned by " $ OwnershipState.TwitchLogin);
        return OwnershipState;
    }

    if (OwnershipState != none && OwnershipState.TwitchLogin == ViewerLogin) {
        return OwnershipState;
    }
// #endregion

    if (NewGameState == none || NewGameState.bReadOnly) {
    	NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Assign Twitch Owner");
        bCreatedGameState = true;
    }

    `TILOG("Assigning viewer " $ ViewerLogin $ " at index " $ ViewerIndex $ " to unit " $ Unit.GetFullName() $ " with object ID " $ ObjID);

// #region Create or update ownership state
    if (OwnershipState == none) {
        OwnershipState = XComGameState_TwitchObjectOwnership(NewGameState.CreateNewStateObject(class'XComGameState_TwitchObjectOwnership'));
    }
    else {
        OwnershipState = XComGameState_TwitchObjectOwnership(NewGameState.ModifyStateObject(class'XComGameState_TwitchObjectOwnership', OwnershipState.ObjectID));
    }

    OwnershipState.TwitchLogin = Viewer.Login;
    OwnershipState.OwnedObjectRef = Unit.GetReference();
// #endregion

// #region Mark the viewer as owning something so they don't get raffled again
if (ViewerIndex != INDEX_NONE) {
    Viewer.OwnedObjectID = ObjID;
    StateMgr.TwitchChatConn.Viewers[ViewerIndex] = Viewer;
}
// #endregion

// #region Modify unit attributes as needed
    // Update our Twitch unit flag to show the viewer name. We want to do this *before* changing
    // the unit name, because we want the unit flag to show the original unit name, with our nameplate underneath.
    class'X2TwitchUtils'.static.SyncUnitFlag(Unit, OwnershipState);

    if (Unit.GetTeam() == eTeam_XCom && ( Unit.IsSoldier() || Unit.GetMyTemplate().bIsCosmetic )) {
        // Don't do anything in this case; we don't modify soldiers because the player has full agency to do that
    }
    else {
        Unit = XComGameState_Unit(NewGameState.ModifyStateObject(class'XComGameState_Unit', Unit.GetReference().ObjectID));

        if (Unit.IsCivilian() || Unit.IsSoldier()) {
            // For civilians and Resistance soldiers, we only show the viewer name. We want to make sure it's
            // in the LastName slot, because the name shows as "First Last", so if LastName is empty there's
            // two spaces in a row, which is noticeable.
            FirstName = "";
            LastName = `TIVIEWERNAME(Viewer);
        }
        else {
            FirstName = `TIVIEWERNAME(Viewer);
            LastName = "(" $ Unit.GetName(eNameType_Full) $ ")";
        }

        Unit.SetUnitName(FirstName, LastName, "");
    }
// #endregion

    // For Chosen, we need a little extra info and have to modify a more global game state
    if (Unit.IsChosen()) {
        OwnershipState.bIsChosenUnit = true;
        OwnershipState.ChosenCharacterGroupName = Unit.GetMyTemplate().CharacterGroupName;

        UpdateChosenGameStateFromUnit(Unit, NewGameState, Viewer);
    }

    if (bCreatedGameState) {
        `GAMERULES.SubmitGameState(NewGameState);
    }

    `XEVENTMGR.TriggerEvent('TwitchUnitOwnerAssigned', /* EventData */ OwnershipState, /* EventSource */, NewGameState);

    return OwnershipState;
}

/// <summary>
/// Assigns viewer names to any units in the current mission that don't already have names.
/// </summary>
static protected function EventListenerReturn AssignNamesToUnits(Object EventData, Object EventSource, XComGameState GameState, Name Event, Object CallbackData) {
    local XComGameState_TwitchObjectOwnership OwnershipState;
	local XComGameState_Unit Unit;

    if (!`TI_CFG(bAssignUnitNames)) {
        return ELR_NoInterrupt;
    }

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
    local TwitchChatTcpLink TwitchConn;
    local TwitchStateManager TwitchMgr;
    local TwitchViewer Viewer;
	local XComGameState_Unit OriginalUnit, Unit;
    local XComGameState_TwitchObjectOwnership OwnershipState;

    if (!`TI_CFG(bAssignUnitNames)) {
		return ELR_NoInterrupt;
    }

    TwitchMgr = `TISTATEMGR;
    TwitchConn = TwitchMgr.TwitchChatConn;
	Unit = XComGameState_Unit(EventSource);

    `TILOG("In ChooseViewerName for event " $ Event $ " and unit " $ Unit.GetFullName(), DetailedLogs);

    // UnitBeginPlay events can fire before we have a chance to initialize the TwitchStateManager
	if (TwitchMgr == none) {
        `TILOG("Aborting ChooseViewerName: TwitchStateManager is none");
		return ELR_NoInterrupt;
    }

    // Don't assign names until we've processed the full viewer list, or else names will be
    // biased towards people who chat the most
    if (!TwitchMgr.bIsViewerListPopulated) {
        `TILOG("Aborting ChooseViewerName: viewer list is not populated");
        return ELR_NoInterrupt;
    }

    OwnershipState = class'XComGameState_TwitchObjectOwnership'.static.FindForObject(Unit.ObjectID);

    if (OwnershipState != none) {
        `TILOG("Aborting ChooseViewerName: unit is already owned by " $ OwnershipState.TwitchLogin, DetailedLogs);
        // Someone already owns this unit
        return ELR_NoInterrupt;
    }

    // Don't give Twitch names to XCOM soldiers or Gremlins, they should have persistent names assigned by the streamer
    // (Non-XCOM soldiers are Resistance members, who should receive names)
    // TODO: when you rescue a Resistance member, do they join your roster?
    if (Unit.GetTeam() == eTeam_XCom && ( Unit.IsSoldier() || Unit.GetMyTemplate().bIsCosmetic )) {
        `TILOG("Aborting ChooseViewerName: unit is non-raffleable XCOM unit", DetailedLogs);
        return ELR_NoInterrupt;
    }

    // Don't give names to player Avatars; let player assign them manually
    if (Unit.GetTeam() == eTeam_XCom && Unit.GetMyTemplate().CharacterGroupName == 'AdventPsiWitch') {
        `TILOG("Aborting ChooseViewerName: unit is non-raffleable XCOM Avatar", DetailedLogs);
        return ELR_NoInterrupt;
    }

    OriginalUnit = class'X2TwitchUtils'.static.FindSourceUnitFromSpawnEffect(Unit, GameState);

    if (OriginalUnit != none) {
        `TILOG("Unit appears to be spawned from something else. Attempting to transfer ownership");

        if (TransferOwnershipFromOriginal(OriginalUnit, Unit)) {
            `TILOG("Ownership transferred successfully.");
    		return ELR_NoInterrupt;
        }

        `TILOG("Failed to transfer ownership. Raffle proceeding normally.");
    }

    // Pick a viewer at random, if any available
    ViewerIndex = TwitchMgr.RaffleViewer();

    if (ViewerIndex == INDEX_NONE) {
        // We'll have to try again later when there might be more viewers in the pool
        `TILOG("Unable to raffle unit " $ Unit.GetFullName() $ " because there are no viewers available");
        TwitchMgr.bUnraffledUnitsExist = true;
        return ELR_NoInterrupt;
    }

    Viewer = TwitchConn.Viewers[ViewerIndex];
    AssignOwnership(Viewer.Login, Unit.GetReference().ObjectID);

	return ELR_NoInterrupt;
}

static protected function EventListenerReturn OnPreCompleteStrategyFromTacticalTransfer(Object EventData, Object EventSource, XComGameState GameState, Name Event, Object CallbackData) {
    local int HistoryIndex;
	local XComGameStateHistory History;
    local XComGameState OldGameState, NewGameState;
    local XComGameState_TwitchObjectOwnership OwnershipState;
    local XComGameState_Unit Unit;

    // When this event occurs, there's already an archive state and a strat start state in history and everything prior is gone.
    // We have to go back to the archive state to find our ownership objects.
    History = `XCOMHISTORY;
    HistoryIndex = History.GetCurrentHistoryIndex() - 1;
    OldGameState = History.GetGameStateFromHistory(HistoryIndex);
	NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Transfer Ownership to Strategy");

    `TILOG("Copying ownership states to strat layer. Looking at history index " $ HistoryIndex);

    foreach OldGameState.IterateByClassType(class'XComGameState_TwitchObjectOwnership', OwnershipState) {
        `TILOG("Looking at ownership state for viewer " $ OwnershipState.TwitchLogin);
        Unit = XComGameState_Unit(History.GetGameStateForObjectID(OwnershipState.OwnedObjectRef.ObjectID, eReturnType_Reference));

        if (IsOwnershipTransient(Unit)) {
            `TILOG("Skipping transient unit " $ Unit.GetFullName());
            continue;
        }

        `TILOG("Copying non-transient state object: Unit is " $ Unit.GetFullName() $ " and owner is " $ OwnershipState.TwitchLogin);
        NewGameState.ModifyStateObject(class'XComGameState_TwitchObjectOwnership', OwnershipState.ObjectID);
    }

    if (NewGameState.GetNumGameStateObjects() > 0) {
        `TILOG("Transferring " $ NewGameState.GetNumGameStateObjects() $ " state objects back to strat layer");
		`GAMERULES.SubmitGameState(NewGameState);
	}
    else {
        `TILOG("No game state objects remained to transfer to strat layer");
		`XCOMHISTORY.CleanupPendingGameState(NewGameState);
    }

    return ELR_NoInterrupt;
}

static protected function EventListenerReturn RemoveTransientOwnershipStates(Object EventData, Object EventSource, XComGameState GameState, Name Event, Object CallbackData) {
    local int HistoryIndex;
	local XComGameStateHistory History;
    local XComGameState OldGameState, NewGameState;
    local XComGameState_TwitchObjectOwnership OwnershipState;
    local XComGameState_Unit Unit;

    History = `XCOMHISTORY;
	NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Delete Transient Twitch Ownership");
    HistoryIndex = History.GetCurrentHistoryIndex() - 1;
    OldGameState = History.GetGameStateFromHistory(HistoryIndex);

    `TILOG("Cleaning up transient ownership states for event " $ Event $ ". Looking at history index " $ HistoryIndex);

    foreach OldGameState.IterateByClassType(class'XComGameState_TwitchObjectOwnership', OwnershipState) {
        `TILOG("Looking at ownership state for viewer " $ OwnershipState.TwitchLogin);
        Unit = XComGameState_Unit(History.GetGameStateForObjectID(OwnershipState.OwnedObjectRef.ObjectID, eReturnType_Reference));

        if (!IsOwnershipTransient(Unit)) {
            `TILOG("Skipping non-transient unit " $ Unit.GetFullName());
            continue;
        }

        `TILOG("Removing transient state object: Unit is " $ Unit.GetFullName() $ " and owner is " $ OwnershipState.TwitchLogin);
        NewGameState.RemoveStateObject(OwnershipState.ObjectID);
    }

    `TILOG("Removing " $ NewGameState.GetNumGameStateObjects() $ " game state objects");

    if (NewGameState.GetNumGameStateObjects() > 0) {
		`GAMERULES.SubmitGameState(NewGameState);
	}
    else {
		History.CleanupPendingGameState(NewGameState);
    }

    return ELR_NoInterrupt;
}

static function bool IsOwnershipTransient(XComGameState_Unit Unit) {
    // Friendly soldiers and the Chosen have permanent ownership
    // TODO: soldiers may be created in the tac-to-strat transition (rewards/rescues?)
    if (Unit.IsSoldier() || Unit.IsChosen()) {
        return false;
    }

    return true;
}

static protected function bool TransferOwnershipFromOriginal(XComGameState_Unit OriginalUnit, XComGameState_Unit NewUnit) {
    local string TwitchLogin;
    local XComGameState NewGameState;
    local XComGameState_TwitchObjectOwnership OwnershipState;

    OwnershipState = class'XComGameState_TwitchObjectOwnership'.static.FindForObject(OriginalUnit.GetReference().ObjectID);

    if (OwnershipState == none) {
        `TILOG("Didn't find an original ownership state to transfer");

        // Original unit didn't have an owner, so raffle this unit off
        return false;
    }

    NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Twitch Transfer Ownership To Spawned Unit");

    TwitchLogin = OwnershipState.TwitchLogin;
    class'XComGameState_TwitchObjectOwnership'.static.DeleteOwnership(OwnershipState, NewGameState);

    `TILOG("Assigning ownership state to new unit");
    OwnershipState = AssignOwnership(TwitchLogin, NewUnit.GetReference().ObjectID, NewGameState, , /* AllowMultipleOwnership */ true);

    `GAMERULES.SubmitGameState(NewGameState);

    return (OwnershipState != none);
}

static protected function UpdateChosenGameStateFromUnit(XComGameState_Unit ChosenUnit, XComGameState NewGameState, TwitchViewer Viewer) {
    local XComGameState_AdventChosen ChosenState;

    `TILOG("UpdateChosenGameStateFromUnit entered");

    // TODO: this might have to happen during transition back to strat layer
    foreach `XCOMHISTORY.IterateByClassType(class'XComGameState_AdventChosen', ChosenState) {
        if (ChosenState.GetChosenTemplate() == ChosenUnit.GetMyTemplate()) {
            break;
        }
	}

    `TILOG("Identified Chosen from template: " $ `SHOWVAR(ChosenUnit.GetMyTemplate().CharacterGroupName));

    ChosenState = XComGameState_AdventChosen(NewGameState.ModifyStateObject(class'XComGameState_AdventChosen', ChosenState.ObjectID));
    ChosenState.FirstName = "";
    ChosenState.LastName = `TIVIEWERNAME(Viewer);
    ChosenState.Nickname = "";

    `TILOG("Chosen last name is now " $ ChosenState.LastName);
}

static function bool IsSpawnedFromExistingUnit(XComGameState_Unit NewUnit, XComGameState GameState) {
    local UnitValue UnitVal;
    local XComGameState_Unit Unit;

    // Check for our own flag first, which is needed because not all events include the source unit
    NewUnit.GetUnitValue('Twitch_SpawnedFrom', UnitVal);

    if (UnitVal.fValue > 0) {
        return true;
    }

    // X2Effect_SpawnUnit always sets a unit value with the new unit's object ID
    foreach GameState.IterateByClassType(class'XComGameState_Unit', Unit) {
        Unit.GetUnitValue(class'X2Effect_SpawnUnit'.default.SpawnedUnitValueName, UnitVal);

        if (UnitVal.fValue > 0 && int(UnitVal.fValue) == NewUnit.GetReference().ObjectID) {
            // Set this for later reference; we shouldn't need it past the next turn
            NewUnit.SetUnitFloatValue('Twitch_SpawnedFrom', Unit.GetReference().ObjectID, eCleanup_BeginTurn);
            return true;
        }
    }

    return false;
}