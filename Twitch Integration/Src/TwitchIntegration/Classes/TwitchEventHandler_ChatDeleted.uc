class TwitchEventHandler_ChatDeleted extends TwitchEventHandler;

function Handle(TwitchStateManager StateMgr, JsonObject Data) {
    local XComLWTuple Tuple;

    Tuple = new class'XComLWTuple';
    Tuple.Id = 'TwitchChatMessageDeleted';
    Tuple.Data.Add(1);
    Tuple.Data[0].kind = XComLWTVString;
    Tuple.Data[0].s = Data.GetStringValue("message_id");

    `XEVENTMGR.TriggerEvent('TwitchChatMessageDeleted', Tuple);
}

defaultproperties
{
    EventType="chatDeletion"
}