// Handles poll state updates
class TwitchEventHandler_UpdatePoll extends TwitchEventHandler;

function Handle(TwitchStateManager StateMgr, JsonObject Data) {
    local TwitchPollModel PollModel;

    PollModel = class'TwitchPollModel'.static.FromJson(Data);

    class'UIPollPanel'.static.UpdateInProgress(PollModel);

    if (PollModel.Status == "TERMINATED" || PollModel.Status == "COMPLETED") {
        `TILOG("Resolving current poll. Status is " $ PollModel.Status);
        StateMgr.ResolveCurrentPoll();
    }
    else if (PollModel.Status == "ACTIVE" || true) {
        StateMgr.SetTimer(1.5, /* bInLoop */ false, 'GetCurrentPollState', StateMgr);
    }
}

defaultproperties
{
    EventType="updatePoll"
}