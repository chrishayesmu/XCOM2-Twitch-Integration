class UIUtilities_Twitch extends Object
    dependson(X2TwitchChatCommandTemplate);

const TwitchIcon_3D = "img:///TwitchIntegration_UI.Icon_Twitch";

static function string RPad(coerce string S, string Padding, int Length) {
    while (Len(S) < Length) {
        S $= Padding;
    }

    return S;
}

/**
 * Formats the given string in a style befitting a dead unit. Does not check whether
 * the corresponding config option is enabled; the caller must do that.
 */
static function string FormatDeadMessage(string S) {
    return "..." @ Locs(S) @ "...";
}

static function HideTwitchName(int ObjectID, optional UIWorldMessageMgr MessageMgr) {
    if (MessageMgr == none) {
        MessageMgr = `PRES.m_kWorldMessageManager;
    }

    // We want to hide both temporary and permanent messages so do both
    MessageMgr.RemoveMessage(GetMsgID(ObjectID, false));
    MessageMgr.RemoveMessage(GetMsgID(ObjectID, true));
}

static function string InsertEmotes(string InString, array<EmoteData> Emotes) {
    local int EmoteIndex;
    local string EmoteImagePath, OutString;
    local string StartString, EndString;

    OutString = InString;

    // Iterate backwards so we replace starting from the end of the message,
    // to avoid invalidating emote indices
    for (EmoteIndex = Emotes.Length - 1; EmoteIndex >= 0; EmoteIndex--) {
        EmoteImagePath = class'TwitchEmoteManager'.static.GetEmotePath(Emotes[EmoteIndex].EmoteCode);

        // If we can't load the emote for some reason, keep its text
        if (EmoteImagePath == "") {
            continue;
        }

        StartString = Left(OutString, Emotes[EmoteIndex].StartIndex);
        EndString = Right(OutString, Len(OutString) - Emotes[EmoteIndex].EndIndex - 1);

        OutString = StartString $ "<img src='" $ EmoteImagePath $ "' align='baseline' vspace='-5' width='22' height='22'>" $ EndString;
    }

    return OutString;
}

static function ShowTwitchName(int ObjectID, optional XComGameState NewGameState, optional bool bPermanent = false) {
    local float DisplayTime;
    local int MsgBehavior;
    local TwitchChatter Viewer;
    local XComGameState_TwitchObjectOwnership OwnershipState;
    local Vector Position;

    OwnershipState = class'XComGameState_TwitchObjectOwnership'.static.FindForObject(ObjectID);

    if (OwnershipState == none) {
        return;
    }

    `TISTATEMGR.GetViewer(OwnershipState.TwitchLogin, Viewer);
    DisplayTime = bPermanent ? 0.0 : 7.0;
    MsgBehavior = bPermanent ? class'UIWorldMessageMgr'.const.FXS_MSG_BEHAVIOR_STEADY : class'UIWorldMessageMgr'.const.FXS_MSG_BEHAVIOR_FLOAT;

    `PRES.QueueWorldMessage(`TIVIEWERNAME(Viewer),
                            Position,
                            OwnershipState.OwnedObjectRef,
                            eColor_Purple,
                            MsgBehavior,
                            /* _sId */ GetMsgId(ObjectID, bPermanent),
                            /* _eBroadcastToTeams */,
                            /* _bUseScreenLocationParam */,
                            /* _vScreenLocationParam */,
                            /* _displayTime */ DisplayTime,
                            /* deprecated */,
                            TwitchIcon_3D, , , , , , , NewGameState, true);
}

private static function string GetMsgId(int ObjectID, bool bPermanent) {
    local string MsgId;

    // The world messenger tries to update messages with the same ID, and it checks every param for changes
    // except for the display time, which of course is the only one we change. Accordingly we have to use different
    // message IDs for permanent messages.
    MsgId = "twitch_name_" $ ObjectID;

    if (bPermanent) {
        MsgId $= "_perm";
    }

    return MsgId;
}