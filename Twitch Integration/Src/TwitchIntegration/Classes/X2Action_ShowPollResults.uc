class X2Action_ShowPollResults extends X2Action;

simulated state Executing
{
    function DestroyPollPanel() {
        local UIPollPanel PollPanel;

        foreach `XCOMGAME.AllActors(class'UIPollPanel', PollPanel) {
            break;
        }

        if (PollPanel != none) {
            PollPanel.Remove();
            PollPanel.Destroy();
        }
    }

    function OpenScreen() {
        local XComGameState_TwitchEventPoll PollGameState;
        local UIPollResultsScreen Screen;

        foreach StateChangeContext.AssociatedState.IterateByClassType(class'XComGameState_TwitchEventPoll', PollGameState) {
            break;
        }

        Screen = Spawn(class'UIPollResultsScreen', `PRES);
        Screen.PollGameState = PollGameState;
        `SCREENSTACK.Push(Screen);
    }

    function bool IsScreenOpen() {
        return `SCREENSTACK.IsInStack(class'UIPollResultsScreen');
    }

Begin:
    class'UIPollPanel'.static.HidePanel(); // get rid of the in-progress UI with voting prompts
    OpenScreen();

    while (IsScreenOpen()) {
        // Halt visualization until user closes the results screen
        Sleep(0.1);
    }

    CompleteAction();
}

defaultproperties
{
	TimeoutSeconds = -1
}