class XComGameState_TwitchEventPoll extends XComGameState_BaseObject dependson(X2PollEventTemplate);

struct PollChoice {
    var Name PollEventTemplateName;
	var int NumVotes;
};

var ePollType PollType;
var array<PollChoice> Choices;
var int DurationInTurns; // The initial duration of the poll; does not change after poll starts
var int RemainingTurns; // How many turns are left to vote
var int PlayerTurnCountWhenStarted; // The XComGameState_Player.PlayerTurnCount on the turn this poll began

defaultproperties
{
    bTacticalTransient = true
}