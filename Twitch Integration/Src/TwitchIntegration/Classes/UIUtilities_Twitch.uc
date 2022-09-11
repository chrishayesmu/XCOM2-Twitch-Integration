class UIUtilities_Twitch extends Object;

const TwitchIcon_3D = "img:///TwitchIntegration_UI.Icon_Twitch";

var protected array<string> arrTwitchEmotes;

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

static function string GetEmoteImagePath(string Emote) {
    local int Index;

    Index = default.arrTwitchEmotes.Find(Emote);

    // Need to check the strings match manually because apparently array.Find uses case-insensitive matches for strings
    if (Index == INDEX_NONE || default.arrTwitchEmotes[Index] != Emote) {
        return "";
    }

    return "img:///TwitchIntegration_UI.Emotes." $ default.arrTwitchEmotes[Index];
}

static function HideTwitchName(int ObjectID, optional UIWorldMessageMgr MessageMgr) {
    if (MessageMgr == none) {
        MessageMgr = `PRES.m_kWorldMessageManager;
    }

    // We want to hide both temporary and permanent messages so do both
    MessageMgr.RemoveMessage(GetMsgID(ObjectID, false));
    MessageMgr.RemoveMessage(GetMsgID(ObjectID, true));
}

static function string InsertEmotes(string InString) {
    local int TokenIndex;
    local string EmoteImagePath, OutString;
    local array<String> arrTokens;

    arrTokens = SplitString(InString, " ", /* bCullEmpty */ false);

    for (TokenIndex = 0; TokenIndex < arrTokens.Length; TokenIndex++) {
        EmoteImagePath = GetEmoteImagePath(arrTokens[TokenIndex]);

        if (EmoteImagePath == "") {
            continue;
        }

        arrTokens[TokenIndex] = "<img src='" $ EmoteImagePath $ "' align='baseline' vspace='-5' width='22' height='22'>";
    }

    JoinArray(arrTokens, OutString, " ");

    return OutString;
}

static function ShowTwitchName(int ObjectID, optional XComGameState NewGameState, optional bool bPermanent = false) {
    local float DisplayTime;
    local int MsgBehavior;
    local TwitchViewer Viewer;
    local XComGameState_TwitchObjectOwnership OwnershipState;
    local Vector Position;

    OwnershipState = class'XComGameState_TwitchObjectOwnership'.static.FindForObject(ObjectID);

    if (OwnershipState == none) {
        return;
    }

    `TISTATEMGR.TwitchChatConn.GetViewer(OwnershipState.TwitchLogin, Viewer);
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

defaultproperties
{
    arrTwitchEmotes.Add("anamiyWTF")        // From SilverMillsy
    arrTwitchEmotes.Add("banzer2F")         // From Banzerschreck
    arrTwitchEmotes.Add("banzer2Freeze")    // From Banzerschreck
    arrTwitchEmotes.Add("banzer2Nino")      // From Banzerschreck
    arrTwitchEmotes.Add("banzer2Wtf")       // From Banzerschreck
    arrTwitchEmotes.Add("BnuuyKILL")        // From SerSnufflesTheStalwart (for StarbrightLass)
    arrTwitchEmotes.Add("britar1Evil")      // From Britarnya
    arrTwitchEmotes.Add("cprPickle")        // From MrCoppertop101
    arrTwitchEmotes.Add("cptscr3Grem")      // From CptScrapples
    arrTwitchEmotes.Add("eizackAngy")       // From Eizack
    arrTwitchEmotes.Add("eizackHaha")       // From Eizack
    arrTwitchEmotes.Add("eizackHeart")      // From Eizack
    arrTwitchEmotes.Add("finoTB")           // For (not from) Incrodon
    arrTwitchEmotes.Add("GSohno")           // From GravitasShortfall
    arrTwitchEmotes.Add("GSohyes")          // From GravitasShortfall
    arrTwitchEmotes.Add("TransgenderPride") // From Herensica

    // Easter eggs
    arrTwitchEmotes.Add("mjbBABY")

    // Global emotes
    arrTwitchEmotes.Add("LUL")

    // MJB emotes
    arrTwitchEmotes.Add("mjbAyy")
    arrTwitchEmotes.Add("mjbBONK")
    arrTwitchEmotes.Add("mjbBRAD")
    arrTwitchEmotes.Add("mjbCHAMP")
    arrTwitchEmotes.Add("mjbCRY")
    arrTwitchEmotes.Add("mjbDank")
    arrTwitchEmotes.Add("mjbEags")
    arrTwitchEmotes.Add("mjbEZ")
    arrTwitchEmotes.Add("mjbF")
    arrTwitchEmotes.Add("mjbGASM")
    arrTwitchEmotes.Add("mjbGOOD")
    arrTwitchEmotes.Add("mjbHmm")
    arrTwitchEmotes.Add("mjbHYPERJAKE")
    arrTwitchEmotes.Add("mjbHYPERMARK")
    arrTwitchEmotes.Add("mjbHYPERNYA")
    arrTwitchEmotes.Add("mjbHYPERPUP")
    arrTwitchEmotes.Add("mjbJAKE")
    arrTwitchEmotes.Add("mjbJBONK")
    arrTwitchEmotes.Add("mjbJEFF")
    arrTwitchEmotes.Add("mjbKARL")
    arrTwitchEmotes.Add("mjbLOVE")
    arrTwitchEmotes.Add("mjbMARK")
    arrTwitchEmotes.Add("mjbNice")
    arrTwitchEmotes.Add("mjbNya")
    arrTwitchEmotes.Add("mjbOak")
    arrTwitchEmotes.Add("mjbPOWER")
    arrTwitchEmotes.Add("mjbPUP")
    arrTwitchEmotes.Add("mjbRANGER")
    arrTwitchEmotes.Add("mjbRIG")
    arrTwitchEmotes.Add("mjbS")
    arrTwitchEmotes.Add("mjbSMILE")
    arrTwitchEmotes.Add("mjbSTAB")
    arrTwitchEmotes.Add("mjbYARE")
    arrTwitchEmotes.Add("mjbYell")
}