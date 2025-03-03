class X2Action_ShowRollTheDiceScreen extends X2Action;

event bool BlocksAbilityActivation() {
    return true;
}

simulated state Executing
{
    function OpenScreen() {
        local XComGameState_TwitchRollTheDice RtdGameState;
        local UIRollTheDiceScreen Screen;

        foreach StateChangeContext.AssociatedState.IterateByClassType(class'XComGameState_TwitchRollTheDice', RtdGameState) {
            break;
        }

        Screen = Spawn(class'UIRollTheDiceScreen', `PRES);
        Screen.Options = RtdGameState.PossibleActions;
        Screen.ViewerLogin = RtdGameState.ViewerLogin;
        Screen.WinningOptionIndex = RtdGameState.SelectedActionIndex;
        Screen.WinningOptionTemplateName = RtdGameState.SelectedActionTemplateName;

        `SCREENSTACK.Push(Screen);
    }

    function bool IsScreenOpen() {
        return `SCREENSTACK.IsInStack(class'UIRollTheDiceScreen');
    }

Begin:
    OpenScreen();

    while (IsScreenOpen()) {
        // Halt visualization until user closes the results screen
        Sleep(0.1);
    }

    Sleep(0.2); // slight pause before we visualize the results
    CompleteAction();
}

defaultproperties
{
	TimeoutSeconds = -1
}