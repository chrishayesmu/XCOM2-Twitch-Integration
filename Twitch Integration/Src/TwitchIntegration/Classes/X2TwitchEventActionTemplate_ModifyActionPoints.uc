class X2TwitchEventActionTemplate_ModifyActionPoints extends X2TwitchEventActionTemplate_TargetsUnits;

var config int PointsToGive;

function Apply(optional XComGameState_Unit InvokingUnit, optional XComGameState_TwitchEventPoll PollGameState) {
    local int TargetNumActionPoints;
    local XComGameState NewGameState;
    local array<XComGameState_Unit> Targets;
    local XComGameState_Unit Unit;

    Targets = FindTargets(InvokingUnit);

    if (Targets.Length == 0) {
        return;
    }

	NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Twitch Give Actions");

    foreach Targets(Unit) {
        TargetNumActionPoints = Max(0, Unit.ActionPoints.Length + PointsToGive);

        if (TargetNumActionPoints == Unit.ActionPoints.Length) {
            continue;
        }

        Unit = XComGameState_Unit(NewGameState.ModifyStateObject(class'XComGameState_Unit', Unit.ObjectID));

        while (Unit.ActionPoints.Length != TargetNumActionPoints) {
            if (Unit.ActionPoints.Length < TargetNumActionPoints) {
                // We are giving action points
                Unit.ActionPoints.AddItem(class'X2CharacterTemplateManager'.default.StandardActionPoint);
            }
            else {
                // We are taking away action points
                Unit.ActionPoints.Remove(0, 1);
            }
        }
    }

    // TODO: visualize

    if (NewGameState.GetNumGameStateObjects() > 0) {
		`GAMERULES.SubmitGameState(NewGameState);
	}
    else {
		`XCOMHISTORY.CleanupPendingGameState(NewGameState);
    }
}

protected function bool IsValidTarget(XComGameState_Unit Unit) {
    if (!super.IsValidTarget(Unit)) {
        return false;
    }

    // Can't remove action points from a target that doesn't have them
    // TODO: do we need to check stun separately from this?
    if (Unit.ActionPoints.Length == 0 && PointsToGive < 0) {
        return false;
    }

    return true;
}