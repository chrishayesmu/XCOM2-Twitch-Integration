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

var config string Channel;
var config bool bBlacklistBroadcaster;
var config array<string> BlacklistedViewerNames;

var config(TwitchChatCommands) array<string> EnabledCommands;

var config(TwitchEvents) int PollDurationInTurns;
var config(TwitchEvents) int MinTurnsBeforeFirstPoll;
var config(TwitchEvents) int MinTurnsBetweenPolls;
var config(TwitchEvents) int ChanceToStartPoll;
var config(TwitchEvents) array<PollTypeWeighting> PollTypeWeights;

var private int OptionsPerPoll;

// ----------------------------------------------
// State variables

var array<TwitchViewer> ConnectedViewers;
var privatewrite bool bIsViewerListPopulated;
var private array<string> AvailableViewers;
var private array<string> RaffledViewers;
var private array<string> VotersInCurrentPoll;

var private HttpGetRequest HttpGet;
var privatewrite TwitchChatTcpLink TwitchChatConn;
var privatewrite UIChatLog ChatLog;

var private array<X2PollEventTemplate> HarbingerEventTemplates;
var private array<X2PollEventTemplate> ProvidenceEventTemplates;
var private array<X2PollEventTemplate> ReinforcementEventTemplates;
var private array<X2PollEventTemplate> SabotageEventTemplates;
var private array<X2PollEventTemplate> SerendipityEventTemplates;

var private array<TwitchCommandHandler> CommandHandlers;

// ----------------------------------------------
// Public functions

function Initialize() {
    local string CommandHandlerName;
    local Class CommandHandlerClass;
    local TwitchCommandHandler CommandHandler;

    local Object ThisObj;
    local X2DataTemplate Template;
    local X2EventListenerTemplateManager EventTemplateManager;
    local X2EventManager EventManager;
	local X2PollEventTemplate PollEventTemplate;

	`LOG("Initializing state manager", , 'TwitchIntegration');

    ThisObj = self;
	EventManager = `XEVENTMGR;
	EventManager.RegisterForEvent(ThisObj, 'PlayerTurnBegun', OnPlayerTurnBegun, ELD_OnStateSubmitted);

    // Load command handlers from config
    foreach EnabledCommands(CommandHandlerName) {
        CommandHandlerClass = class'Engine'.static.FindClassType(CommandHandlerName);
        CommandHandler = TwitchCommandHandler(new(None, CommandHandlerName) CommandHandlerClass);
	    CommandHandlers.AddItem(CommandHandler);
    }

    `LOG("Loaded " $ CommandHandlers.Length $ " command handlers", , 'TwitchIntegration');

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

	// Connect to Twitch chat servers
    ConnectToTwitchChat();

	// Retrieve list of viewers from Twitch API at startup and periodically. It's heavily cached,
    // so we don't need to retrieve it very often.
    LoadViewerList();
    SetTimer(180.0, /* inBLoop */ true, 'LoadViewerList');
}

function CastVote(string Voter, int OptionIndex) {
	local XComGameState NewGameState;
    local XComGameState_TwitchEventPoll PollGameState;

	if (VotersInCurrentPoll.Find(Voter) != INDEX_NONE) {
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

	VotersInCurrentPoll.AddItem(Voter);

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

function HandleChatCommand(string Command, string ViewerName, string CommandBody) {
	local TwitchCommandHandler CommandHandler;

	foreach CommandHandlers(CommandHandler) {
		if (CommandHandler.CommandAliases.Find(Command) != INDEX_NONE) {
			CommandHandler.Handle(self, Command, CommandBody, ViewerName);
			break;
		}
	}
}

function LoadViewerList() {
	HttpGet = Spawn(class'HttpGetRequest');
	HttpGet.Call("tmi.twitch.tv/group/user/" $ Locs(class'TwitchChatTcpLink'.default.TwitchChannel) $ "/chatters", OnNamesListReceived, OnNamesListReceiveError);
}

/// <summary>
/// Selects a viewer who has not previously been raffled and marks them as raffled. Make sure not
/// to call this function if you may not ultimately use the viewer for anything, as the viewer
/// will become ineligible for future raffles in this mission.
/// </summary>
/// <returns>The index of the viewer in the ConnectedViewers array, or -1 if no viewers are available.</returns>
function int RaffleViewer() {
    local int Index;
    local string ViewerName;

    if (!bIsViewerListPopulated || AvailableViewers.Length == 0) {
        return -1;
    }

    ViewerName = AvailableViewers[`SYNC_RAND(AvailableViewers.Length)];
//    Index = ConnectedViewers.Find('Name', ViewerName);

    AvailableViewers.RemoveItem(ViewerName);
    RaffledViewers.AddItem(ViewerName);

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

	PollState = XComGameState_TwitchEventPoll(NewGameState.CreateStateObject(class'XComGameState_TwitchEventPoll'));
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
    `LOG("PostLoadGame for TwitchStateManager");
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
    `LOG("OnConnectedToTwitchChat");

    if (ChatLog == none && class'UIChatLog'.default.bShowChatLog) {
        ChatLog = Spawn(class'UIChatLog', `SCREENSTACK.GetFirstInstanceOf(class'UITacticalHud')).InitChatLog(10, 245, 475, 210);
        ChatLog.AnchorTopLeft();
    }
}

private function OnNamesListReceiveError(HttpResponse Response) {
    `LOG("[TwitchIntegration] Error occurred when retrieving viewers; response code was " $ Response.ResponseCode);

    HttpGet.Close();
    HttpGet.Destroy();
}

private function OnNamesListReceived(HttpResponse Response) {
	local JsonObject JsonObj;

	if (Response.ResponseCode != 200) {
		`LOG("[TwitchIntegration] Error occurred when retrieving viewers; response code was " $ Response.ResponseCode);
		return;
	}

    `LOG("Received names list, parsing response");

    ConnectedViewers.Length = 0;

    // TODO: rewrite this without JsonObject because it crashes on large payloads

	//JsonObj = class'JsonObject'.static.DecodeJson(Response.Body);
	//JsonObj = JsonObj.GetObject("chatters");

    // Start with the highest roles and work down to the lowest, since viewers will not be added multiple times
    /*
    PopulateViewers(JsonObj.GetObject("broadcaster").ValueArray, eTwitchRole_Broadcaster);
    PopulateViewers(JsonObj.GetObject("moderators").ValueArray, eTwitchRole_Moderator);
    PopulateViewers(JsonObj.GetObject("vips").ValueArray, eTwitchRole_VIP);

    // A bunch of these roles could be considered special, but we only really care about roles the streamer can control
    PopulateViewers(JsonObj.GetObject("admins").ValueArray, eTwitchRole_None);
    PopulateViewers(JsonObj.GetObject("global_mods").ValueArray, eTwitchRole_None);
    PopulateViewers(JsonObj.GetObject("staff").ValueArray, eTwitchRole_None);
    PopulateViewers(JsonObj.GetObject("viewers").ValueArray, eTwitchRole_None);
*/
    bIsViewerListPopulated = true;
    HttpGet.Destroy();

    `LOG("Received viewer list from Twitch: found " $ ConnectedViewers.Length $ " viewers");

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
            StartPoll(SelectPollTypeByWeight(), PollDurationInTurns, PlayerState);
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
	local string Command;
	local string CommandBody;
	local int Index;

	// Only messages we're interested in are chat commands
	if (Message.MessageType != eTwitchMessageType_Chat && Message.MessageType != eTwitchMessageType_Whisper) {
		return;
	}

    // Only care about commands starting with "!" at the moment
    // TODO: maybe do some minimal processing, especially for commands that cost bits since they'll often
    // start with the bit cheer
    if (Left(Message.Body, 1) != "!") {
        return;
    }

	Index = InStr(Message.Body, " ");
	Command = Mid(Message.Body, 1, index - 1); // start at 1 to strip the leading exclamation point
	CommandBody = Mid(Message.Body, index + 1);

//    HandleChatCommand(Command, Message.Sender, CommandBody);
}

/*
private function PopulateViewers(array<string> Viewers, eTwitchRole AssignedRole) {
    local string Id;
    local TwitchViewer Viewer;

    foreach Viewers(Id) {
        if (ConnectedViewers.Find('Id', Id) != INDEX_NONE) {
            continue;
        }

        if (BlacklistedViewerNames.Find(Id) != INDEX_NONE) {
            continue;
        }

        if (bBlacklistBroadcaster && AssignedRole == eTwitchRole_Broadcaster) {
            continue;
        }

        Viewer.Id = Locs(Id);
        Viewer.Name = Id;
        Viewer.Role = AssignedRole;
        ConnectedViewers.AddItem(Viewer);

        if (class'XComGameState_TwitchObjectOwnership'.static.FindForUser(Id) == none) {
            AvailableViewers.AddItem(Id);
        }
    }
}
*/

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
                `LOG("Removing potential event due to ExclusiveWith: " $ EventTemplate.DataName);
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
            `LOG("Weighted roll selected event " $ EventTemplate.DataName $ " on roll " $ WeightRoll);
            return EventTemplate;
        }

        RunningTotal += EventTemplate.Weight;
    }

    `LOG("Default selected event " $ PossibleEvents[PossibleEvents.Length - 1].DataName);
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
            `LOG("Weighted roll selected poll type " $ Weighting.PollType $ " with roll " $ WeightRoll);
            return Weighting.PollType;
        }

        RunningTotal += Weighting.Weight;
    }

    // TODO: the last poll type might have a weight of 0, in which case this would be wrong
    `LOG("Default selected poll type " $ PollTypeWeights[PollTypeWeights.Length - 1].PollType $ " TotalWeight " $ TotalWeight $ " roll " $ WeightRoll);
    return PollTypeWeights[PollTypeWeights.Length - 1].PollType;
}

private function bool ShouldStartPoll(XComGameState_Player PlayerState) {
    local int TurnsSinceLastPollEnded, TurnsSinceLastPollStarted;
    local int TurnsSinceMissionStart;
	local XComGameState_TwitchEventPoll PollState;

    // Check if enough turns have elapsed since beginning the mission
    TurnsSinceMissionStart = PlayerState.PlayerTurnCount - 1; // PlayerTurnCount is 1 on the first turn

    if (TurnsSinceMissionStart < MinTurnsBeforeFirstPoll) {
        return false;
    }

    // Check if enough turns have elapsed since the end of the last poll (if there's been one)
    PollState = class'X2TwitchUtils'.static.GetMostRecentPoll();

    if (PollState != none) {
        if (PollState.RemainingTurns > 0) {
            // This poll is still going right now
            `LOG("There's already an active poll, not starting a new one");
            return false;
        }

        TurnsSinceLastPollStarted = PlayerState.PlayerTurnCount - PollState.PlayerTurnCountWhenStarted;
        TurnsSinceLastPollEnded = TurnsSinceLastPollStarted - PollState.DurationInTurns;

        if (TurnsSinceLastPollEnded < MinTurnsBetweenPolls) {
            `LOG("Last poll ended " $ TurnsSinceLastPollEnded $ " turns ago; min to start new is " $ MinTurnsBetweenPolls);
            return false;
        }
    }

    // Roll it
    return `SYNC_RAND(100) < ChanceToStartPoll;
}

defaultproperties
{
    bIsViewerListPopulated = false
    OptionsPerPoll = 3
}