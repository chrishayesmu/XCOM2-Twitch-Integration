// Handles poll state updates
class TwitchEventHandler_UpdatePoll extends TwitchEventHandler;

function Handle(TwitchStateManager StateMgr, JsonObject Data) {
    local TwitchPollModel PollModel;

    PollModel = class'TwitchPollModel'.static.FromJson(Data);

    class'UIPollPanel'.static.UpdateInProgress(PollModel);

    if (PollModel.Status == "TERMINATED" || PollModel.Status == "COMPLETED" || PollModel.Status == "ARCHIVED") {
        `TILOG("Resolving current poll. Status is " $ PollModel.Status);
        StateMgr.ResolveCurrentPoll(/* ApplyResults */ true);
    }
    else if (PollModel.Status == "MODERATED") {
        // A mod or the broadcaster deleted the poll in the Twitch UI
        `TILOG("Current poll's status is " $ PollModel.Status $ ". Ending poll without applying results.");
        StateMgr.ResolveCurrentPoll(/* ApplyResults */ false);
    }
    else if (PollModel.Status == "ACTIVE" || true) {
        StateMgr.SetTimer(1.5, /* bInLoop */ false, 'GetCurrentPollState', StateMgr);
    }
}

defaultproperties
{
    EventType="updatePoll"
}