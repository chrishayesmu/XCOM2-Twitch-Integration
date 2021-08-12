class X2Action_AddToChatLog extends X2Action;

var string Sender;
var string Message;

simulated state Executing
{
    function UpdateLog() {
        class'X2TwitchUtils'.static.AddMessageToChatLog(Sender, Message, XComGameState_Unit(Metadata.StateObject_NewState));
    }

Begin:
    UpdateLog();
    CompleteAction();
}

defaultproperties
{
	TimeoutSeconds = 0.25
}