class UIUtilities_Twitch extends Object;

static function ShowTwitchName(int ObjectID, optional XComGameState NewGameState) {
    local XComGameState_TwitchObjectOwnership OwnershipState;
    local Vector Position;

    OwnershipState = class'XComGameState_TwitchObjectOwnership'.static.FindForObject(ObjectID);

    if (OwnershipState == none) {
        return;
    }

    `PRES.QueueWorldMessage(OwnershipState.TwitchUsername,
                            Position,
                            OwnershipState.OwnedObjectRef,
                            eColor_Purple,
                            class'UIWorldMessageMgr'.const.FXS_MSG_BEHAVIOR_READY,
                            /* _sId */,
                            /* _eBroadcastToTeams */,
                            /* _bUseScreenLocationParam */,
                            /* _vScreenLocationParam */,
                            /* _displayTime */ 7.0,
                            /* deprecated */,
                            "img:///TwitchIntegration_UI.Icon_Twitch", , , , , , , NewGameState, true);
}