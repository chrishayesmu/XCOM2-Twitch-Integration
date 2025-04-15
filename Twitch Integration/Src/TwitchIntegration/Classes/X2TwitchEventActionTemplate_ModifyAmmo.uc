class X2TwitchEventActionTemplate_ModifyAmmo extends X2TwitchEventActionTemplate_TargetsUnits;

var localized string strAmmoAddedSingular;
var localized string strAmmoAddedPlural;
var localized string strAmmoRemovedSingular;
var localized string strAmmoRemovedPlural;

var config int AmmoToGive;

function Apply(optional XComGameState_Unit InvokingUnit) {
    local int TargetAmmoAmount;
	local XComGameStateContext_ChangeContainer NewContext;
    local XComGameState_Item Weapon;
    local array<XComGameState_Unit> Targets;
    local XComGameState NewGameState;
    local XComGameState_Unit Unit;

    Targets = FindTargets(InvokingUnit);
    if (Targets.Length == 0) {
        return;
    }

    NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Twitch Action: ModifyActionPoints");
	NewContext = XComGameStateContext_ChangeContainer(NewGameState.GetContext());
	NewContext.BuildVisualizationFn = BuildDefaultVisualization;

    foreach Targets(Unit) {
        Weapon = Unit.GetItemInSlot(eInvSlot_PrimaryWeapon, NewGameState);
        TargetAmmoAmount = Clamp(Weapon.Ammo + AmmoToGive, 0, Weapon.GetItemClipSize());

        if (TargetAmmoAmount == Weapon.Ammo) {
            continue;
        }

        Weapon = XComGameState_Item(NewGameState.ModifyStateObject(class'XComGameState_Item', Weapon.ObjectID));
        Weapon.Ammo = TargetAmmoAmount;

        // Just create a new unit state to attach the flyover visualization to it
        Unit = XComGameState_Unit(NewGameState.ModifyStateObject(class'XComGameState_Unit', Unit.ObjectID));
    }

    if (NewGameState.GetNumGameStateObjects() > 0) {
        `GAMERULES.SubmitGameState(NewGameState);
    }
    else {
        `XCOMHISTORY.CleanupPendingGameState(NewGameState);
    }
}

protected function GetFlyoverParams(XComGameState VisualizeGameState, XComGameState_Unit PreviousUnitState, XComGameState_Unit CurrentUnitState, out TwitchActionFlyoverParams FlyoverParams) {
    local XComGameState_Item CurrentWeaponState, PreviousWeaponState;
    local int ChangeInAmmo;
    local string FlyoverText;

    CurrentWeaponState = CurrentUnitState.GetItemInSlot(eInvSlot_PrimaryWeapon);
    PreviousWeaponState = XComGameState_Item(`XCOMHISTORY.GetGameStateForObjectID(CurrentWeaponState.ObjectID, eReturnType_Reference, VisualizeGameState.HistoryIndex - 1));
    ChangeInAmmo = CurrentWeaponState.Ammo - PreviousWeaponState.Ammo;

    if (ChangeInAmmo == 0) {
        `TILOG("WARNING: ChangeInAmmo was 0, but such a game state should not reach visualization", , 'TwitchIntegration');
        return;
    }

    // TODO: different icon for good vs bad
    if (ChangeInAmmo == 1) {
        FlyoverParams.Color = eColor_Good;
        FlyoverText = strAmmoAddedSingular;
    }
    else if (ChangeInAmmo > 1) {
        FlyoverParams.Color = eColor_Good;
        FlyoverText = strAmmoAddedPlural;
    }
    else if (ChangeInAmmo == -1) {
        FlyoverParams.Color = eColor_Bad;
        FlyoverText = strAmmoRemovedSingular;
    }
    else {
        FlyoverParams.Color = eColor_Bad;
        FlyoverText = strAmmoRemovedPlural;
    }

    FlyoverParams.Text = Repl(FlyoverText, "<Ammo/>", int(Abs(ChangeInAmmo)));
}

protected function bool IsValidTarget(XComGameState_Unit Unit) {
    local XComGameState_Item Weapon;

    if (!super.IsValidTarget(Unit)) {
        return false;
    }

    Weapon = Unit.GetItemInSlot(eInvSlot_PrimaryWeapon);

    if (AmmoToGive > 0 && Weapon.Ammo >= Weapon.GetItemClipSize()) {
        return false; // no ammo missing to refill
    }

    if (AmmoToGive < 0 && Weapon.Ammo == 0) {
        return false; // no ammo to take away
    }

    return true;
}

defaultproperties
{
    bHasPerUnitFlyover=true
}