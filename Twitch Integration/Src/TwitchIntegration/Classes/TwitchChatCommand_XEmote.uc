class TwitchChatCommand_XEmote extends TwitchChatCommand
    dependson(TwitchStateManager);

function bool Invoke(string CommandAlias, string Body, string MessageId, TwitchChatter Viewer) {
    local string EmoteImagePath;
    local XComGameState_Unit UnitState;

    // Ignore any command that isn't just an emote or an empty string (to clear emotes)
    if (InStr(Body, " ") != INDEX_NONE) {
        return false;
    }

    EmoteImagePath = class'UIUtilities_Twitch'.static.GetEmoteImagePath(Body);

    // Allow an empty command body to hide the emote
    if (EmoteImagePath == "" && Body != "") {
        return false;
    }

    UnitState = class'X2TwitchUtils'.static.GetViewerUnitOnMission(Viewer.Login);

    if (UnitState == none) {
        return false;
    }

    `TISTATEMGR.TwitchFlagMgr.SetTwitchEmoteImage(UnitState, EmoteImagePath);
    return true;
}