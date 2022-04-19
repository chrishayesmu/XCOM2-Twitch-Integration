class XComGameState_TwitchObjectOwnership extends XComGameState_BaseObject;

var string TwitchLogin;
var StateObjectReference OwnedObjectRef;

// These fields are used for ownership of the Chosen, since their object ref doesn't remain valid between missions like soldiers do.
var bool bIsChosenUnit;
var Name ChosenCharacterGroupName;

function XComGameState_TwitchObjectOwnership ChangeObjectRef(StateObjectReference NewObjectRef, optional XComGameState NewGameState) {
    local bool bCreatedGameState;
    local XComGameState_TwitchObjectOwnership ModifiedState;

    if (NewObjectRef.ObjectID == OwnedObjectRef.ObjectID) {
        return self;
    }

    if (NewGameState == none) {
    	NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Twitch Update Object Ref");
        bCreatedGameState = true;
    }

    ModifiedState = XComGameState_TwitchObjectOwnership(NewGameState.ModifyStateObject(class'XComGameState_TwitchObjectOwnership', self.ObjectID));
    ModifiedState.OwnedObjectRef = NewObjectRef;

    if (bCreatedGameState) {
        `GAMERULES.SubmitGameState(NewGameState);
    }

    return ModifiedState;
}

static function DeleteOwnership(XComGameState_TwitchObjectOwnership Ownership, optional XComGameState GameState) {
    local bool bCreatedGameState;
	local XComGameState_Unit Unit;

    Unit = XComGameState_Unit(`XCOMHISTORY.GetGameStateForObjectID(Ownership.OwnedObjectRef.ObjectID));
    `TILOG("Requested to delete ownership of unit " $ Unit.GetFullName() $ " from viewer " $ Ownership.TwitchLogin);

    if (GameState == none || GameState.bReadOnly) {
        `TILOG("Creating new game state");
        GameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Remove Twitch Ownership");
        bCreatedGameState = true;
    }

    // TODO: handle the Chosen specially

    `TILOG("Removing ownership state object");
    GameState.RemoveStateObject(Ownership.ObjectID);

    // After deleting the ownership, we need to rename the unit in case the viewer had a bad name (except for soldiers,
    // since any custom soldier name was done manually by the player)
    if (!Unit.IsSoldier()) {
        `TILOG("Going to update unit name");
        Unit = XComGameState_Unit(GameState.ModifyStateObject(class'XComGameState_Unit', Unit.GetReference().ObjectID));

        if (Unit.IsCivilian()) {
            // We don't know what name civilians used to have
            // TODO: it should be in the earliest history state for them
            Unit.SetUnitName("Name", "Deleted", "");
        }
        else {
            // Having no name set will cause it to fall back on the template name
            Unit.SetUnitName("", "", "");
        }
    }

    if (bCreatedGameState) {
        `TILOG("Submitting newly-created game state");
        `GAMERULES.SubmitGameState(GameState);
    }

    // TODO need to pass new game state through here too
    class'X2TwitchUtils'.static.SyncUnitFlag(Unit);

    `XEVENTMGR.TriggerEvent('TwitchUnitOwnerRemoved', /* EventData */ Ownership, /* EventSource */, GameState);
}

static function XComGameState_TwitchObjectOwnership FindForChosen(Name CharacterGroupName) {
    local XComGameState_TwitchObjectOwnership OwnershipState;

    foreach `XCOMHISTORY.IterateByClassType(class'XComGameState_TwitchObjectOwnership', OwnershipState) {
        if (OwnershipState.bIsChosenUnit && OwnershipState.ChosenCharacterGroupName == CharacterGroupName) {
            return OwnershipState;
        }
    }

    return none;
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

static function XComGameState_TwitchObjectOwnership FindForUser(string Login, optional XComGameState NewGameState) {
    local XComGameState_TwitchObjectOwnership OwnershipState;

    if (NewGameState != none) {
        foreach NewGameState.IterateByClassType(class'XComGameState_TwitchObjectOwnership', OwnershipState) {
            if (OwnershipState.TwitchLogin ~= Login) {
                return OwnershipState;
            }
        }
    }
    else {
        foreach `XCOMHISTORY.IterateByClassType(class'XComGameState_TwitchObjectOwnership', OwnershipState) {
            if (OwnershipState.TwitchLogin ~= Login) {
                return OwnershipState;
            }
        }
    }

    return none;
}