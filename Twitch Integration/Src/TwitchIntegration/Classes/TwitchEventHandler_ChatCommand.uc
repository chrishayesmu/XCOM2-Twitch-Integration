/// <summary>
/// Event handler for all chat commands. Delegates the actual handling of said commands
/// to instances of the TwitchChatCommand class.
/// </summary>
class TwitchEventHandler_ChatCommand extends TwitchEventHandler
    dependson(TwitchStateManager, X2TwitchChatCommandTemplate);

function Handle(TwitchStateManager StateMgr, JsonObject Data) {
    local array<EmoteData> Emotes;
    local XComGameState NewGameState;
    local XComGameState_TwitchChatCommandTracking CommandTrackingState;
    local X2TwitchChatCommandTemplate CommandHandler;
    local TwitchChatter Viewer;
    local string Command, Body, MessageId, UserLogin;

    CommandTrackingState = class'X2TwitchUtils'.static.GetChatCommandTracking();

    if (CommandTrackingState == none) {
        `TILOG("No XComGameState_TwitchChatCommandTracking was found. Unable to handle chat commands currently.");
        return;
    }

    Command = Locs(Data.GetStringValue("command"));
    Body = Data.GetStringValue("body");
    MessageId = Data.GetStringValue("message_id");
    UserLogin = Data.GetStringValue("user_login");
    Emotes = ParseEmoteData(Data);

    CommandHandler = class'X2TwitchChatCommandTemplateManager'.static.GetChatCommandTemplateManager().GetChatCommandTemplateForAlias(Command);

    `TILOG("Attempting to handle chat command " $ Command $ " with template " $ (CommandHandler != none ? CommandHandler.DataName : 'none'));

    if (CommandHandler == none) {
        `TILOG("Did not find any applicable command handler");
        return;
    }

    if (CommandTrackingState.IsChatCommandOnCooldown(CommandHandler, UserLogin)) {
        `TILOG("Command is on cooldown");
        return;
    }

    StateMgr.UpsertViewer(UserLogin, Viewer);

    `TILOG("Handling command with template " $ CommandHandler.DataName);
    if (CommandHandler.Invoke(Command, Body, Emotes, MessageId, Viewer) && CommandHandler.ShouldTrackUsage()) {
        // Record the command usage
        NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Tracking Chat Command " $ Command);
        CommandTrackingState = XComGameState_TwitchChatCommandTracking(NewGameState.ModifyStateObject(class'XComGameState_TwitchChatCommandTracking', CommandTrackingState.ObjectID));
        CommandTrackingState.RecordCommandUsage(CommandHandler, Viewer.Login);

        `GAMERULES.SubmitGameState(NewGameState);
    }
}

private function array<EmoteData> ParseEmoteData(JsonObject Data) {
    local array<EmoteData> Emotes;
    local EmoteData Emote;
    local JsonObject EmoteObj;
    local int Index;

    EmoteObj = Data.GetObject("emote_data");

    for (Index = 0; Index < EmoteObj.ObjectArray.Length; Index++) {
        Emote.EmoteCode = EmoteObj.ObjectArray[Index].GetStringValue("emote_code");
        Emote.StartIndex = EmoteObj.ObjectArray[Index].GetIntValue("start_index");
        Emote.EndIndex = EmoteObj.ObjectArray[Index].GetIntValue("end_index");

        Emotes.AddItem(Emote);
    }

    return Emotes;
}

defaultproperties
{
    EventType="chatCommand"
}