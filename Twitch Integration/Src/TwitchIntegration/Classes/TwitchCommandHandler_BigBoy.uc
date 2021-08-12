class TwitchCommandHandler_BigBoy extends TwitchCommandHandler
    dependson(TwitchStateManager);

function Handle(TwitchStateManager StateMgr, TwitchMessage Command, TwitchViewer Viewer) {
    local XComGameState NewGameState;
	local XComGameStateContext_ChangeContainer NewContext;
	local XComGameState_Unit Unit;

    Unit = class'X2TwitchUtils'.static.FindUnitOwnedByViewer(Viewer.Login);

    if (Unit == none) {
        return;
    }

	NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("BigBoy From " $ Viewer.Login);

    Unit = XComGameState_Unit(NewGameState.ModifyStateObject(class'XComGameState_Unit', Unit.ObjectID));

	NewContext = XComGameStateContext_ChangeContainer(NewGameState.GetContext());
	NewContext.BuildVisualizationFn = BigBoy_BuildVisualization;

    `GAMERULES.SubmitGameState(NewGameState);
}

protected function BigBoy_BuildVisualization(XComGameState VisualizeGameState) {
	local VisualizationActionMetadata ActionMetadata;
	local XComGameState_Unit Unit;
	local XComGameStateHistory History;

    local X2Action_Twitch_SetUnitScale ScaleAction;

	History = `XCOMHISTORY;

	foreach VisualizeGameState.IterateByClassType(class'XComGameState_Unit', Unit) {
		break;
	}

	ActionMetadata.StateObject_OldState = Unit;
	ActionMetadata.StateObject_NewState = Unit;
	ActionMetadata.VisualizeActor = History.GetVisualizer(Unit.ObjectID);

    ScaleAction = X2Action_Twitch_SetUnitScale(class'X2Action_Twitch_SetUnitScale'.static.AddToVisualizationTree(ActionMetadata, VisualizeGameState.GetContext(), , ActionMetadata.LastActionAdded));
    ScaleAction.AddedScale = -0.75;
}
