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

var config array<string> ViewerWhitelist;
var config array<string> ViewerBlacklist;

var config bool bEnableInStrategy;
var config bool bEnableInTactical;
var config bool bRequireOwnedUnit;

var config ChatCommandRateLimitConfig IndividualRateLimits;
var config ChatCommandRateLimitConfig GlobalRateLimits;

var config StrategyCost CostToUse;

var protected const class<XComGameState_ChatCommandBase> GameStateClass; // must be set in defaultproperties of subclasses

function Initialize() {
    local int I;

    // Lowercase any viewer name references to simplify things
    for (I = 0; I < CommandAliases.Length; I++) {
        CommandAliases[I] = Locs(CommandAliases[I]);
    }

    for (I = 0; I < ViewerWhitelist.Length; I++) {
        ViewerWhitelist[I] = Locs(ViewerWhitelist[I]);
    }

    for (I = 0; I < ViewerBlacklist.Length; I++) {
        ViewerBlacklist[I] = Locs(ViewerBlacklist[I]);
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
/// <remarks>Subclasses should call the base class Invoke, but be warned that it can have side effects, such as paying
/// costs to use the command. Subclasses should therefore perform their own checks that the chat command can be used before
/// calling the base Invoke, to avoid paying costs and then failing to deliver any result.</remarks>
function bool Invoke(string CommandAlias, string Body, array<EmoteData> Emotes, string MessageId, TwitchChatter Viewer) {
    local XComGameState_Unit UnitState;

    `TILOG("Received chat command '" $ CommandAlias $ "' from viewer " $ Viewer.Login);

    if (bRequireOwnedUnit) {
        if (Viewer.OwnedObjectID == 0) {
            `TILOG("Viewer doesn't own a unit and bRequireOwnedUnit is true");
            return false;
        }

        // When on the tactical layer, it's not enough to own a unit; it has to be in the current mission
        if (`TI_IS_TAC_GAME) {
            UnitState = class'X2TwitchUtils'.static.GetViewerUnitOnMission(Viewer.Login);

            if (UnitState == none) {
                `TILOG("Viewer's unit is not on the current mission");
                return false;
            }
        }
    }

    if (ViewerWhitelist.Length > 0 && ViewerWhitelist.Find(Locs(Viewer.Login)) == INDEX_NONE) {
        return false;
    }

    if (ViewerBlacklist.Length > 0 && ViewerBlacklist.Find(Locs(Viewer.Login)) != INDEX_NONE) {
        return false;
    }

    if (!class'X2TwitchUtils'.static.TryPayStrategyCost(CostToUse)) {
        return false;
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