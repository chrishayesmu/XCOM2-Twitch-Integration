class TwitchCommandHandler_XEmote extends TwitchCommandHandler
    dependson(TwitchStateManager);

function Handle(TwitchStateManager StateMgr, TwitchMessage Command, TwitchViewer Viewer) {
    local string CommandBody, EmoteImagePath;
    local XComGameState_Unit UnitState;

    // Ignore any command that isn't just an emote or an empty string (to clear emotes)
    CommandBody = GetCommandBody(Command);

    if (InStr(CommandBody, " ") != INDEX_NONE) {
        return;
    }

    EmoteImagePath = class'UIUtilities_Twitch'.static.GetEmoteImagePath(CommandBody);

    // Allow an empty command body to hide the emote
    if (EmoteImagePath == "" && CommandBody != "") {
        return;
    }

    UnitState = class'X2TwitchUtils'.static.GetViewerUnitOnMission(Viewer.Login);

    if (UnitState == none) {
        return;
    }

    `TISTATEMGR.TwitchFlagMgr.SetTwitchEmoteImage(UnitState, EmoteImagePath);
}