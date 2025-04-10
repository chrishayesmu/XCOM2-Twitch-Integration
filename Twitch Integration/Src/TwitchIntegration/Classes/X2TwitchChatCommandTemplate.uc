class X2TwitchChatCommandTemplate extends X2DataTemplate
    config(TwitchChatCommands)
    dependson(TwitchStateManager);

struct ChatCommandRateLimitConfig {
    var float CooldownInSeconds;
    var int CooldownInTurns;
    var int MaxUsesPerTurn;
};

struct EmoteData {
    var string EmoteCode;
    var int StartIndex;
    var int EndIndex;
};

// Which command strings this command can handle, without the leading exclamation point
// (i.e. "xsay" rather than "!xsay")
var config array<string> CommandAliases;

var config bool bEnableInStrategy;
var config bool bEnableInTactical;
var config bool bRequireOwnedUnit;

var config ChatCommandRateLimitConfig IndividualRateLimits;
var config ChatCommandRateLimitConfig GlobalRateLimits;

var protected const class<XComGameState_ChatCommandBase> GameStateClass; // must be set in defaultproperties of subclasses

function Initialize() {
    local int I;

    // Lowercase all aliases to simplify things
    for (I = 0; I < CommandAliases.Length; I++) {
        CommandAliases[I] = Locs(CommandAliases[I]);
    }
}

/// <summary>
/// Called when a chat command is being invoked by a viewer. This will not be called if the command is currently on cooldown.
/// </summary>
/// <param name="NewGameState">A game state to modify as part of the command usage.</param>
/// <param name="CommandAlias">The alias which was used to invoke the command.</param>
/// <param name="Body">The remainder of the chat message following the alias, with whitespace trimmed. May be empty.</param>
/// <param name="Emotes">Data for any emotes contained in the chat message.</param>
/// <param name="MessageId">The unique ID assigned by Twitch to this chat message.</param>
/// <param name="Viewer">The viewer object for the sender. Rarely, this may be inaccurate if a user is chatting before Twitch's
/// API has returned them in the chatters list; in particular, subscriber/VIP/moderator info may be missing.</param>
/// <returns>True if the command was successfully invoked (and thus should be placed on cooldown), false otherwise.</returns>
function bool Invoke(string CommandAlias, string Body, array<EmoteData> Emotes, string MessageId, TwitchChatter Viewer) {
    local XComGameState_Unit UnitState;

    if (bRequireOwnedUnit) {
        if (Viewer.OwnedObjectID == 0) {
            return false;
        }

        // When on the tactical layer, it's not enough to own a unit; it has to be in the current mission
        if (`TI_IS_TAC_GAME) {
            UnitState = class'X2TwitchUtils'.static.GetViewerUnitOnMission(Viewer.Login);

            return UnitState != none;
        }
    }

    return true;
}

/// <summary>
/// Whether usage of this command should be tracked in the XComGameState_TwitchChatCommandTracking singleton. Tracking is
/// skipped when not needed, to keep the game state small.
/// </summary>
function bool ShouldTrackUsage() {
    return IndividualRateLimits.CooldownInSeconds > 0
        || IndividualRateLimits.CooldownInTurns > 0
        || IndividualRateLimits.MaxUsesPerTurn > 0
        || GlobalRateLimits.CooldownInSeconds > 0
        || GlobalRateLimits.CooldownInTurns > 0
        || GlobalRateLimits.MaxUsesPerTurn > 0;
}

protected function XComGameState_ChatCommandBase CreateChatCommandGameState(XComGameState NewGameState, string Body, array<EmoteData> Emotes, string MessageId, TwitchChatter Viewer) {
    local XComGameState_ChatCommandBase ChatCommandGameState;
    local XComGameState_Unit Unit;

    Unit = class'X2TwitchUtils'.static.FindUnitOwnedByViewer(Viewer.Login);

	ChatCommandGameState = XComGameState_ChatCommandBase(NewGameState.CreateNewStateObject(default.GameStateClass));
    ChatCommandGameState.MessageBody = Body;
    ChatCommandGameState.Emotes = Emotes;
	ChatCommandGameState.SenderLogin = Viewer.Login;
    ChatCommandGameState.SendingUnitObjectID = Unit != none ? Unit.GetReference().ObjectID : 0;
    ChatCommandGameState.TwitchMessageId = MessageId;

    return ChatCommandGameState;
}

/// <summary>
/// Registers the given emotes in the Twitch Integration mod so they can be displayed in-game. If your command interacts with
/// emotes in any way, you should call this function.
/// </summary>
protected function RegisterEmotes(array<EmoteData> Emotes) {
    local int Index;

    for (Index = 0; Index < Emotes.Length; Index++) {
        class'TwitchEmoteManager'.static.RegisterEmote(Emotes[Index].EmoteCode);
    }
}