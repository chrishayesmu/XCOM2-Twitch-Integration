// Usually we connect to Twitch by responding to the OnTacticalBeginPlay event, but unfortunately,
// that event does not fire when loading into the tactical game directly.
class UIScreenListener_TwitchTacticalHud extends UIScreenListener
    config(NonExistentConfigFile);

var private bool bIsAltDown;
var private bool bIsControlDown;

event OnInit(UIScreen Screen) {
    local UITacticalHud TacticalHud;

    TacticalHud = UITacticalHud(Screen);
    if (TacticalHud == none) {
        return;
    }

    TacticalHud.Movie.Stack.SubscribeToOnInputForScreen(TacticalHud, OnTacticalHudInput);

    // Wait a few seconds; when the tactical HUD first loads there may still be a cinematic or loading
    // screen up, so any temporary things we do (like a 'connection successful' toast) will disappear
    // without being seen by the player
    `BATTLE.SetTimer(5.0, /* inBLoop */ false, nameof(SpawnStateManagerIfNeeded), self);

    // Set up a timer to periodically check if units enter/leave LOS and handle their nameplates accordingly
    `BATTLE.SetTimer(0.1, /* inBLoop */ true, nameof(CheckUnitLosStatus), self);
}

event OnRemoved(UIScreen Screen) {
    if (UITacticalHud(Screen) == none) {
        return;
    }

    // Remove timers so we don't leak
    `BATTLE.ClearTimer(nameof(CheckUnitLosStatus), self);
}

protected function CheckUnitLosStatus() {
    local bool bPermanentNameplatesEnabled, bCivilianNameplatesEnabled, bEnemyNameplatesEnabled, bSoldierNameplatesEnabled;
    local bool bShowNameplate;
    local UIWorldMessageMgr WorldMessageMgr;
    local UIUnitFlagManager UnitFlagManager;
	local UIUnitFlag UnitFlag;
	local XComGameStateHistory History;
    local XGUnit Unit;

    UnitFlagManager = `PRES.m_kUnitFlagManager;

    if (UnitFlagManager == none) {
        `TILOGCLS("No UnitFlagManager, skipping update to nameplates");
        return;
    }

    bPermanentNameplatesEnabled = `TI_CFG(bPermanentNameplatesEnabled);
    bCivilianNameplatesEnabled = `TI_CFG(bCivilianNameplatesEnabled);
    bEnemyNameplatesEnabled = `TI_CFG(bEnemyNameplatesEnabled);
    bSoldierNameplatesEnabled = `TI_CFG(bSoldierNameplatesEnabled);

    foreach `XCOMGAME.AllActors(class'XGUnit', Unit) {
        UnitFlag = UnitFlagManager.GetFlagForObjectID(Unit.ObjectID);

        // We're putting the Twitch name in the unit flag as much as possible, so only show the name as
        // a world message if we can't put it in the unit flag for some reason

        // If a unit flag exists, simply tie into its state; we'll want to match it as often as possible
        if (UnitFlag != none) {
            bShowNameplate = false;
        }
        else {
            bShowNameplate = class'X2TacticalVisibilityHelpers'.static.CanXComSquadSeeTarget(Unit.ObjectID);
        }

        if (Unit.IsCivilianChar()) {
            bShowNameplate = bShowNameplate && bCivilianNameplatesEnabled;
        }
        else if (bShowNameplate) {
            `TILOGCLS("WARNING: showing nameplate for a non-civilian unit with XGUnit object ID " $ Unit.ObjectID);
        }

        if (!bShowNameplate) {
            class'UIUtilities_Twitch'.static.HideTwitchName(Unit.ObjectID, WorldMessageMgr);
        }
        else if (bPermanentNameplatesEnabled)  {
            class'UIUtilities_Twitch'.static.ShowTwitchName(Unit.ObjectID, , /* bPermanent */ true);
        }
    }
}

protected function bool OnTacticalHudInput(UIScreen Screen, int iInput, int ActionMask) {
    if (iInput == class'UIUtilities_Input'.const.FXS_KEY_LEFT_ALT) {
        if ((ActionMask & class'UIUtilities_Input'.const.FXS_ACTION_PRESS) == class'UIUtilities_Input'.const.FXS_ACTION_PRESS) {
            bIsAltDown = true;
        }
        else if ((ActionMask & class'UIUtilities_Input'.const.FXS_ACTION_RELEASE) == class'UIUtilities_Input'.const.FXS_ACTION_RELEASE) {
            bIsAltDown = false;
        }

        // Never consume alt, just track its state
        return false;
    }

    if (iInput == class'UIUtilities_Input'.const.FXS_KEY_LEFT_CONTROL) {
        if ((ActionMask & class'UIUtilities_Input'.const.FXS_ACTION_PRESS) == class'UIUtilities_Input'.const.FXS_ACTION_PRESS) {
            bIsControlDown = true;
        }
        else if ((ActionMask & class'UIUtilities_Input'.const.FXS_ACTION_RELEASE) == class'UIUtilities_Input'.const.FXS_ACTION_RELEASE) {
            bIsControlDown = false;
        }

        // Never consume control, just track its state
        return false;
    }

    if (iInput == class'UIUtilities_Input'.const.FXS_KEY_T && bIsControlDown && bIsAltDown) {
        if ((ActionMask & class'UIUtilities_Input'.const.FXS_ACTION_PRESS) == class'UIUtilities_Input'.const.FXS_ACTION_PRESS) {
            ToggleNameplates();

            return true;
        }
    }

    return false;
}

private function SpawnStateManagerIfNeeded() {
    if (`TISTATEMGR == none) {
        `XCOMGAME.Spawn(class'TwitchStateManager').Initialize();
    }
}

private function ToggleNameplates() {
    local bool bPermanentNameplatesEnabled, bUnitIsVisibleToSquad;
    local UIWorldMessageMgr WorldMessageMgr;
    local XGUnit Unit;

    bPermanentNameplatesEnabled = !`TI_CFG(bPermanentNameplatesEnabled);

    class'TwitchIntegrationConfig'.default.bPermanentNameplatesEnabled = bPermanentNameplatesEnabled;
    WorldMessageMgr = `PRES.m_kWorldMessageManager;

    `TILOGCLS("Twitch nameplates enabled: " $ bPermanentNameplatesEnabled);

    CheckUnitLosStatus();
}

defaultproperties
{
    bIsAltDown=false
    bIsControlDown=false
}