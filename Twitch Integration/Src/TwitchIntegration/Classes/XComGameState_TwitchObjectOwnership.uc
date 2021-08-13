class XComGameState_TwitchObjectOwnership extends XComGameState_BaseObject;

var string TwitchLogin;
var StateObjectReference OwnedObjectRef;

static function DeleteOwnership(XComGameState_TwitchObjectOwnership Ownership) {
	local XComGameState NewGameState;
	local XComGameState_Unit Unit;

    Unit = XComGameState_Unit(`XCOMHISTORY.GetGameStateForObjectID(Ownership.OwnedObjectRef.ObjectID));

    NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Remove Twitch Ownership");
    NewGameState.RemoveStateObject(Ownership.ObjectID);

    // After deleting the ownership, we need to rename the unit in case the viewer had a bad name (except for soldiers,
    // since any custom soldier name was done manually by the player)
    if (!Unit.IsSoldier()) {
        Unit = XComGameState_Unit(NewGameState.ModifyStateObject(class'XComGameState_Unit', Unit.GetReference().ObjectID));

        if (Unit.IsCivilian()) {
            Unit.SetUnitName("Name", "Deleted", ""); // we don't know what name they used to have
        }
        else {
            // Having no name set will cause it to fall back on the template name
            Unit.SetUnitName("", "", "");
        }

        class'X2TwitchUtils'.static.SyncUnitFlag(Unit);
    }

    `GAMERULES.SubmitGameState(NewGameState);
}

static function XComGameState_TwitchObjectOwnership FindForObject(int ObjID) {
    local XComGameState_TwitchObjectOwnership OwnershipState;

    foreach `XCOMHISTORY.IterateByClassType(class'XComGameState_TwitchObjectOwnership', OwnershipState) {
        if (OwnershipState.OwnedObjectRef.ObjectID == ObjID) {
            return OwnershipState;
        }
    }

    return none;
}

static function XComGameState_TwitchObjectOwnership FindForUser(string Login) {
    local XComGameState_TwitchObjectOwnership OwnershipState;

    foreach `XCOMHISTORY.IterateByClassType(class'XComGameState_TwitchObjectOwnership', OwnershipState) {
        if (OwnershipState.TwitchLogin == Login) {
            return OwnershipState;
        }
    }

    return none;
}