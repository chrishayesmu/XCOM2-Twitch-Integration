class TwitchCommandHandler_ToggleSectopod extends TwitchCommandHandler
    dependson(TwitchStateManager);

function Handle(TwitchStateManager StateMgr, TwitchMessage Command, TwitchViewer Viewer) {
    local XComGameState NewGameState;
	local XComGameStateContext_ChangeContainer NewContext;
	local XComGameState_Unit Unit;

    Unit = class'X2TwitchUtils'.static.FindUnitOwnedByViewer(Viewer.Login);

    if (Unit == none) {
        return;
    }

	NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Toggle Sectopod From " $ Viewer.Login);

    Unit = XComGameState_Unit(NewGameState.ModifyStateObject(class'XComGameState_Unit', Unit.ObjectID));

	NewContext = XComGameStateContext_ChangeContainer(NewGameState.GetContext());
	NewContext.BuildVisualizationFn = ToggleSectopod_BuildVisualization;

    `GAMERULES.SubmitGameState(NewGameState);
}

protected function ToggleSectopod_BuildVisualization(XComGameState VisualizeGameState) {
	local VisualizationActionMetadata ActionMetadata;
	local XComGameState_Unit Unit;
	local XComGameStateHistory History;
    local X2Action_PlayAnimation PlayAnimation;

	History = `XCOMHISTORY;

	foreach VisualizeGameState.IterateByClassType(class'XComGameState_Unit', Unit) {
		break;
	}

	ActionMetadata.StateObject_OldState = Unit;
	ActionMetadata.StateObject_NewState = Unit;
	ActionMetadata.VisualizeActor = History.GetVisualizer(Unit.ObjectID);

    // TODO: either loop the animation so it stays in sync with game state, or activate the actual stand/crouch ability
	PlayAnimation = X2Action_PlayAnimation(class'X2Action_PlayAnimation'.static.AddToVisualizationTree(ActionMetadata, VisualizeGameState.GetContext()));
	PlayAnimation.Params.AnimName = 'HL_Stand2Crouch'; // or 'LL_Crouch2Stand'
}
