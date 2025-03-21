class TwitchChatCommand_XEmote extends TwitchChatCommand
    dependson(TwitchStateManager);

function bool Invoke(string CommandAlias, string Body, array<EmoteData> Emotes, string MessageId, TwitchChatter Viewer) {
    local string EmoteImagePath;
    local XComGameState_Unit UnitState;

    RegisterEmotes(Emotes);

    // Ignore any command that isn't just an emote or an empty string (to clear emotes)
    if (InStr(Body, " ") != INDEX_NONE || Emotes.Length > 1) {
        return false;
    }

    EmoteImagePath = Emotes.Length == 0 ? "" : class'TwitchEmoteManager'.static.GetEmotePath(Emotes[0].EmoteCode);

    // If path not found and there was an attempt to set emote, abort
    if (EmoteImagePath == "" && Emotes.Length > 0) {
        return false;
    }

    UnitState = class'X2TwitchUtils'.static.GetViewerUnitOnMission(Viewer.Login);

    if (UnitState == none) {
        return false;
    }

    `TISTATEMGR.TwitchFlagMgr.SetTwitchEmoteImage(UnitState, EmoteImagePath);
    return true;
}