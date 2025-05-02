class X2TwitchChatCommandTemplate_RollTheDice extends X2TwitchChatCommandTemplate_ExecuteAction;

function bool Invoke(string CommandAlias, string Body, array<EmoteData> Emotes, string MessageId, TwitchChatter Viewer) {
    if (!`TI_CFG(bRtdEnableChatCommand)) {
        `TILOG("Roll the Dice chat command has been disabled in the mod options");
        return false;
    }

    return super.Invoke(CommandAlias, Body, Emotes, MessageId, Viewer);
}