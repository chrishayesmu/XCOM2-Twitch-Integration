class TwitchChatCommand extends TwitchEventHandler
    dependson(TwitchStateManager)
    abstract;

// Which commands the class can handle, without the leading exclamation point
// (i.e. "xsay" rather than "!xsay")
var config array<string> CommandAliases;

var config bool bEnableInStrategy;
var config bool bEnableInTactical;

function Initialize(TwitchStateManager StateMgr) {
    local int I;

    // Lowercase all aliases to simplify things
    for (I = 0; I < CommandAliases.Length; I++) {
        CommandAliases[I] = Locs(CommandAliases[I]);
    }
}

function Invoke(string CommandAlias, string Body, string MessageId, TwitchChatter Viewer);

protected function XComGameState_ChatCommandBase CreateChatCommandGameState(class<XComGameState_ChatCommandBase> GameStateClass, XComGameState NewGameState, string Body, string MessageId, TwitchChatter Viewer) {
    local XComGameState_ChatCommandBase ChatCommandGameState;
    local XComGameState_Unit Unit;

    Unit = class'X2TwitchUtils'.static.FindUnitOwnedByViewer(Viewer.Login);

	ChatCommandGameState = XComGameState_ChatCommandBase(NewGameState.CreateNewStateObject(GameStateClass));
    ChatCommandGameState.MessageBody = Body;
	ChatCommandGameState.SenderLogin = Viewer.Login;
    ChatCommandGameState.SendingUnitObjectID = Unit != none ? Unit.GetReference().ObjectID : 0;
    ChatCommandGameState.TwitchMessageId = MessageId;

    return ChatCommandGameState;
}