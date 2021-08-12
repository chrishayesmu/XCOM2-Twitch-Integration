class X2Action_Twitch_SetUnitScale extends X2Action;

var float AddedScale;

var private float TotalAdded;

simulated state Executing
{
    function bool ModifyScale() {
        local float Delta;

        Delta = AddedScale > 0 ? 0.03 : -0.03;
        TotalAdded += Delta;

        UnitPawn.Mesh.SetScale(1 + TotalAdded);

        return Abs(TotalAdded - AddedScale) < 0.03;
    }

Begin:
    while (!ModifyScale()) {
        // Scale the unit over multiple frames
        Sleep(0.05);
    }

    CompleteAction();
}

defaultproperties
{
    TimeoutSeconds=10
}