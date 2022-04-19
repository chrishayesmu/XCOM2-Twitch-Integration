class TwitchStateManager extends Actor
	config(TwitchIntegration)
	dependson(TwitchChatTcpLink, XComGameState_TwitchEventPoll);

// ----------------------------------------------
// Structs/enums

struct PollTypeWeighting {
    var ePollType PollType;
    var int Weight;
};

// ----------------------------------------------
// Config vars

var config array<string> BlacklistedViewerNames;

var config(TwitchChatCommands) array<string> EnabledCommands;
var config(TwitchEvents) array<PollTypeWeighting> PollTypeWeights;

var private int OptionsPerPoll;

// ----------------------------------------------
// State variables

var bool bUnraffledUnitsExist;
var privatewrite bool bIsViewerListPopulated;
var private array<string> VotersInCurrentPoll;

var private HttpGetRequest HttpGet;
var privatewrite TwitchChatTcpLink TwitchChatConn;
var privatewrite TwitchUnitFlagManager TwitchFlagMgr;
var privatewrite UIChatLog ChatLog;
var privatewrite UIRaffleWinnersPanel RaffleWinnersPanel;

var private array<X2PollEventTemplate> HarbingerEventTemplates;
var private array<X2PollEventTemplate> ProvidenceEventTemplates;
var private array<X2PollEventTemplate> ReinforcementEventTemplates;
var private array<X2PollEventTemplate> SabotageEventTemplates;
var private array<X2PollEventTemplate> SerendipityEventTemplates;

var private array<TwitchCommandHandler> CommandHandlers;

// ----------------------------------------------
// Static functions

static function TwitchStateManager GetStateManager() {
	local TwitchStateManager mgr;

	foreach `XCOMGAME.AllActors(class'TwitchStateManager', mgr) {
		break;
	}

	return mgr;
}

// ----------------------------------------------
// Public functions

function Initialize() {
    local bool bIsTacticalGame;
    local string CommandHandlerName;
    local Class CommandHandlerClass;
    local TwitchCommandHandler CommandHandler;

    local int Index;
    local Object ThisObj;
    local X2DataTemplate Template;
    local X2EventListenerTemplateManager EventTemplateManager;
    local X2EventManager EventManager;
	local X2PollEventTemplate PollEventTemplate;

	`TILOG("Initializing state manager");

    bIsTacticalGame = !`TI_IS_STRAT_GAME;
    ThisObj = self;
	EventManager = `XEVENTMGR;
	EventManager.RegisterForEvent(ThisObj, 'PlayerTurnBegun', OnPlayerTurnBegun, ELD_OnStateSubmitted);

    // Load command handlers from config
    foreach EnabledCommands(CommandHandlerName) {
        CommandHandlerClass = class'Engine'.static.FindClassType(CommandHandlerName);
        CommandHandler = TwitchCommandHandler(new(None, CommandHandlerName) CommandHandlerClass);
        CommandHandler.Initialize(self);
	    CommandHandlers.AddItem(CommandHandler);
    }

    `TILOG("Loaded " $ CommandHandlers.Length $ " command handlers");

	// Find all poll event templates and organize them by type for future use
	EventTemplateManager = class'X2EventListenerTemplateManager'.static.GetEventListenerTemplateManager();

	foreach EventTemplateManager.IterateTemplates(Template, static.FilterRelevantTemplates) {
		PollEventTemplate = X2PollEventTemplate(Template);

		switch (PollEventTemplate.UseInPollType) {
			case ePollType_Harbinger:
				HarbingerEventTemplates.AddItem(PollEventTemplate);
				break;
			case ePollType_Providence:
				ProvidenceEventTemplates.AddItem(PollEventTemplate);
				break;
			case ePollType_Reinforcement:
				ReinforcementEventTemplates.AddItem(PollEventTemplate);
				break;
			case ePollType_Sabotage:
				SabotageEventTemplates.AddItem(PollEventTemplate);
				break;
            case ePollType_Serendipity:
                SerendipityEventTemplates.AddItem(PollEventTemplate);
                break;
		}
	}

    // Make sure blacklisted viewers are all lowercase, since Twitch logins are lowercase
    for (Index = 0; Index < default.BlacklistedViewerNames.Length; Index++) {
        default.BlacklistedViewerNames[Index] = Locs(default.BlacklistedViewerNames[Index]);
    }

	// Connect to Twitch chat servers
    ConnectToTwitchChat();

    if (bIsTacticalGame) {
        TwitchFlagMgr = Spawn(class'TwitchUnitFlagManager');
        TwitchFlagMgr.Initialize();
    }

	// Retrieve list of viewers from Twitch API at startup and periodically. It's heavily cached,
    // so we don't need to retrieve it very often.
    LoadViewerList();
    SetTimer(180.0, /* inBLoop */ true, nameof(LoadViewerList));

    // Periodically raffle any unraffled units. This covers us if there are more units than there are
    // viewers; every time our viewer pool increases, we can clear out some of the unraffled units.
    SetTimer(3.0, /* inBLoop */ true, nameof(RaffleUnitsIfNeeded));
}

function CastVote(TwitchViewer Viewer, int OptionIndex) {
	local XComGameState NewGameState;
    local XComGameState_TwitchEventPoll PollGameState;

	if (VotersInCurrentPoll.Find(Viewer.Login) != INDEX_NONE) {
		// No changing votes at this time
		return;
	}

    PollGameState = class'X2TwitchUtils'.static.GetActivePoll();

    if (PollGameState == none) {
        return;
    }

	if (OptionIndex < 0 || OptionIndex >= PollGameState.Choices.Length) {
		return;
	}

	VotersInCurrentPoll.AddItem(Viewer.Login);

	NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Twitch Poll Vote");
    PollGameState = XComGameState_TwitchEventPoll(NewGameState.ModifyStateObject(class'XComGameState_TwitchEventPoll', PollGameState.ObjectID));
    PollGameState.Choices[OptionIndex].NumVotes++;

	`GAMERULES.SubmitGameState(NewGameState);

    class'UIPollPanel'.static.UpdateInProgress();
}

function ConnectToTwitchChat(bool bForceReconnect = false) {
    if (TwitchChatConn != none && TwitchChatConn.IsConnected() && !bForceReconnect) {
        return; // already connected
    }

    if (TwitchChatConn == none) {
        TwitchChatConn = Spawn(class'TwitchChatTcpLink');
        TwitchChatConn.Initialize(OnConnectedToTwitchChat, OnTwitchMessageReceived);
    }
    else {
        if (TwitchChatConn.IsConnected()) {
            TwitchChatConn.Close();
        }

        TwitchChatConn.Connect();
    }
}

function HandleChatCommand(TwitchMessage Command, TwitchViewer Viewer) {
    local int Index;
    local string CommandAlias;
	local TwitchCommandHandler CommandHandler;

    Index = Instr(Command.Body, " ");
    CommandAlias = Mid(Command.Body, 1, Index - 1);

	foreach CommandHandlers(CommandHandler) {
		if (CommandHandler.CommandAliases.Find(CommandAlias) != INDEX_NONE) {
            // Only forward the command to the handler if it should be enabled right now
            if ( (CommandHandler.bEnableInStrategy && `TI_IS_STRAT_GAME)
              || (CommandHandler.bEnableInTactical && !`TI_IS_STRAT_GAME) ) {
    			CommandHandler.Handle(self, Command, Viewer);
            }
            else {
                `TILOG("Handler for alias " $ CommandAlias $ " is not supported in current game layer; is strat = " $ `TI_IS_STRAT_GAME);
            }

            // Regardless of whether the command is enabled, each alias only belongs to one command
			break;
		}
	}
}

function LoadViewerList() {
	HttpGet = Spawn(class'HttpGetRequest');
	HttpGet.Call("tmi.twitch.tv/group/user/" $ Locs(`TI_CFG(TwitchChannel)) $ "/chatters", OnNamesListReceived, OnNamesListReceiveError);
}

/// <summary>
/// Selects a viewer who does not currently own any object. Do not call this multiple times without assigning
/// ownership first, or you may get the same viewer repeatedly.
/// </summary>
/// <returns>The index of the viewer in the TwitchChatConn.Viewers array, or INDEX_NONE if no viewers are available.</returns>
function int RaffleViewer() {
    local bool bExcludeBroadcaster;
    local int AvailableIndex, Index, RaffledIndex;
    local int NumAvailableViewers;
    local string TwitchChannel;
    local TwitchViewer Viewer;

    bExcludeBroadcaster = `TI_CFG(bExcludeBroadcaster);
    TwitchChannel = Locs(`TI_CFG(TwitchChannel));

    for (Index = 0; Index < TwitchChatConn.Viewers.Length; Index++) {
        Viewer = TwitchChatConn.Viewers[Index];

        if (Viewer.OwnedObjectID > 0) {
            continue;
        }

        if (bExcludeBroadcaster && Viewer.Login ~= TwitchChannel) {
            continue;
        }

        NumAvailableViewers++;
    }

    if (NumAvailableViewers == 0) {
        `TILOG("RaffleViewer: No available viewers out of " $ TwitchChatConn.Viewers.Length $ " connected");
        return INDEX_NONE;
    }

    RaffledIndex = `SYNC_RAND(NumAvailableViewers);
    `TILOG("Out of " $ NumAvailableViewers $ " available viewers, rolled for #" $ RaffledIndex);

    for (Index = 0; Index < TwitchChatConn.Viewers.Length; Index++) {
        // We've raffled an index into a virtual array of only available viewers, so now we
        // need to count through it by only incrementing at available viewers
        if (TwitchChatConn.Viewers[Index].OwnedObjectID > 0) {
            continue;
        }

        if (bExcludeBroadcaster && Viewer.Login ~= TwitchChannel) {
            continue;
        }

        if (AvailableIndex == RaffledIndex) {
            break;
        }
        else {
            AvailableIndex++;
        }
    }

    return Index;
}

function ResolveCurrentPoll() {
    local XComGameState NewGameState;
	local XComGameStateContext_ChangeContainer Context;
    local XComGameState_TwitchEventPoll PollGameState;
    local X2PollEventTemplate PollEventTemplate;
	local PollChoice WinningOption;

    PollGameState = class'X2TwitchUtils'.static.GetActivePoll();

    if (PollGameState == none) {
        return;
    }

	WinningOption = class'X2TwitchUtils'.static.GetWinningPollChoice(PollGameState);

    NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Twitch Poll Resolving");
    PollGameState = XComGameState_TwitchEventPoll(NewGameState.ModifyStateObject(class'XComGameState_TwitchEventPoll', PollGameState.ObjectID));
    PollGameState.RemainingTurns = 0;

    Context = XComGameStateContext_ChangeContainer(NewGameState.GetContext());
	Context.BuildVisualizationFn = BuildVisualization_PollEnding;

	`GAMERULES.SubmitGameState(NewGameState);

    PollEventTemplate = class'X2TwitchUtils'.static.GetPollEventTemplate(WinningOption.PollEventTemplateName);
    PollEventTemplate.Resolve(PollGameState);
}

function StartPoll(ePollType PollType, int DurationInTurns, optional XComGameState_Player PlayerState) {
    local int Index;
	local array<X2PollEventTemplate> PollEvents;
	local XComGameState NewGameState;
	local XComGameState_TwitchEventPoll PollState;

    // Check if there's already a poll running
    if (class'X2TwitchUtils'.static.GetActivePoll() != none) {
        return;
    }

    if (PlayerState == none) {
        PlayerState = XComGameState_Player(`XCOMHISTORY.GetGameStateForObjectID(`TACTICALRULES.GetCachedUnitActionPlayerRef().ObjectID));
    }

    VotersInCurrentPoll.Length = 0;
    PollEvents = SelectEventsForPoll(PollType);

    // Submit a new game state for the start of the poll
	NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Twitch Poll Start");

	PollState = XComGameState_TwitchEventPoll(NewGameState.CreateNewStateObject(class'XComGameState_TwitchEventPoll'));
	PollState.PollType = PollType;
	PollState.DurationInTurns = DurationInTurns;
	PollState.RemainingTurns = DurationInTurns;
    PollState.PlayerTurnCountWhenStarted = PlayerState.PlayerTurnCount;

	PollState.Choices.Length = OptionsPerPoll;
    for (Index = 0; Index < OptionsPerPoll; Index++) {
	    PollState.Choices[Index].PollEventTemplateName = PollEvents[Index].DataName;
	    PollState.Choices[Index].NumVotes = 0;
    }

	`GAMERULES.SubmitGameState(NewGameState);

    class'UIPollPanel'.static.UpdateInProgress();
}

simulated event PostLoadGame() {
    `TILOG("PostLoadGame for TwitchStateManager");
}

// ----------------------------------------------
// Private functions

private function BuildVisualization_PollEnding(XComGameState VisualizeGameState) {
    local VisualizationActionMetadata ActionMetadata;
	local XComGameState_TwitchEventPoll PollState;

	foreach VisualizeGameState.IterateByClassType(class'XComGameState_TwitchEventPoll', PollState) {
		break;
	}

	ActionMetadata.StateObject_OldState = `XCOMHISTORY.GetGameStateForObjectID(PollState.ObjectID, eReturnType_Reference, VisualizeGameState.HistoryIndex - 1);
	ActionMetadata.StateObject_NewState = PollState;

    class'X2Action_ShowPollResults'.static.AddToVisualizationTree(ActionMetadata, VisualizeGameState.GetContext());
}

private function bool FilterRelevantTemplates(X2DataTemplate Template) {
	local X2PollEventTemplate PollEventTemplate;

	PollEventTemplate = X2PollEventTemplate(Template);

	if (PollEventTemplate == none) {
		return false;
	}

	return true;
}

private function OnConnectedToTwitchChat() {
    `TILOG("Connection to Twitch chat established");

    if (!`TI_IS_STRAT_GAME) {
        if (ChatLog == none) {
            // We always create a chat log, and let that component worry about hiding itself based on config
            ChatLog = Spawn(class'UIChatLog', `SCREENSTACK.GetFirstInstanceOf(class'UITacticalHud')).InitChatLog();
            ChatLog.AnchorTopLeft();
        }

        if (RaffleWinnersPanel == none) {
            RaffleWinnersPanel = Spawn(class'UIRaffleWinnersPanel', `SCREENSTACK.GetFirstInstanceOf(class'UITacticalHud')).InitRafflePanel();
            RaffleWinnersPanel.AnchorTopLeft();
        }
    }
}

private function OnNamesListReceiveError(HttpResponse Response) {
    `TILOG("Error occurred when retrieving viewers; response code was " $ Response.ResponseCode);

    HttpGet.Close();
    HttpGet.Destroy();
}

private function OnNamesListReceived(HttpResponse Response) {
	local JsonObject JsonObj;

	if (Response.ResponseCode != 200) {
		`TILOG("Error occurred when retrieving viewers; response code was " $ Response.ResponseCode);
		return;
	}

	JsonObj = class'JsonObject'.static.DecodeJson(Response.Body);
	JsonObj = JsonObj.GetObject("chatters");

    PopulateViewers(JsonObj.GetObject("broadcaster").ValueArray);
    PopulateViewers(JsonObj.GetObject("moderators").ValueArray);
    PopulateViewers(JsonObj.GetObject("vips").ValueArray);
    PopulateViewers(JsonObj.GetObject("admins").ValueArray);
    PopulateViewers(JsonObj.GetObject("global_mods").ValueArray);
    PopulateViewers(JsonObj.GetObject("staff").ValueArray);
    PopulateViewers(JsonObj.GetObject("viewers").ValueArray);

    bIsViewerListPopulated = true;
    HttpGet.Destroy();

    `XEVENTMGR.TriggerEvent('TwitchAssignUnitNames');
}

private function EventListenerReturn OnPlayerTurnBegun(Object EventData, Object EventSource, XComGameState GameState, Name Event, Object CallbackData) {
    local XComGameState NewGameState;
    local XComGameState_Player PlayerState;
    local XComGameState_TwitchEventPoll PollGameState;

    PlayerState = XComGameState_Player(EventSource);

	// We only care about the human player's turn, not the AI's
	if (`TACTICALRULES.GetLocalClientPlayerObjectID() != PlayerState.ObjectID) {
		return ELR_NoInterrupt;
    }

    PollGameState = class'X2TwitchUtils'.static.GetActivePoll();

    if (PollGameState == none) {
        if (ShouldStartPoll(PlayerState)) {
            StartPoll(SelectPollTypeByWeight(), `TI_CFG(PollDurationInTurns), PlayerState);
        }

        return ELR_NoInterrupt;
    }

    if (PollGameState.RemainingTurns == 1) {
        ResolveCurrentPoll();
        return ELR_NoInterrupt;
    }

	NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Twitch Poll Turn Elapsed");
    PollGameState = XComGameState_TwitchEventPoll(NewGameState.ModifyStateObject(class'XComGameState_TwitchEventPoll', PollGameState.ObjectID));
    PollGameState.RemainingTurns--;

	`GAMERULES.SubmitGameState(NewGameState);

    class'UIPollPanel'.static.UpdateInProgress();

    return ELR_NoInterrupt;
}

private function OnTwitchMessageReceived(TwitchMessage Message, TwitchViewer FromViewer) {
    local XComLWTuple Tuple;

    // Handle deleted messages specially
    if (Message.MessageType == eTwitchMessageType_ClearMessage) {
        Tuple = new class'XComLWTuple';
        Tuple.Id = 'TwitchChatMessageDeleted';
        Tuple.Data.Add(1);
        Tuple.Data[0].kind = XComLWTVString;
        Tuple.Data[0].s = Message.MsgId;

        `XEVENTMGR.TriggerEvent('TwitchChatMessageDeleted', Tuple);
        return;
    }

	// Only other messages we're interested in are chat commands
	if (Message.MessageType != eTwitchMessageType_Chat && Message.MessageType != eTwitchMessageType_Whisper) {
		return;
	}

    // Only care about commands starting with "!" at the moment
    // TODO: maybe do some minimal processing, especially for commands that cost bits since they'll often
    // start with the bit cheer
    if (Left(Message.Body, 1) != "!") {
        return;
    }

    HandleChatCommand(Message, FromViewer);
}

private function PopulateViewers(array<string> ViewerLogins) {
    local string Login;
    local TwitchViewer Viewer;
    local int ViewerIndex;
    local XComGameState_TwitchObjectOwnership Ownership;

    foreach ViewerLogins(Login) {
        ViewerIndex = TwitchChatConn.GetViewer(Login, Viewer);

        // If viewer is already recorded, just update their TTL
        if (ViewerIndex != INDEX_NONE) {
            Viewer.LastSeenTime = class'XComGameState_TimerData'.static.GetUTCTimeInSeconds();
            TwitchChatConn.Viewers[ViewerIndex] = Viewer;
            continue;
        }

        if (BlacklistedViewerNames.Find(Login) != INDEX_NONE) {
            continue;
        }

        Viewer.Login = Login;

        Ownership = class'XComGameState_TwitchObjectOwnership'.static.FindForUser(Login);
        if (Ownership != none) {
            Viewer.OwnedObjectID = Ownership.OwnedObjectRef.ObjectID;
        }

        TwitchChatConn.Viewers.AddItem(Viewer);
    }
}

private function RaffleUnitsIfNeeded() {
    if (bUnraffledUnitsExist) {
        bUnraffledUnitsExist = false;
        `XEVENTMGR.TriggerEvent('TwitchAssignUnitNames');
    }
}

private function array<X2PollEventTemplate> SelectEventsForPoll(ePollType PollType) {
    local X2PollEventTemplate EventTemplate;
    local X2PollEventTemplate SelectedEvent;
	local array<X2PollEventTemplate> FilteredEvents;
    local array<X2PollEventTemplate> PossibleEvents;
	local array<X2PollEventTemplate> SelectedEvents;

	switch (PollType) {
		case ePollType_Harbinger:
			PossibleEvents = HarbingerEventTemplates;
			break;
		case ePollType_Providence:
			PossibleEvents = ProvidenceEventTemplates;
			break;
		case ePollType_Reinforcement:
			PossibleEvents = ReinforcementEventTemplates;
			break;
		case ePollType_Sabotage:
			PossibleEvents = SabotageEventTemplates;
			break;
        case ePollType_Serendipity:
			PossibleEvents = SerendipityEventTemplates;
			break;
	}

    // Let templates check the current game state and be sure they can execute
    foreach PossibleEvents(EventTemplate) {
        if (!EventTemplate.IsValid()) {
            continue;
        }

        FilteredEvents.AddItem(EventTemplate);
    }

    // Select N templates from the filtered list, and at each step check the ExclusiveWith property to remove unwanted events
    while (SelectedEvents.Length < OptionsPerPoll) {
        SelectedEvent = SelectEventWithWeighting(FilteredEvents);
        SelectedEvents.AddItem(SelectedEvent);
        FilteredEvents.RemoveItem(SelectedEvent);

        // Check if any potential events are exclusive with the one we just added
        foreach FilteredEvents(EventTemplate) {
            // ExclusiveWith could be in either direction, so just check both
            if (EventTemplate.ExclusiveWith.Find(SelectedEvent.DataName) != INDEX_NONE || SelectedEvent.ExclusiveWith.Find(EventTemplate.DataName) != INDEX_NONE) {
                `TILOG("Removing potential event due to ExclusiveWith: " $ EventTemplate.DataName);
                FilteredEvents.RemoveItem(EventTemplate);
            }
        }

        // Make sure we don't run out of events and cause an infinite loop
        if (FilteredEvents.Length == 0) {
            break;
        }
    }

    return SelectedEvents;
}

private function X2PollEventTemplate SelectEventWithWeighting(array<X2PollEventTemplate> PossibleEvents) {
    local int RunningTotal;
    local int TotalWeight;
    local int WeightRoll;
    local X2PollEventTemplate EventTemplate;

    foreach PossibleEvents(EventTemplate) {
        TotalWeight += EventTemplate.Weight;
    }

    WeightRoll = `SYNC_RAND(TotalWeight);

    foreach PossibleEvents(EventTemplate) {
        if (WeightRoll < RunningTotal + EventTemplate.Weight) {
            `TILOG("Weighted roll selected event " $ EventTemplate.DataName $ " on roll " $ WeightRoll);
            return EventTemplate;
        }

        RunningTotal += EventTemplate.Weight;
    }

    `TILOG("Default selected event " $ PossibleEvents[PossibleEvents.Length - 1].DataName);
    return PossibleEvents[PossibleEvents.Length - 1];
}

private function ePollType SelectPollTypeByWeight() {
    local int RunningTotal;
    local int TotalWeight;
    local int WeightRoll;
    local PollTypeWeighting Weighting;

    foreach PollTypeWeights(Weighting) {
        TotalWeight += Weighting.Weight;
    }

    WeightRoll = `SYNC_RAND(TotalWeight);

    foreach PollTypeWeights(Weighting) {
        if (WeightRoll < RunningTotal + Weighting.Weight) {
            `TILOG("Weighted roll selected poll type " $ Weighting.PollType $ " with roll " $ WeightRoll);
            return Weighting.PollType;
        }

        RunningTotal += Weighting.Weight;
    }

    // TODO: the last poll type might have a weight of 0, in which case this would be wrong
    `TILOG("Default selected poll type " $ PollTypeWeights[PollTypeWeights.Length - 1].PollType $ " TotalWeight " $ TotalWeight $ " roll " $ WeightRoll);
    return PollTypeWeights[PollTypeWeights.Length - 1].PollType;
}

private function bool ShouldStartPoll(XComGameState_Player PlayerState) {
    local int TurnsSinceLastPollEnded, TurnsSinceLastPollStarted;
    local int TurnsSinceMissionStart;
	local XComGameState_TwitchEventPoll PollState;

    if (!`TI_CFG(bEnablePolls)) {
        return false;
    }

    // Check if enough turns have elapsed since beginning the mission
    TurnsSinceMissionStart = PlayerState.PlayerTurnCount - 1; // PlayerTurnCount is 1 on the first turn

    if (TurnsSinceMissionStart < `TI_CFG(MinTurnsBeforeFirstPoll)) {
        return false;
    }

    // Check if enough turns have elapsed since the end of the last poll (if there's been one)
    PollState = class'X2TwitchUtils'.static.GetMostRecentPoll();

    if (PollState != none) {
        if (PollState.RemainingTurns > 0) {
            // This poll is still going right now
            `TILOG("There's already an active poll, not starting a new one");
            return false;
        }

        TurnsSinceLastPollStarted = PlayerState.PlayerTurnCount - PollState.PlayerTurnCountWhenStarted;
        TurnsSinceLastPollEnded = TurnsSinceLastPollStarted - PollState.DurationInTurns;

        if (TurnsSinceLastPollEnded < `TI_CFG(MinTurnsBetweenPolls)) {
            `TILOG("Last poll ended " $ TurnsSinceLastPollEnded $ " turns ago; cannot start another yet");
            return false;
        }
    }

    // Roll it
    return `SYNC_RAND(100) < `TI_CFG(ChanceToStartPoll);
}

defaultproperties
{
    bIsViewerListPopulated = false
    OptionsPerPoll = 3
}