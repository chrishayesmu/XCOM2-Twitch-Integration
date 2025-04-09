class X2TwitchEventActionTemplate_EndPoll extends X2TwitchEventActionTemplate;

var config bool bApplyResults;

function Apply(optional XComGameState_Unit InvokingUnit) {
    `TISTATEMGR.ResolveCurrentPoll(bApplyResults);
}

function bool IsValid(optional XComGameState_Unit InvokingUnit) {
    local XComGameState_TwitchEventPoll PollGameState;

    PollGameState = class'X2TwitchUtils'.static.GetActivePoll();

    // Make sure there's a poll to end
    return PollGameState != none;
}