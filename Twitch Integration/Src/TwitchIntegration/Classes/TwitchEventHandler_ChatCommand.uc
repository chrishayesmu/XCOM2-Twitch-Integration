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
    local TwitchChatCommand CommandHandler;
    local TwitchChatter Viewer;
    local string Command, Body, MessageId, UserLogin;

    Command = Locs(Data.GetStringValue("command"));

    `TILOG("Attempting to handle chat command " $ Command);

    foreach CommandHandlers(CommandHandler) {
        if (CommandHandler.CommandAliases.Find(Command) == INDEX_NONE) {
            continue;
        }

        Body = Data.GetStringValue("body");
        MessageId = Data.GetStringValue("message_id");
        UserLogin = Data.GetStringValue("user_login");

        StateMgr.UpsertViewer(UserLogin, Viewer);

        `TILOG("Handling command with " $ CommandHandler);
        CommandHandler.Invoke(Command, Body, MessageId, Viewer);
        return;
    }

    `TILOG("Did not find any applicable command handler");
}

/// <summary>
/// Gets the body of the command following the alias, e.g. "!xsay hi" would map to "hi".
/// </summary>
protected function string GetCommandBody(JsonObject Data) {
    return Data.GetStringValue("body");
}

/// <summary>
/// Gets the Twitch message ID of the chat message that triggered this command.
/// </summary>
protected function string GetMessageId(JsonObject Data) {
    return Data.GetStringValue("message_id");
}

/// <summary>
/// Gets the Twitch login of the user who triggered this command.
/// </summary>
protected function string GetUserLogin(JsonObject Data) {
    return Data.GetStringValue("user_login");
}

defaultproperties
{
    EventType="chatCommand"
}