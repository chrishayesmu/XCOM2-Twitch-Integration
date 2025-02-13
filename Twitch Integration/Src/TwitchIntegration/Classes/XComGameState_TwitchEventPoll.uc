class XComGameState_TwitchEventPoll extends XComGameState_BaseObject dependson(TwitchPollModel, X2PollChoiceTemplate);

// All of the data which would normally go in the game state directly; here it's a struct
// because we need the same data in a non-game-state context as well.
struct PollData {
    var name PollGroupTemplateName;
    var array<PollChoice> PollChoices;
    var int DurationInTurns; // The initial duration of the poll; does not change after poll starts
    var int DurationInSeconds; // The initial duration of the poll; does not change after poll starts
};

var PollData Data;

var string TwitchPollId; // ID assigned to the poll by Twitch
var int PlayerTurnCountWhenStarted; // The XComGameState_Player.PlayerTurnCount on the turn this poll began
var int RemainingTurns; // How many turns are left to vote (if the time is measured in turns)
var bool IsActive; // Whether this poll is still active or not

defaultproperties
{
    bTacticalTransient = true
}