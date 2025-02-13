/// <summary>
/// Event handler for when a Twitch poll is created. The flow for polls is:
///
///   1. The game determines it should create a poll.
///   2. A poll type is selected and its info is sent to the stream companion app.
///   3. If the app is able to create a Twitch poll, an event is generated.
///   4. When the game receives the event, we submit a poll game state and set up the UI.
///
/// This class is responsible for step #4.
/// </summary>
class TwitchEventHandler_CreatePoll extends TwitchEventHandler;

var PollData PendingPollData;

function Handle(TwitchStateManager StateMgr, JsonObject Data) {
    local int I;
    local TwitchPollModel PollModel;
	local XComGameState NewGameState;
    local XComGameState_Player PlayerState;
	local XComGameState_TwitchEventPoll PollState;
    local X2PollGroupTemplate PollGroupTemplate;
    local PollData Empty;

    `TILOG("Handling a new poll");

    PollGroupTemplate = class'X2PollGroupTemplateManager'.static.GetPollGroupTemplateManager().GetPollGroupTemplate(PendingPollData.PollGroupTemplateName);

    PlayerState = XComGameState_Player(`XCOMHISTORY.GetGameStateForObjectID(`TACTICALRULES.GetCachedUnitActionPlayerRef().ObjectID));

	NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Twitch Poll Start");

    PollModel = class'TwitchPollModel'.static.FromJson(Data);

    // Need to copy over the template names for the poll choices, since Twitch/the app don't know about them
    PollModel.PollGroupTemplateName = PendingPollData.PollGroupTemplateName;

    for (I = 0; I < PollModel.Choices.Length; I++) {
        PollModel.Choices[I].TemplateName = StateMgr.LatestPollModel.Choices[I].TemplateName;
    }

	PollState = XComGameState_TwitchEventPoll(NewGameState.CreateNewStateObject(class'XComGameState_TwitchEventPoll'));
    PollState.Data = PendingPollData;
    PollState.TwitchPollId = PollModel.Id;

    PollState.PlayerTurnCountWhenStarted = PlayerState.PlayerTurnCount;
    PollState.RemainingTurns = PollGroupTemplate.DurationInTurns > 0 ? PollGroupTemplate.DurationInTurns : -1;
    PollState.IsActive = true;

    `GAMERULES.SubmitGameState(NewGameState);

    class'UIPollPanel'.static.UpdateInProgress(PollModel);

    PendingPollData = Empty;
}

defaultproperties
{
    EventType="createPoll"
}