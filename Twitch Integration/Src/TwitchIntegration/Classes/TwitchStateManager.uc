class TwitchStateManager extends Actor
	config(TwitchIntegration)
	dependson(TwitchPollModel, XComGameState_TwitchEventPoll);

// ----------------------------------------------
// Structs/enums

struct TwitchChatter {
    var string Login;        // The login of the viewer (should be same as Name but all lowercase)
	var string DisplayName;  // The name the viewer uses in chat
    var int SubTier;         // Subscription tier (0, 1, 2, or 3), where 0 means not subbed. Prime subs are tier 1.
    var bool IsBroadcaster;  // Whether this viewer is the broadcaster.
    var int OwnedObjectID;   // If > 0, the ID of an object this viewer has raffled as owner of
};

// ----------------------------------------------
// Config vars

var config array<string> BlacklistedViewerNames;

var config(TwitchChatCommands) array<string> EnabledCommands;

// ----------------------------------------------
// State variables

var bool bUnraffledUnitsExist;
var float fTimeSinceLastRaffle;
var privatewrite bool bIsViewerListPopulated;
var array<TwitchChatter> CurrentChatters;
var array<JsonObject> EventQueue;
var TwitchPollModel LatestPollModel;

var array<string> RiggedRaffles; // list of logins which are guaranteed upcoming raffle positions

var privatewrite TwitchUnitFlagManager TwitchFlagMgr;
var privatewrite UIChatLog ChatLog;
var privatewrite UIRaffleWinnersPanel RaffleWinnersPanel;

var private array<TwitchEventHandler> EventHandlers;
var private TwitchEventHandler_CreatePoll CreatePollEventHandler; // also present in EventHandlers array

var private bool bPendingCreateOfChatCommandHistory; // if true, we still need to create an XComGameState_TwitchChatCommandTracking singleton

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
    local int Index;
    local Object ThisObj;
    local TwitchEventHandler EventHandler;
    local X2EventManager EventManager;

	`TILOG("Initializing state manager");

    class'TwitchEmoteManager'.static.Initialize();

    // Check if command tracking already exists, e.g. because we're loading a mid-mission save
    if (`XCOMHISTORY.GetSingleGameStateObjectForClass(class'XComGameState_TwitchChatCommandTracking', /* AllowNULL */ true) == none) {
        bPendingCreateOfChatCommandHistory = true;
    }

    // Set up event handlers
    CreatePollEventHandler = new class'TwitchEventHandler_CreatePoll';

    EventHandlers.AddItem(new class'TwitchEventHandler_ChannelPointRedeem');
    EventHandlers.AddItem(new class'TwitchEventHandler_ChatCommand');
    EventHandlers.AddItem(new class'TwitchEventHandler_ChatDeleted');
    EventHandlers.AddItem(CreatePollEventHandler);
    EventHandlers.AddItem(new class'TwitchEventHandler_UpdatePoll');

    foreach EventHandlers(EventHandler) {
        EventHandler.Initialize(self);
    }

    `TILOG("Loaded " $ EventHandlers.Length $ " event handlers");

    // Make sure blacklisted viewers are all lowercase, since Twitch logins are lowercase
    for (Index = 0; Index < BlacklistedViewerNames.Length; Index++) {
        BlacklistedViewerNames[Index] = Locs(BlacklistedViewerNames[Index]);
    }

    if (`TI_IS_TAC_GAME) {
        ThisObj = self;
	    EventManager = `XEVENTMGR;
	    EventManager.RegisterForEvent(ThisObj, 'PlayerTurnBegun', OnPlayerTurnBegun, ELD_OnStateSubmitted);

        TwitchFlagMgr = Spawn(class'TwitchUnitFlagManager');
        TwitchFlagMgr.Initialize();
    }

	// Retrieve list of viewers from Twitch API at startup and periodically. It's heavily cached,
    // so we don't need to retrieve it very often.
    LoadViewerList();
    SetTimer(60.0, /* inBLoop */ true, nameof(LoadViewerList));

    // Load pending events very frequently, so the game is pretty responsive to viewers
    SetTimer(1.0, /* inBLoop */ true, nameof(LoadPendingEvents));

    // Initially raffle any unraffled units. We have to be careful to always do this from the main thread and
    // not in response to web requests, or we can end up submitting a game state from an illegal thread and
    // crash the game.
    bUnraffledUnitsExist = true;
    fTimeSinceLastRaffle = 100.0f;
}

event Tick(float DeltaTime) {
    local XComGameState NewGameState;
    local TwitchEventHandler EventHandler;
    local array<JsonObject> Events;
    local string EventType;
    local int I;
    local bool bEventHandled;

    super.Tick(DeltaTime);

    if (bPendingCreateOfChatCommandHistory) {
        bPendingCreateOfChatCommandHistory = false;

        `TILOG("Creating initial XComGameState_TwitchChatCommandTracking singleton");

	    NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Initial Twitch chat tracking singleton");
        NewGameState.CreateNewStateObject(class'XComGameState_TwitchChatCommandTracking');
        `GAMERULES.SubmitGameState(NewGameState);
    }

    `TILOG("EventQueue contains " $ EventQueue.Length $ " items", EventQueue.Length > 0);

    // Processing events might take a while; operate on a copy of the queue to reduce concurrency issues
    Events = EventQueue;
    EventQueue.Length = 0;

    for (I = 0; I < Events.Length; I++) {
        bEventHandled = false;
        EventType = Events[i].GetStringValue("$type");

        `TILOG("Processing event of type " $ EventType);

        foreach EventHandlers(EventHandler) {
            if (EventHandler.EventType == EventType) {
                EventHandler.Handle(self, Events[i]);

                bEventHandled = true;
            }
        }

        if (!bEventHandled) {
            `TILOG("WARNING: received an event with type " $ EventType $ " but no handler is registered for this type");
        }
    }

    if (bUnraffledUnitsExist && `TI_CFG(bAssignUnitNames)) {
        fTimeSinceLastRaffle += DeltaTime;

        if (fTimeSinceLastRaffle >= 5.0f && bIsViewerListPopulated) {
            bUnraffledUnitsExist = false;
            fTimeSinceLastRaffle = 0.0f;

            `XEVENTMGR.TriggerEvent('TwitchAssignUnitNames');
        }
    }
}

function CreatePoll(string Title, array<string> Choices, int DurationInSeconds, int ChannelPointsPerVote) {
    local HttpGetRequest httpGet;
    local string Url;
    local int I;

    `TILOG("Creating a poll: title is '" $ Title $ "', there are " $ Choices.Length $ " choices, duration is " $ DurationInSeconds $ " seconds, ChannelPointsPerVote is " $ ChannelPointsPerVote);

    Url = "localhost:5000/api/poll/create";
    Url $= "?title=" $ class'TextUtilities_Twitch'.static.UrlEncode(Title);
    Url $= "&duration=" $ DurationInSeconds;
    Url $= "&pointsPerVote=" $ ChannelPointsPerVote;

    for (I = 0; I < Choices.Length; I++) {
        `TILOG("Choice " $ I $ " is " $ Choices[I]);
        Url $= "&choices=" $ class'TextUtilities_Twitch'.static.UrlEncode(Choices[I]);
    }

    httpGet = Spawn(class'HttpGetRequest');
    httpGet.Call(Url, OnPollCreated, OnPollCreateError);
}

function EndPoll(string Id) {
    local HttpGetRequest httpGet;

    `TILOG("EndPoll: Id=" $ Id);
    httpGet = Spawn(class'HttpGetRequest');
    httpGet.Call("localhost:5000/api/poll/end?id=" $ Id);
}

function GetCurrentPollState() {
    local HttpGetRequest httpGet;

    httpGet = Spawn(class'HttpGetRequest');
    httpGet.Call("localhost:5000/api/poll/current", OnCurrentPollReceived, OnCurrentPollReceiveError);
}

// Retrieves the viewer with the given login, if they're in chat. Returns their index in the
// CurrentChatters array if found, or INDEX_NONE if not.
function int GetViewer(string Login, out TwitchChatter Chatter) {
    local TwitchChatter Empty;
    local int Index;

    Index = CurrentChatters.Find('Login', Login);

    if (Index == INDEX_NONE) {
        Chatter = Empty;
        Chatter.Login = Login;
        return INDEX_NONE;
    }

    Chatter = CurrentChatters[Index];
    return Index;
}

function LoadPendingEvents() {
    local HttpGetRequest httpGet;

    httpGet = Spawn(class'HttpGetRequest');
    httpGet.Call("localhost:5000/api/events/pending", OnPendingEventsReceived, OnPendingEventsReceiveError);
}

function LoadViewerList() {
    local HttpGetRequest httpGet;

    `TILOG("Loading viewer list from app connection");

    httpGet = Spawn(class'HttpGetRequest');
    httpGet.Call("localhost:5000/api/chat/chatters", OnNamesListReceived, OnNamesListReceiveError);
}

/// <summary>
/// Selects a viewer who does not currently own any object. Do not call this multiple times without assigning
/// ownership first, or you may get the same viewer repeatedly.
/// </summary>
/// <returns>The index of the viewer in the CurrentChatters array, or INDEX_NONE if no viewers are available.</returns>
function int RaffleViewer() {
    local bool bExcludeBroadcaster;
    local int AvailableIndex, Index, RaffledIndex;
    local int NumAvailableViewers;
    local TwitchChatter Viewer;

    bExcludeBroadcaster = `TI_CFG(bExcludeBroadcaster);

    for (Index = 0; Index < RiggedRaffles.Length; Index++) {
        UpsertViewer(RiggedRaffles[Index], Viewer);
        RiggedRaffles.Remove(Index, 1);

        if (Viewer.OwnedObjectID > 0) {
            // This viewer can't rig a raffle because they already own something
            Index--;
            continue;
        }

        return CurrentChatters.Find('Login', Viewer.Login);
    }

    for (Index = 0; Index < CurrentChatters.Length; Index++) {
        if (CurrentChatters[Index].OwnedObjectID > 0) {
            continue;
        }

        if (bExcludeBroadcaster && CurrentChatters[Index].IsBroadcaster) {
            continue;
        }

        NumAvailableViewers++;
    }

    if (NumAvailableViewers == 0) {
        return INDEX_NONE;
    }

    RaffledIndex = Rand(NumAvailableViewers);
    `TILOG("Out of " $ NumAvailableViewers $ " available viewers, rolled for #" $ RaffledIndex);

    for (Index = 0; Index < CurrentChatters.Length; Index++) {
        // We've raffled an index into a virtual array of only available viewers, so now we
        // need to count through it by only incrementing at available viewers
        if (CurrentChatters[Index].OwnedObjectID > 0) {
            continue;
        }

        if (bExcludeBroadcaster && CurrentChatters[Index].IsBroadcaster) {
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

function ResolveCurrentPoll(bool ApplyResults) {
    local XComGameState NewGameState;
	local XComGameStateContext_ChangeContainer Context;
    local XComGameState_TwitchEventPoll PollGameState;

    PollGameState = class'X2TwitchUtils'.static.GetActivePoll();

    if (PollGameState == none) {
        return;
    }

    EndPoll(PollGameState.TwitchPollId);

    NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Twitch Poll Resolving");
    PollGameState = XComGameState_TwitchEventPoll(NewGameState.ModifyStateObject(class'XComGameState_TwitchEventPoll', PollGameState.ObjectID));
    PollGameState.RemainingTurns = PollGameState.RemainingTurns > 0 ? 0 : -1; // don't erase negative values, which indicate a time-based poll
    PollGameState.IsActive = false;
    PollGameState.ApplyResults = ApplyResults;

    Context = XComGameStateContext_ChangeContainer(NewGameState.GetContext());
	Context.BuildVisualizationFn = BuildVisualization_PollEnding;

	`GAMERULES.SubmitGameState(NewGameState);
}

// Public so it can be called from console commands/actions
function X2PollGroupTemplate SelectPollGroupTemplateByWeight(optional array<name> AllowedTemplateNames) {
    local array<X2PollGroupTemplate> EligibleTemplates;
    local X2PollGroupTemplate Template;
    local int RunningTotal, TotalWeight, WeightRoll;
    local int Index;

    EligibleTemplates = class'X2PollGroupTemplateManager'.static.GetPollGroupTemplateManager().GetEligiblePollGroupTemplates();

    if (AllowedTemplateNames.Length > 0) {
        for (Index = EligibleTemplates.Length - 1; Index >= 0; Index--) {
            if (AllowedTemplateNames.Find(EligibleTemplates[Index].DataName) == INDEX_NONE) {
                EligibleTemplates.Remove(Index, 1);
            }
        }
    }

    if (EligibleTemplates.Length == 0) {
        return none;
    }

    foreach EligibleTemplates(Template) {
        TotalWeight += Template.Weight;
    }

    WeightRoll = Rand(TotalWeight);

    foreach EligibleTemplates(Template) {
        if (WeightRoll < RunningTotal + Template.Weight) {
            `TILOG("Weighted roll selected poll group " $ Template.DataName $ " with roll " $ WeightRoll);
            return Template;
        }

        RunningTotal += Template.Weight;
    }

    `TILOG("Default selected poll group " $ EligibleTemplates[EligibleTemplates.Length - 1].DataName $ "; TotalWeight=" $ TotalWeight $ ", roll=" $ WeightRoll);
    return EligibleTemplates[EligibleTemplates.Length - 1];
}

function StartPoll(X2PollGroupTemplate PollGroupTemplate) {
    local int Index, NumChoices;
    local int ChannelPointsPerVote;
    local X2PollChoiceTemplateManager TemplateMgr;
	local array<X2PollChoiceTemplate> PollEvents;
    local array<string> ChoiceNames;
    local PollData Data;

    // Check if there's already a poll running
    if (class'X2TwitchUtils'.static.GetActivePoll() != none) {
        `TILOG("Not starting a poll because there's already one running");
        return;
    }

    NumChoices = PollGroupTemplate.RollForNumberOfChoices();
    PollEvents = PollGroupTemplate.RollForChoices(NumChoices);
    NumChoices = PollEvents.Length; // in case we couldn't add as many choices as requested

    TemplateMgr = class'X2PollChoiceTemplateManager'.static.GetPollChoiceTemplateManager();

	Data.PollGroupTemplateName = PollGroupTemplate.DataName;
	Data.DurationInTurns = PollGroupTemplate.DurationInTurns;

	Data.PollChoices.Length = NumChoices;
    ChoiceNames.Length = NumChoices;

    for (Index = 0; Index < NumChoices; Index++) {
	    Data.PollChoices[Index].Title = PollEvents[Index].FriendlyName;
	    Data.PollChoices[Index].TemplateName = PollEvents[Index].DataName;

        ChoiceNames[Index] = TemplateMgr.GetPollChoiceTemplate(PollEvents[Index].DataName).FriendlyName;
    }

    ChannelPointsPerVote = `TI_CFG(bAllowChannelPointVotes) ? `TI_CFG(ChannelPointsPerVote) : 0;
    Data.DurationInSeconds = PollGroupTemplate.DurationInTurns > 0 ? 1800 : (PollGroupTemplate.DurationInSeconds > 0 ? PollGroupTemplate.DurationInSeconds : 120);

    CreatePollEventHandler.PendingPollData = Data;

    CreatePoll(PollGroupTemplate.PollTitle, ChoiceNames, Data.DurationInSeconds, ChannelPointsPerVote);
}

function TimeoutViewer(string ViewerLogin, int DurationInSeconds) {
    local HttpGetRequest httpGet;
    local string Url;

    `TILOG("TimeoutViewer called with ViewerLogin = " $ ViewerLogin $ ", DurationInSeconds = " $ DurationInSeconds);

    Url = "localhost:5000/api/moderation/timeout?viewerLogin=" $ ViewerLogin $ "&durationInSeconds=" $ DurationInSeconds;

    httpGet = Spawn(class'HttpGetRequest');
    httpGet.Call(Url); // fire and forget
}

function bool TryGetViewer(string UserLogin, out TwitchChatter chatter) {
    local int Index;

    // TODO: this probably should be using user ID and not login, because events from the EBS may not have a login due to
    // anonymous transactions
    Index = CurrentChatters.Find('Login', UserLogin);

    if (Index == INDEX_NONE)
    {
        return false;
    }

    chatter = CurrentChatters[Index];
    return true;
}

function UpsertViewer(string UserLogin, out TwitchChatter Viewer) {
    local XComGameState_Unit Unit;

    if (TryGetViewer(UserLogin, Viewer)) {
        return;
    }

    Viewer.Login = UserLogin;
    Viewer.DisplayName = UserLogin;
    Viewer.SubTier = 0;
    Viewer.IsBroadcaster = false;

    Unit = class'X2TwitchUtils'.static.FindUnitOwnedByViewer(UserLogin);
    Viewer.OwnedObjectID = Unit.ObjectID;

    CurrentChatters.AddItem(Viewer);
}

// ----------------------------------------------
// Private functions

private function BuildVisualization_PollEnding(XComGameState VisualizeGameState) {
    local VisualizationActionMetadata ActionMetadata;
	local XComGameState_TwitchEventPoll PollState;

	foreach VisualizeGameState.IterateByClassType(class'XComGameState_TwitchEventPoll', PollState) {
		break;
	}

    if (!PollState.ApplyResults) {
        class'UIPollPanel'.static.HidePanel();
        return;
    }

	ActionMetadata.StateObject_OldState = `XCOMHISTORY.GetGameStateForObjectID(PollState.ObjectID, eReturnType_Reference, VisualizeGameState.HistoryIndex - 1);
	ActionMetadata.StateObject_NewState = PollState;

    class'X2Action_ShowPollResults'.static.AddToVisualizationTree(ActionMetadata, VisualizeGameState.GetContext());
}

private function OnCurrentPollReceived(HttpGetRequest Request, HttpResponse Response) {
	local JsonObject ResponseObj;

	if (Response.ResponseCode != 200) {
		`TILOG("Error occurred when retrieving current poll; response code was " $ Response.ResponseCode);
        Request.Close();
        Request.Destroy();
		return;
	}

	ResponseObj = class'JsonObject'.static.DecodeJson(Response.Body);
    ResponseObj.SetStringValue("$type", "updatePoll");

    LatestPollModel = class'TwitchPollModel'.static.FromJson(ResponseObj);

    EventQueue.AddItem(ResponseObj);

    Request.Close();
    Request.Destroy();
}

private function OnCurrentPollReceiveError(HttpGetRequest Request, HttpResponse Response) {
    `TILOG("Error occurred when retrieving current poll; response code was " $ Response.ResponseCode);
    `TILOG("Response body: " $ Response.Body);

    Request.Close();
    Request.Destroy();
}

private function OnNamesListReceiveError(HttpGetRequest Request, HttpResponse Response) {
    `TILOG("Error occurred when retrieving viewers; response code was " $ Response.ResponseCode);
    `TILOG("Response body: " $ Response.Body);

    Request.Close();
    Request.Destroy();
}

private function OnNamesListReceived(HttpGetRequest Request, HttpResponse Response) {
    local int I;
    local TwitchChatter Chatter;
    local array<TwitchChatter> Chatters;
	local JsonObject ResponseObj, UserObj;
    local XComGameState_TwitchObjectOwnership Ownership;

	if (Response.ResponseCode != 200) {
		`TILOG("Error occurred when retrieving viewers; response code was " $ Response.ResponseCode);
        Request.Close();
        Request.Destroy();
		return;
	}

	ResponseObj = class'JsonObject'.static.DecodeJson(Response.Body);

    for (I = 0; I < ResponseObj.ObjectArray.Length; I++)
    {
        UserObj = ResponseObj.ObjectArray[I];

        Chatter.Login = UserObj.GetStringValue("user_login");
        Chatter.DisplayName = UserObj.GetStringValue("user_name");
        Chatter.SubTier = UserObj.GetIntValue("sub_tier");
        Chatter.IsBroadcaster = UserObj.GetBoolValue("is_broadcaster");

        // TODO: doing this for every single chatter on every refresh might get pretty expensive on large streams
        Ownership = class'XComGameState_TwitchObjectOwnership'.static.FindForUser(Chatter.Login);
        if (Ownership != none) {
            Chatter.OwnedObjectID = Ownership.OwnedObjectRef.ObjectID;
        }

        Chatters.AddItem(Chatter);
    }

    CurrentChatters = Chatters;

    bIsViewerListPopulated = true;
    Request.Close();
    Request.Destroy();

    if (!`TI_IS_STRAT_GAME) {
        // We always create a chat log, and let that component worry about hiding itself based on config
        if (ChatLog == none) {
            ChatLog = Spawn(class'UIChatLog', `SCREENSTACK.GetFirstInstanceOf(class'UITacticalHud')).InitChatLog();
            ChatLog.AnchorTopLeft();
        }

        if (RaffleWinnersPanel == none) {
            RaffleWinnersPanel = Spawn(class'UIRaffleWinnersPanel', `SCREENSTACK.GetFirstInstanceOf(class'UITacticalHud')).InitRafflePanel();
            RaffleWinnersPanel.AnchorTopLeft();
        }
    }
}

private function OnPendingEventsReceiveError(HttpGetRequest Request, HttpResponse Response) {
    `TILOG("Error occurred when retrieving pending events; response code was " $ Response.ResponseCode);
    `TILOG("Response body: " $ Response.Body);

    Request.Close();
    Request.Destroy();
}

private function OnPendingEventsReceived(HttpGetRequest Request, HttpResponse Response) {
	local int I;
    local JsonObject ResponseObj;

	if (Response.ResponseCode != 200) {
		`TILOG("Error occurred when retrieving pending events; response code was " $ Response.ResponseCode);
        Request.Close();
        Request.Destroy();
		return;
	}

	ResponseObj = class'JsonObject'.static.DecodeJson(Response.Body);

    // We can't process any events right now; our callback isn't on the main game thread, and could be running during the processing
    // of another game state, in which case handling events may lead to a crash. Push the events into a queue and we'll handle them
    // on the main thread later.
    for (I = 0; I < ResponseObj.ObjectArray.Length; I++)
    {
        EventQueue.AddItem(ResponseObj.ObjectArray[I]);
    }

    Request.Close();
    Request.Destroy();
}

private function OnPollCreated(HttpGetRequest Request, HttpResponse Response) {
    local JsonObject ResponseObj;

	if (Response.ResponseCode != 200) {
		`TILOG("Error occurred when creating a poll; response code was " $ Response.ResponseCode);
        Request.Close();
        Request.Destroy();
		return;
	}

	ResponseObj = class'JsonObject'.static.DecodeJson(Response.Body);
    ResponseObj.SetStringValue("$type", "createPoll"); // not in the actual response, have to add it for event handling

    LatestPollModel = class'TwitchPollModel'.static.FromJson(ResponseObj);

    EventQueue.AddItem(ResponseObj);

    Request.Close();
    Request.Destroy();

    // Start getting updates on the poll's status and votes
    SetTimer(2.0, /* bInLoop */ false, nameof(GetCurrentPollState));
}

private function OnPollCreateError(HttpGetRequest Request, HttpResponse Response) {
    `TILOG("Error occurred when creating a poll; response code was " $ Response.ResponseCode);
    `TILOG("Response body: " $ Response.Body);

    Request.Close();
    Request.Destroy();
}

private function EventListenerReturn OnPlayerTurnBegun(Object EventData, Object EventSource, XComGameState GameState, Name Event, Object CallbackData) {
    local XComGameState NewGameState;
    local XComGameState_Player PlayerState;
    local XComGameState_TwitchEventPoll PollGameState;

    PlayerState = XComGameState_Player(EventSource);

	// We only care about the XCOM player's turn, not the AI's
	if (PlayerState.TeamFlag != eTeam_XCom) {
		return ELR_NoInterrupt;
    }

    PollGameState = class'X2TwitchUtils'.static.GetActivePoll();

    if (PollGameState == none) {
        if (ShouldStartPoll(PlayerState)) {
            StartPoll(SelectPollGroupTemplateByWeight());
        }

        return ELR_NoInterrupt;
    }

    if (PollGameState.RemainingTurns < 0) {
        // This is a time-based poll, don't modify it
        return ELR_NoInterrupt;
    }

    if (PollGameState.RemainingTurns == 1) {
        ResolveCurrentPoll(/* ApplyResults */ true);
        return ELR_NoInterrupt;
    }

	NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Twitch Poll Turn Elapsed");
    PollGameState = XComGameState_TwitchEventPoll(NewGameState.ModifyStateObject(class'XComGameState_TwitchEventPoll', PollGameState.ObjectID));
    PollGameState.RemainingTurns--;

	`GAMERULES.SubmitGameState(NewGameState);

    class'UIPollPanel'.static.GetPanel().SetTurnsRemaining(PollGameState.RemainingTurns);

    return ELR_NoInterrupt;
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
        // TODO: handle time-based polls here
        if (PollState.RemainingTurns > 0) {
            // This poll is still going right now
            `TILOG("There's already an active poll, not starting a new one");
            return false;
        }

        TurnsSinceLastPollStarted = PlayerState.PlayerTurnCount - PollState.PlayerTurnCountWhenStarted;
        TurnsSinceLastPollEnded = TurnsSinceLastPollStarted - PollState.Data.DurationInTurns;

        if (TurnsSinceLastPollEnded < `TI_CFG(MinTurnsBetweenPolls)) {
            `TILOG("Last poll ended " $ TurnsSinceLastPollEnded $ " turns ago; cannot start another yet");
            return false;
        }
    }

    // Roll it
    return Rand(100) < `TI_CFG(ChanceToStartPoll);
}

defaultproperties
{
    bIsViewerListPopulated=false
}