class X2EventListener_TwitchNames extends X2EventListener
    config(TwitchIntegration);

static function array<X2DataTemplate> CreateTemplates() {
	local array<X2DataTemplate> Templates;

    Templates.AddItem(CleanUpOwnershipStates());
    Templates.AddItem(UnitAssignName());
    Templates.AddItem(UnitShowName());

	return Templates;
}

static function X2EventListenerTemplate CleanUpOwnershipStates() {
    local CHEventListenerTemplate Template;

    `CREATE_X2TEMPLATE(class'CHEventListenerTemplate', Template, 'CleanUpTwitchOwnership');

    Template.RegisterInStrategy = true;
    Template.RegisterInTactical = true;
    Template.AddEvent('OnTacticalBeginPlay', RemoveTransientOwnershipStates);
    Template.AddEvent('PreCompleteStrategyFromTacticalTransfer', RemoveTransientOwnershipStates);

    return Template;
}

static function X2EventListenerTemplate UnitAssignName() {
	local CHEventListenerTemplate Template;

	`CREATE_X2TEMPLATE(class'CHEventListenerTemplate', Template, 'AssignTwitchName');

	Template.RegisterInTactical = true;
	Template.AddEvent('OnUnitBeginPlay', ChooseViewerName);
    Template.AddEvent('UnitRemovedFromPlay', OnUnitRemovedFromPlay);
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

// #region Check if either unit or viewer already has associated ownership
    OwnershipState = class'XComGameState_TwitchObjectOwnership'.static.FindForUser(ViewerLogin);

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

    StateMgr = `TISTATEMGR;
    ViewerIndex = StateMgr.TwitchChatConn.GetViewer(ViewerLogin, Viewer);
    Unit = XComGameState_Unit(`XCOMHISTORY.GetGameStateForObjectID(ObjID));

    if (NewGameState == none) {
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
    if (Unit.GetTeam() == eTeam_XCom && ( Unit.IsSoldier() || Unit.GetMyTemplate().bIsCosmetic )) {
        // Don't do anything in this case; we don't modify soldiers because the player has full agency to do that
        // TODO: need to check if this is a cosmetic unit also (i.e. Gremlin)
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

    // Update our Twitch unit flag to show the viewer name
    class'X2TwitchUtils'.static.SyncUnitFlag(Unit, OwnershipState);

    if (Unit.IsChosen()) {
        UpdateChosenGameStateFromUnit(Unit);
    }

    if (bCreatedGameState) {
        `GAMERULES.SubmitGameState(NewGameState);
    }
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
	local XComGameState_Unit Unit;
    local XComGameState_TwitchObjectOwnership OwnershipState;

    if (!`TI_CFG(bAssignUnitNames)) {
		return ELR_NoInterrupt;
    }

    TwitchMgr = `TISTATEMGR;
    TwitchConn = TwitchMgr.TwitchChatConn;
	Unit = XComGameState_Unit(EventSource);

    `TILOG("In ChooseViewerName for unit " $ Unit.GetFullName());

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
        `TILOG("Aborting ChooseViewerName: unit is already owned by " $ OwnershipState.TwitchLogin);
        // Someone already owns this unit
        return ELR_NoInterrupt;
    }

    // Don't give Twitch names to XCOM soldiers or Gremlins, they should have persistent names assigned by the streamer
    // (Non-XCOM soldiers are Resistance members, who should receive names)
    // TODO: when you rescue a Resistance member, do they join your roster?
    if (Unit.GetTeam() == eTeam_XCom && ( Unit.IsSoldier() || Unit.GetMyTemplate().bIsCosmetic )) {
        `TILOG("Aborting ChooseViewerName: unit is non-raffleable XCOM unit");
        return ELR_NoInterrupt;
    }

    // Don't give names to player Avatars
    // TODO: make this configurable
    if (Unit.GetTeam() == eTeam_XCom && Unit.GetMyTemplate().CharacterGroupName == 'AdventPsiWitch') {
        `TILOG("Aborting ChooseViewerName: unit is non-raffleable XCOM Avatar");
        return ELR_NoInterrupt;
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

    if (Unit.IsCivilian() && Unit.IsAlien()) {
        `TILOG("WARNING: This unit is a Faceless!");
    }

	return ELR_NoInterrupt;
}

static protected function EventListenerReturn OnEnemyGroupSighted(Object EventData, Object EventSource, XComGameState GameState, Name Event, Object CallbackData) {
    local TwitchViewer Viewer;
	local VisualizationActionMetadata EmptyMetadata;
	local VisualizationActionMetadata Metadata;
	local Array<X2Action> arrActions;
    local X2Action_Twitch_ToggleNameplate NameplateAction;
    local X2Action_RevealAIBegin RevealAIAction;
	local X2Action_PlaySoundAndFlyOver SoundAndFlyover;
	local XComGameStateContext Context;
	local XComGameStateHistory History;
	local XComGameStateVisualizationMgr VisMgr;
    local XComGameState_AIGroup AIGroupState;
    local XComGameState_TwitchObjectOwnership OwnershipState;
    local XComGameState_BaseObject OwnedObject;
    local StateObjectReference UnitRef;

    AIGroupState = XComGameState_AIGroup(EventData);
	History = `XCOMHISTORY;
	VisMgr = `XCOMVISUALIZATIONMGR;

    VisMgr.GetNodesOfType(VisMgr.VisualizationTree, class'X2Action_RevealAIBegin', arrActions);
    `TILOG("There are " $ arrActions.Length $ " RevealAIBegin actions in current vis tree");

    // TODO: sometimes there are no RevealAIBegin actions in the vis tree for some reason (esp. spawning from psi gate?)
    if (arrActions.Length == 0) {
        return ELR_NoInterrupt;
    }

    RevealAIAction = X2Action_RevealAIBegin(arrActions[0]);
    Context = RevealAIAction.StateChangeContext;

    foreach AIGroupState.m_arrMembers(UnitRef) {
        OwnershipState = class'XComGameState_TwitchObjectOwnership'.static.FindForObject(UnitRef.ObjectID);

        if (OwnershipState == none) {
            continue;
        }

        OwnedObject = History.GetGameStateForObjectID(OwnershipState.OwnedObjectRef.ObjectID, eReturnType_Reference);

	    Metadata = EmptyMetadata;
	    Metadata.StateObject_OldState = OwnedObject;
	    Metadata.StateObject_NewState = OwnedObject;
	    Metadata.VisualizeActor = History.GetVisualizer(OwnedObject.ObjectID);

        NameplateAction = X2Action_Twitch_ToggleNameplate(class'X2Action_Twitch_ToggleNameplate'.static.AddToVisualizationTree(Metadata, Context, false, RevealAIAction));
        NameplateAction.bEnableNameplate = true;
    }

    return ELR_InterruptEvent;
}

static protected function EventListenerReturn OnUnitRemovedFromPlay(Object EventData, Object EventSource, XComGameState GameState, Name Event, Object CallbackData) {
    local StateObjectReference EffectRef;
	local XComGameStateHistory History;
    local XComGameState NewGameState;
	local XComGameState_Effect EffectState;
    local XComGameState_TwitchObjectOwnership Ownership;
    local XComGameState_Unit CivUnitState;

    CivUnitState = XComGameState_Unit(EventData);

    // Check that this civilian is a Faceless
    if (!CivUnitState.IsCivilian() || !CivUnitState.IsAlien()) {
        return ELR_NoInterrupt;
    }

    History = `XCOMHISTORY;
    Ownership = class'XComGameState_TwitchObjectOwnership'.static.FindForObject(CivUnitState.GetReference().ObjectID);

    foreach CivUnitState.AffectedByEffects(EffectRef) {
        EffectState = XComGameState_Effect(History.GetGameStateForObjectID(EffectRef.ObjectID));

        if (!EffectState.GetX2Effect().IsA('X2Effect_SpawnFaceless')) {
            continue;
        }

    	NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Twitch Faceless Owner Swap");
        AssignOwnership(Ownership.TwitchLogin, EffectState.CreatedObjectReference.ObjectID, NewGameState, , true);

        // Need to delete ownership of the original civilian unit
        NewGameState.RemoveStateObject(Ownership.ObjectID);

        // TODO: probably need to delete the nameplate of the civilian and create a new one attached to the Faceless object ID

        `GAMERULES.SubmitGameState(NewGameState);

        break;
    }

    return ELR_NoInterrupt;
}

static protected function EventListenerReturn RemoveTransientOwnershipStates(Object EventData, Object EventSource, XComGameState GameState, Name Event, Object CallbackData) {
	local XComGameStateHistory History;
    local XComGameState NewGameState;
    local XComGameState_TwitchObjectOwnership OwnershipState;
    local XComGameState_Unit Unit;

    `TILOG("Cleaning up transient ownership states for event " $ Event);

    History = `XCOMHISTORY;
	NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Delete Transient Twitch Ownership");

    foreach History.IterateByClassType(class'XComGameState_TwitchObjectOwnership', OwnershipState, , /* bUnlimitedSearch */ true) {
        Unit = XComGameState_Unit(History.GetGameStateForObjectID(OwnershipState.OwnedObjectRef.ObjectID, eReturnType_Reference));

        if (!IsOwnershipTransient(Unit)) {
            continue;
        }

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

static protected function bool IsOwnershipTransient(XComGameState_Unit Unit) {
    // Friendly soldiers and cosmetic units (i.e. Gremlins) have permanent ownership
    if (Unit.GetTeam() == eTeam_XCom && ( Unit.IsSoldier() || Unit.GetMyTemplate().bIsCosmetic )) {
        return false;
    }

    // TODO XComGameState_AdventChosen
    if (Unit.IsChosen()) {
        return false;
    }

    return true;
}

static protected function UpdateChosenGameStateFromUnit(XComGameState_Unit ChosenUnit) {
	local name UnitTemplate;
    local XComGameState_AdventChosen ChosenState;

    foreach `XCOMHISTORY.IterateByClassType(class'XComGameState_AdventChosen', ChosenState) {
        if (ChosenState.GetChosenTemplate() == ChosenUnit.GetMyTemplate()) {
            `TILOG("Identified Chosen from template: " $ `SHOWVAR(ChosenUnit.GetMyTemplate().CharacterGroupName));
        }
	}
}