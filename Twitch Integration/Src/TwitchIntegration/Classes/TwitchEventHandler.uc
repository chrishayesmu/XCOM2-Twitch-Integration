class TwitchEventHandler extends Object
    dependson(TwitchStateManager)
    config (TwitchChatCommands)
    abstract;

/// <summary>
/// The event type which this handler is responsible for. This must correspond to the "$type"
/// field in the event JSON provided by the Stream Companion app. Subclasses should set this in
/// their defaultproperties block.
/// </summary>
var protectedwrite string EventType;

function Initialize(TwitchStateManager StateMgr) {
}

function Handle(TwitchStateManager StateMgr, JsonObject Data);

protected function bool TryGetInvokingUser(TwitchStateManager StateMgr, JsonObject Data, out TwitchChatter Chatter) {
    local string UserLogin;

    // TODO: this probably should be using user ID and not login, because events from the EBS may not have a login due to
    // anonymous transactions
    UserLogin = Data.GetStringValue("user_login");

    if (UserLogin == "") {
        return false;
    }

    return StateMgr.TryGetViewer(UserLogin, Chatter);
}