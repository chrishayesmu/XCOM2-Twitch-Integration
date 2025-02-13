// Handles poll state updates
class TwitchEventHandler_UpdatePoll extends TwitchEventHandler;

function Handle(TwitchStateManager StateMgr, JsonObject Data) {
    local TwitchPollModel PollModel;
	local XComGameState_TwitchEventPoll PollState; // TODO

    PollModel = class'TwitchPollModel'.static.FromJson(Data);

    `TILOG("Received latest poll state, updating UI. Poll status is " $ PollModel.Status);
    class'UIPollPanel'.static.UpdateInProgress(PollModel);

    if (PollModel.Status == "TERMINATED" || PollModel.Status == "COMPLETED") {
        `TILOG("Resolving current poll.");
        StateMgr.ResolveCurrentPoll();
    }
    else if (PollModel.Status == "ACTIVE" || true) {
        `TILOG("Setting timer for GetCurrentPollState again");
        StateMgr.SetTimer(1.5, /* bInLoop */ false, 'GetCurrentPollState', StateMgr);
    }
}

defaultproperties
{
    EventType="updatePoll"
}