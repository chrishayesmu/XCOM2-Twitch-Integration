//---------------------------------------------------------------------------------------
//  FILE:   XComDownloadableContentInfo_TwitchIntegration.uc
//
//	Use the X2DownloadableContentInfo class to specify unique mod behavior when the
//  player creates a new campaign or loads a saved game.
//
//---------------------------------------------------------------------------------------
//  Copyright (c) 2016 Firaxis Games, Inc. All rights reserved.
//---------------------------------------------------------------------------------------

class X2DownloadableContentInfo_TwitchIntegration extends X2DownloadableContentInfo
	dependson(XComGameState_TwitchEventPoll);

/// <summary>
/// This method is run when the player loads a saved game directly into Strategy while this DLC is installed
/// </summary>
static event OnLoadedSavedGameToStrategy()
{
    `TILOG("OnLoadedSavedGameToStrategy");

    if (`TISTATEMGR == none) {
	    `XCOMGAME.Spawn(class'TwitchStateManager').Initialize();
    }
}

/// <summary>
/// Called just before the player launches into a tactical a mission while this DLC / Mod is installed.
/// Allows dlcs/mods to modify the start state before launching into the mission
/// </summary>
static event OnPreMission(XComGameState StartGameState, XComGameState_MissionSite MissionState)
{
    `TILOG("OnPreMission triggered");
    CopyStateObjectsToNewState(StartGameState);
}

/// <summary>
/// Called when the player is doing a direct tactical->tactical mission transfer. Allows mods to modify the
/// start state of the new transfer mission if needed
/// </summary>
static event ModifyTacticalTransferStartState(XComGameState TransferStartState)
{
    `TILOG("ModifyTacticalTransferStartState triggered");
    CopyStateObjectsToNewState(TransferStartState);
}

static function CopyStateObjectsToNewState(XComGameState NewGameState) {
    local XComGameState_TwitchObjectOwnership OwnershipState;
    local XComGameState_Unit UnitState;

    `TILOG("Copying ownership objects to new game state");

    // Copy all ownership states
    foreach `XCOMHISTORY.IterateByClassType(class'XComGameState_TwitchObjectOwnership', OwnershipState, , /* bUnlimitedSearch */ true) {
        UnitState = XComGameState_Unit(`XCOMHISTORY.GetGameStateForObjectID(OwnershipState.OwnedObjectRef.ObjectID));

        if (!class'X2EventListener_TwitchNames'.static.IsOwnershipTransient(UnitState)) {
            `TILOG("Copying ownership state for viewer " $ OwnershipState.TwitchLogin);
            NewGameState.ModifyStateObject(class'XComGameState_TwitchObjectOwnership', OwnershipState.ObjectID);
        }
        else {
            `TILOG("Skipping transient ownership state for viewer " $ OwnershipState.TwitchLogin);
        }
    }
}

// #region Console commands

/// <summary>
/// Casts a vote in the current poll as though it was cast by the specified viewer.
/// </summary>
exec function TwitchCastVote(string ViewerName, int Option) {
    local TwitchViewer Viewer;
    Viewer.Login = ViewerName;

	`TISTATEMGR.CastVote(Viewer, Option - 1);
}

/// <summary>
/// Executes a Twitch command as though it were coming from the specified viewer.
/// </summary>
exec function TwitchChatCommand(string ViewerLogin, string Command, optional string CommandBody) {
    local TwitchMessage Message;
    local TwitchViewer Viewer;
    local TwitchStateManager StateMgr;

    StateMgr = `TISTATEMGR;
    Message.Body = "!" $ Command;

    if (CommandBody != "") {
        Message.Body @= CommandBody;
    }

    if (StateMgr.TwitchChatConn.GetViewer(ViewerLogin, Viewer) == INDEX_NONE) {
        `TILOG("Viewer " $ ViewerLogin $ " not found, supplying fake viewer");
        Viewer.Login = ViewerLogin;
    }

    StateMgr.HandleChatCommand(Message, Viewer);
}

exec function TwitchCleanStates(optional bool bForce = false) {
    local int Index, NumStaleStates;
    local TwitchChatTcpLink ChatConn;
    local TwitchViewer Viewer;
    local XComGameState NewGameState;
    local XComGameStateHistory History;
    local XComGameState_TwitchObjectOwnership OwnershipState;
    local XComGameState_Unit Unit;

    if (`TI_IS_TAC_GAME && !bForce)
    {
        class'Helpers'.static.OutputMsg("------------------------------------------------------------------------------------------------------------------");
        class'Helpers'.static.OutputMsg("WARNING: Running this during a mission will clear raffle winners for any enemies/civilians.");
        class'Helpers'.static.OutputMsg("Those units will will be re-raffled and will likely be assigned to different viewers.");
        class'Helpers'.static.OutputMsg("It is therefore recommended to only use this command while in the Avenger.");
        class'Helpers'.static.OutputMsg("------------------------------------------------------------------------------------------------------------------");
        class'Helpers'.static.OutputMsg("   ");
        class'Helpers'.static.OutputMsg("To force this command anyway, run \"TwitchCleanStates true\".");
        return;
    }

    History = `XCOMHISTORY;
	NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Console Command: TwitchCleanStates");
    ChatConn = `TISTATEMGR != none ? `TISTATEMGR.TwitchChatConn : none;

    foreach History.IterateByClassType(class'XComGameState_TwitchObjectOwnership', OwnershipState) {
        Unit = XComGameState_Unit(History.GetGameStateForObjectID(OwnershipState.OwnedObjectRef.ObjectID));

        if (class'X2EventListener_TwitchNames'.static.IsOwnershipTransient(Unit)) {
            // TODO: if in tactical, this shouldn't include units on the mission
            class'Helpers'.static.OutputMsg("Deleting transient ownership of unit " $ Unit.GetFullName() $ " by viewer " $ OwnershipState.TwitchLogin);
            class'XComGameState_TwitchObjectOwnership'.static.DeleteOwnership(OwnershipState, NewGameState);
            NumStaleStates++;

            if (ChatConn != none)
            {
                // Update the viewer so they aren't marked as owning something
                Index = ChatConn.GetViewer(OwnershipState.TwitchLogin, /* unused out param*/ Viewer);

                if (Index != INDEX_NONE)
                {
                    ChatConn.Viewers[Index].OwnedObjectID = 0;
                }
            }
        }
    }

    if (NewGameState.GetNumGameStateObjects() > 0) {
        class'Helpers'.static.OutputMsg("Cleaning up " $ NumStaleStates $ " ownership objects");
		`GAMERULES.SubmitGameState(NewGameState);
	}
    else {
        class'Helpers'.static.OutputMsg("Did not find any stale ownership to clean up");
		`XCOMHISTORY.CleanupPendingGameState(NewGameState);
    }
}

/// <summary>
/// Connects to Twitch chat, forcibly disconnecting first if bForceReconnect is true.
/// </summary>
exec function TwitchConnect(bool bForceReconnect = false) {
    `TISTATEMGR.ConnectToTwitchChat(bForceReconnect);
}

exec function TwitchDebugSendRawIrc(string RawIrcMessage) {
    `TISTATEMGR.TwitchChatConn.DebugSendRawIrc(RawIrcMessage);
}

exec function TwitchDebugSendWhisper(string Recipient, string Message) {
    `TISTATEMGR.TwitchChatConn.QueueWhisper(Recipient, Message, 5.0);
}

/// <summary>
/// Ends the currently running poll, if any.
/// </summary>
exec function TwitchEndPoll() {
	`TISTATEMGR.ResolveCurrentPoll();
}

/// <summary>
/// Immediately executes the action with the given name (as specified in config).
/// </summary>
exec function TwitchExecuteAction(name ActionName) {
    local X2TwitchEventActionTemplate Action;

    Action = class'X2TwitchUtils'.static.GetTwitchEventActionTemplate(ActionName);

    if (Action == none) {
        class'Helpers'.static.OutputMsg("Did not find an Action template called " $ ActionName);
        return;
    }

    Action.Apply();
}

/// <summary>
/// Lists all viewers who own a unit. Does not distinguish between dead and living units, or units which aren't
/// on the current mission if any (such as Chosen or XCOM soldiers).
/// </summary>
exec function TwitchListRaffledViewers() {
    local string Message;
    local XComGameState_TwitchObjectOwnership OwnershipState;
    local XComGameState_Unit Unit;

    // Column headers
    class'Helpers'.static.OutputMsg("");
    Message =  `TI_RPAD("Object ID", " ", 12);
    Message $= `TI_RPAD("Viewer", " ", 35);
    Message $= "Unit Name";

    class'Helpers'.static.OutputMsg(Message);
    class'Helpers'.static.OutputMsg("-------------------------------------------------------");

    foreach `XCOMHISTORY.IterateByClassType(class'XComGameState_TwitchObjectOwnership', OwnershipState, , /* bUnlimitedSearch */ true) {
        Unit = XComGameState_Unit(`XCOMHISTORY.GetGameStateForObjectID(OwnershipState.OwnedObjectRef.ObjectID, eReturnType_Reference));

        // First column is deliberately wider than its header due to non-fixed-width font
        Message =  `TI_RPAD(OwnershipState.OwnedObjectRef.ObjectID, " ", 14);
        Message $= `TI_RPAD(OwnershipState.TwitchLogin, " ", 35);

        if (Unit != none) {
            Message $= Unit.GetFullName();
        }

        class'Helpers'.static.OutputMsg(Message);
        `TILOG(Message);
    }
}

/// <summary>
/// Executes a quick poll with predetermined results for testing purposes.
/// </summary>
exec function TwitchQuickPoll(ePollType PollType) {
    TwitchStartPoll(PollType, 2);
    TwitchCastVote("user1", 1);
    TwitchCastVote("user2", 2);
    TwitchCastVote("user3", 2);
    TwitchEndPoll();
}

/// <summary>
/// Re-raffles the unit closest to the mouse cursor. Follows standard raffle rules, so XCOM soldiers
/// cannot be re-raffled using this method.
/// </summary>
exec function TwitchRaffleUnitUnderMouse() {
	local XComGameState_TwitchObjectOwnership OwnershipState;
	local XComGameState_Unit Unit;
    local TwitchStateManager StateMgr;

    StateMgr = `TISTATEMGR;

	Unit = `CHEATMGR.GetClosestUnitToCursor(, /* bConsiderDead */ true);
	if (Unit == none) {
        return;
    }

    OwnershipState = class'XComGameState_TwitchObjectOwnership'.static.FindForObject(Unit.ObjectID);

    if (OwnershipState != none) {
        class'Helpers'.static.OutputMsg("Deleting ownership data for unit..");

        // Delete the existing ownership so this unit can be raffled
        class'XComGameState_TwitchObjectOwnership'.static.DeleteOwnership(OwnershipState);
    }

    class'Helpers'.static.OutputMsg("Triggering raffle of all unowned units");
    StateMgr.bUnraffledUnitsExist = true;
    StateMgr.fTimeSinceLastRaffle = 100.0f;
}

/// <summary>
/// Reassigns ownership of the unit closest to the mouse cursor to the given viewer. This method does not
/// use any raffling, and does work on XCOM soldiers. It also works on dead units.
/// </summary>
exec function TwitchReassignUnitUnderMouse(optional string ViewerLogin) {
	local XComGameState_TwitchObjectOwnership OwnershipState;
	local XComGameState_Unit Unit;

	Unit = `CHEATMGR.GetClosestUnitToCursor(, /* bConsiderDead */ true);
	if (Unit == none) {
        return;
    }

    // Make sure the given viewer doesn't already own something
    OwnershipState = class'XComGameState_TwitchObjectOwnership'.static.FindForUser(ViewerLogin);

    if (OwnershipState != none) {
        class'Helpers'.static.OutputMsg("Viewer already owns a unit. Owning multiple units is not allowed.");
        return;
    }

    OwnershipState = class'XComGameState_TwitchObjectOwnership'.static.FindForObject(Unit.ObjectID);

    // Don't submit a game state if we aren't changing anything
    if (OwnershipState != none && OwnershipState.TwitchLogin == ViewerLogin) {
        return;
    }

    if (OwnershipState == none && ViewerLogin == "") {
        return;
    }

    if (ViewerLogin == "") {
        if (Unit.IsCivilian()) {
            class'Helpers'.static.OutputMsg("WARNING: Civilian's original name is unknown");
        }

        class'XComGameState_TwitchObjectOwnership'.static.DeleteOwnership(OwnershipState);

        Unit = XComGameState_Unit(`XCOMHISTORY.GetGameStateForObjectID(OwnershipState.OwnedObjectRef.ObjectID));
        class'Helpers'.static.OutputMsg("Deleted ownership of unit and renamed it to '" $ Unit.GetFullName() $ "'");
    }
    else {
        class'X2EventListener_TwitchNames'.static.AssignOwnership(ViewerLogin, Unit.GetReference().ObjectID, , /* OverridePreviousOwnership */ true);
        class'Helpers'.static.OutputMsg("Reassigned owner of '" $ Unit.GetFullName() $ "' to viewer '" $ ViewerLogin $ "'");
    }
}

exec function TwitchUnassignViewer(string ViewerLogin)
{
	local XComGameState_TwitchObjectOwnership OwnershipState;

    OwnershipState = class'XComGameState_TwitchObjectOwnership'.static.FindForUser(ViewerLogin);

    if (OwnershipState == none) {
        class'Helpers'.static.OutputMsg("Viewer " $ ViewerLogin $ " does not own any units");
        return;
    }

    class'Helpers'.static.OutputMsg("Deleting unit ownership for viewer " $ ViewerLogin);
    class'XComGameState_TwitchObjectOwnership'.static.DeleteOwnership(OwnershipState);

}

/// <summary>
/// Starts a new poll with randomly-selected events from the given poll type.
/// </summary>
exec function TwitchStartPoll(ePollType PollType, int DurationInTurns) {
	`TISTATEMGR.StartPoll(PollType, DurationInTurns);
}

// #endregion