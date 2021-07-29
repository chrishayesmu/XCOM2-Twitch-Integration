class X2Action_AddToChatLog extends X2Action;

simulated state Executing
{
    function UpdateLog() {
        local XComGameState_TwitchXSay XSayState;

        foreach StateChangeContext.AssociatedState.IterateByClassType(class'XComGameState_TwitchXSay', XSayState) {
            break;
        }

        class'X2TwitchUtils'.static.AddMessageToChatLog(XSayState.Sender, XSayState.MessageBody, XComGameState_Unit(Metadata.StateObject_NewState));
    }

Begin:
    UpdateLog();
    CompleteAction();
}

defaultproperties
{
	TimeoutSeconds = 0.25
}