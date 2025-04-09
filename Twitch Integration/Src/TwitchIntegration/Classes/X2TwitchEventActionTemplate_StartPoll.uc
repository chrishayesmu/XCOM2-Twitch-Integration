class X2TwitchEventActionTemplate_StartPoll extends X2TwitchEventActionTemplate;

var config array<name> AllowedPollGroups;

function Apply(optional XComGameState_Unit InvokingUnit) {
    local TwitchStateManager StateMgr;

    StateMgr = `TISTATEMGR;

    StateMgr.StartPoll(StateMgr.SelectPollGroupTemplateByWeight(AllowedPollGroups));
}

function bool IsValid(optional XComGameState_Unit InvokingUnit) {
    local XComGameState_TwitchEventPoll PollGameState;

    PollGameState = class'X2TwitchUtils'.static.GetActivePoll();

    // Can't start a poll if there's one running already. This will only tell us about
    // polls started by us, not ones running independently on Twitch, but it's close enough.
    return PollGameState == none;
}