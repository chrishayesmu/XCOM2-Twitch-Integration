class XComGameState_TwitchObjectOwnership extends XComGameState_BaseObject;

var string TwitchLogin;
var StateObjectReference OwnedObjectRef;

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