/// <summary>
/// Event handler for all chat commands. Delegates the actual handling of said commands
/// to instances of the TwitchChatCommand class.
/// </summary>
class TwitchEventHandler_ChatCommand extends TwitchEventHandler
    dependson(TwitchStateManager)
    config(TwitchChatCommands);

var config array<string> EnabledCommands;

var private array<TwitchChatCommand> CommandHandlers;

function Initialize(TwitchStateManager StateMgr) {
    local string CommandHandlerName;
    local TwitchChatCommand CommandHandler;
    local Class CommandHandlerClass;

    // Load command handlers from config
    foreach EnabledCommands(CommandHandlerName) {
        CommandHandlerClass = class'Engine'.static.FindClassType(CommandHandlerName);

        if (CommandHandlerClass == none) {
            `TILOG("ERROR: couldn't load a chat command class with the name " $ CommandHandlerName);
            continue;
        }

        CommandHandler = TwitchChatCommand(new(None, CommandHandlerName) CommandHandlerClass);
        CommandHandler.Initialize(StateMgr);
	    CommandHandlers.AddItem(CommandHandler);
    }
}

function Handle(TwitchStateManager StateMgr, JsonObject Data) {
    local XComGameState NewGameState;
    local XComGameState_TwitchChatCommandTracking CommandTrackingState;
    local TwitchChatCommand CommandHandler;
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

    `TILOG("Attempting to handle chat command " $ Command);

    foreach CommandHandlers(CommandHandler) {
        if (CommandHandler.CommandAliases.Find(Command) == INDEX_NONE) {
            continue;
        }

        if (CommandTrackingState.IsChatCommandOnCooldown(CommandHandler, UserLogin)) {
            `TILOG("Command is on cooldown");
            return;
        }

        StateMgr.UpsertViewer(UserLogin, Viewer);

        `TILOG("Handling command with " $ CommandHandler);
        if (CommandHandler.Invoke(Command, Body, MessageId, Viewer) && CommandHandler.ShouldTrackUsage()) {
            // Record the command usage
            NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Tracking Chat Command " $ Command);
            CommandTrackingState = XComGameState_TwitchChatCommandTracking(NewGameState.ModifyStateObject(class'XComGameState_TwitchChatCommandTracking', CommandTrackingState.ObjectID));
            CommandTrackingState.RecordCommandUsage(CommandHandler, Viewer.Login);

		    `GAMERULES.SubmitGameState(NewGameState);
        }

        return;
    }

    `TILOG("Did not find any applicable command handler");
}

defaultproperties
{
    EventType="chatCommand"
}