class XComGameState_TwitchObjectOwnership extends XComGameState_BaseObject;

var string TwitchUsername;
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

static function XComGameState_TwitchObjectOwnership FindForUser(string Username) {
    local XComGameState_TwitchObjectOwnership OwnershipState;

    foreach `XCOMHISTORY.IterateByClassType(class'XComGameState_TwitchObjectOwnership', OwnershipState) {
        if (OwnershipState.TwitchUsername == Username) {
            return OwnershipState;
        }
    }

    return none;
}