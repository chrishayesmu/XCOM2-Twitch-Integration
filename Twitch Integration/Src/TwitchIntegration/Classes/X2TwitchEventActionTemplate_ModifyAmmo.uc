class X2TwitchEventActionTemplate_ModifyAmmo extends X2TwitchEventActionTemplate_TargetsUnits;

var config int AmmoToGive;

function Apply(optional XComGameState_Unit InvokingUnit, optional XComGameState_TwitchEventPoll PollGameState) {
    local int TargetAmmoAmount;
    local XComGameState NewGameState;
    local XComGameState_Item Weapon;
    local array<XComGameState_Unit> Targets;
    local XComGameState_Unit Unit;

    Targets = FindTargets(InvokingUnit);

    if (Targets.Length == 0) {
        return;
    }

	NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Twitch Give Actions");

    foreach Targets(Unit) {
        Weapon = Unit.GetItemInSlot(eInvSlot_PrimaryWeapon, NewGameState);
        TargetAmmoAmount = Clamp(Weapon.Ammo + AmmoToGive, 0, Weapon.GetItemClipSize());

        if (TargetAmmoAmount == Weapon.Ammo) {
            continue;
        }

        Weapon = XComGameState_Item(NewGameState.ModifyStateObject(class'XComGameState_Item', Weapon.ObjectID));
        Weapon.Ammo = TargetAmmoAmount;
    }

    // TODO visualize this

    if (NewGameState.GetNumGameStateObjects() > 0) {
		`GAMERULES.SubmitGameState(NewGameState);
	}
    else {
		`XCOMHISTORY.CleanupPendingGameState(NewGameState);
    }
}

protected function bool IsValidTarget(XComGameState_Unit Unit) {
    local XComGameState_Item Weapon;

    if (!super.IsValidTarget(Unit)) {
        return false;
    }

    Weapon = Unit.GetItemInSlot(eInvSlot_PrimaryWeapon);

    `LOG("Weapon " $ Weapon.Name $ " currently has ammo: " $ Weapon.Ammo $ " for clip size: " $ Weapon.GetItemClipSize());

    if (AmmoToGive > 0 && Weapon.Ammo >= Weapon.GetItemClipSize()) {
        return false; // no ammo missing to refill
    }

    if (AmmoToGive < 0 && Weapon.Ammo == 0) {
        return false; // no ammo to take away
    }

    return true;
}