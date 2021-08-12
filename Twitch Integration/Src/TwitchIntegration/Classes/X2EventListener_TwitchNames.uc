class X2EventListener_TwitchNames extends X2EventListener
    config(TwitchIntegration);

var config bool bAssignUnitNames;

var config bool bAssignChosenNames;
var config bool bChosenNamesArePersistent;
//var config eTwitchRole MinRoleForChosen;

static function array<X2DataTemplate> CreateTemplates() {
	local array<X2DataTemplate> Templates;

    if (default.bAssignUnitNames) {
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

        ChooseViewerName(Unit, Unit, GameState, Event, none);
    }

    return ELR_NoInterrupt;
}

static protected function EventListenerReturn ChooseViewerName(Object EventData, Object EventSource, XComGameState GameState, Name Event, Object CallbackData) {
    local int ViewerIndex;
    local TwitchChatTcpLink TwitchConn;
    local TwitchStateManager TwitchMgr;
    local TwitchViewer Viewer;
    local XComGameState NewGameState;
	local XComGameState_Unit Unit;
    local XComGameState_TwitchObjectOwnership OwnershipState;
	local string FirstName, LastName;

	local XComPresentationLayer Pres;
	local UIUnitFlag UnitFlag;

	Pres = `PRES;
    TwitchMgr = `TISTATEMGR;
    TwitchConn = TwitchMgr.TwitchChatConn;
	Unit = XComGameState_Unit(EventSource);

    // UnitBeginPlay events can fire before we have a chance to initialize the TwitchStateManager
	if (Pres == none || TwitchMgr == none || Unit == none) {
		return ELR_NoInterrupt;
    }

    // Don't assign names until we've processed the full viewer list, or else names will be
    // biased towards people who chat the most
    if (!TwitchMgr.bIsViewerListPopulated) {
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
        // We'll have to try again later when there might be more viewers in the pool
        TwitchMgr.bUnraffledUnitsExist = true;
        return ELR_NoInterrupt;
    }

    Viewer = TwitchConn.Viewers[ViewerIndex];

	NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Assign Twitch Owner");

    // TODO: maybe we can make this game state transient if it's a non-Chosen enemy who will never be seen again
	OwnershipState = XComGameState_TwitchObjectOwnership(NewGameState.CreateStateObject(class'XComGameState_TwitchObjectOwnership'));
    OwnershipState.TwitchLogin = Viewer.Login;
    OwnershipState.OwnedObjectRef = Unit.GetReference();

    // Mark ownership in the viewer pool as well
    Viewer.OwnedObjectID = OwnershipState.OwnedObjectRef.ObjectID;
    TwitchConn.Viewers[ViewerIndex] = Viewer;

    `LOG("Assigning viewer " $ OwnershipState.TwitchLogin $ " at index " $ ViewerIndex $ " to unit " $ Unit.GetFullName(), , 'TwitchIntegration');

    if (Unit.IsCivilian() && Unit.IsAlien()) {
        `LOG("WARNING: This unit is a Faceless!", , 'TwitchIntegration');
    }

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
    UnitFlag = Pres.m_kUnitFlagManager.GetFlagForObjectID(Unit.GetReference().ObjectID);

    if (UnitFlag != none) {
        UnitFlag.UpdateFromUnitState(Unit, true);
    }
    else {
        Pres.m_kUnitFlagManager.AddFlag(Unit.GetReference());
    }

    `GAMERULES.SubmitGameState(NewGameState);

	return ELR_NoInterrupt;
}

static protected function EventListenerReturn OnEnemyGroupSighted(Object EventData, Object EventSource, XComGameState GameState, Name Event, Object CallbackData) {
	local VisualizationActionMetadata EmptyMetadata;
	local VisualizationActionMetadata Metadata;
	local Array<X2Action> arrActions;
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
    `LOG("OnEnemyGroupSighted: there are " $ arrActions.Length $ " RevealAIBegin actions in current vis tree");

    // TODO: sometimes there are no RevealAIBegin actions in the vis tree for some reason (esp. spawning from psi gate?)
    if (arrActions.Length == 0) {
        return ELR_NoInterrupt;
    }

    RevealAIAction = X2Action_RevealAIBegin(arrActions[0]);
    Context = RevealAIAction.StateChangeContext;

    foreach AIGroupState.m_arrMembers(UnitRef) {
        `LOG("Sighted unit ID " $ UnitRef.ObjectID, , 'TwitchIntegration');

        OwnershipState = class'XComGameState_TwitchObjectOwnership'.static.FindForObject(UnitRef.ObjectID);

        if (OwnershipState == none) {
            continue;
        }

        OwnedObject = `XCOMHISTORY.GetGameStateForObjectID(OwnershipState.OwnedObjectRef.ObjectID, eReturnType_Reference);

	    Metadata = EmptyMetadata;
	    Metadata.StateObject_OldState = OwnedObject;
	    Metadata.StateObject_NewState = OwnedObject;
	    Metadata.VisualizeActor = History.GetVisualizer(OwnedObject.ObjectID);

        // TODO: might have to make our own action in order to show the flyover longer; this one's pretty short
        // TODO: pull Twitch display name instead of login
	    SoundAndFlyOver = X2Action_PlaySoundAndFlyOver(class'X2Action_PlaySoundAndFlyOver'.static.AddToVisualizationTree(Metadata, Context, false, RevealAIAction));
	    SoundAndFlyOver.SetSoundAndFlyOverParameters(none, OwnershipState.TwitchLogin, '', eColor_Purple, class'UIUtilities_Twitch'.const.TwitchIcon_3D,
                                                     0, /* _BlockUntilFinished */, /* _VisibleTeam */, class'UIWorldMessageMgr'.const.FXS_MSG_BEHAVIOR_READY);
    }

    return ELR_InterruptEvent;
}

static protected function EventListenerReturn OnUnitRemovedFromPlay(Object EventData, Object EventSource, XComGameState GameState, Name Event, Object CallbackData) {
    local StateObjectReference EffectRef;
	local XComGameStateHistory History;
	local XComGameState_Effect EffectState;
    local XComGameState_Unit CivUnitState;

    `LOG("OnUnitRemovedFromPlay triggered");

    CivUnitState = XComGameState_Unit(EventData);

    `LOG("Unit's object ID: " $ CivUnitState.ObjectID);
    `LOG(`SHOWVAR(CivUnitState.IsCivilian()));
    `LOG(`SHOWVAR(CivUnitState.IsAlien()));

    if (!CivUnitState.IsCivilian() || !CivUnitState.IsAlien()) {
        return ELR_NoInterrupt;
    }

    History = `XCOMHISTORY;

    foreach CivUnitState.AffectedByEffects(EffectRef) {
        EffectState = XComGameState_Effect(History.GetGameStateForObjectID(EffectRef.ObjectID));

        if (!EffectState.GetX2Effect().IsA('X2Effect_SpawnFaceless')) {
            `LOG("Found effect but it's not SpawnFaceless, moving on");
            continue;
        }

        `LOG(`SHOWVAR(EffectState.ApplyEffectParameters.SourceStateObjectRef.ObjectID));
    }
}