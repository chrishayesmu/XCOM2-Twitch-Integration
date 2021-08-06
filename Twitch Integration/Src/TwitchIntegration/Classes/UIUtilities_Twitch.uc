class UIUtilities_Twitch extends Object;

const TwitchIcon_3D = "img:///TwitchIntegration_UI.Icon_Twitch";

static function ShowTwitchName(int ObjectID, optional XComGameState NewGameState, optional bool bPermanent = false) {
	local Array<X2Action> arrActions;
    local X2Action_RevealAIBegin RevealAIAction;
    local X2Action_ShowTwitchNames ShowNamesAction;
	local XComGameStateContext Context;
	local XComGameStateVisualizationMgr VisMgr;
    local XComGameState_TwitchObjectOwnership OwnershipState;
    local Vector Position;

    OwnershipState = class'XComGameState_TwitchObjectOwnership'.static.FindForObject(ObjectID);

    if (OwnershipState == none) {
        return;
    }

	VisMgr = `XCOMVISUALIZATIONMGR;
    VisMgr.GetNodesOfType(VisMgr.VisualizationTree, class'X2Action_RevealAIBegin', arrActions);
    `LOG("There are " $ arrActions.Length $ " RevealAIBegin actions in current vis tree");

    if (arrActions.Length > 0) {
        // it's pretty unlikely we'll have multiple reveals at once, deal with that later
        RevealAIAction = X2Action_RevealAIBegin(arrActions[0]);
	    Context = RevealAIAction.StateChangeContext;

        ShowNamesAction = X2Action_ShowTwitchNames(class'X2Action_ShowTwitchNames'.static.CreateVisualizationAction(Context));

        VisMgr.ReplaceNode(ShowNamesAction, RevealAIAction);
		VisMgr.ConnectAction(RevealAIAction, VisMgr.BuildVisTree, true, ShowNamesAction);
    }

    `PRES.QueueWorldMessage(OwnershipState.TwitchUsername,
                            Position,
                            OwnershipState.OwnedObjectRef,
                            eColor_Purple,
                            class'UIWorldMessageMgr'.const.FXS_MSG_BEHAVIOR_READY,
                            /* _sId */ "twitch_name_" $ ObjectID,
                            /* _eBroadcastToTeams */,
                            /* _bUseScreenLocationParam */,
                            /* _vScreenLocationParam */,
                            /* _displayTime */ bPermanent ? -1.0 : 7.0,
                            /* deprecated */,
                            TwitchIcon_3D, , , , , , , NewGameState, true);
}