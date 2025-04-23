// Usually we connect to Twitch by responding to the OnTacticalBeginPlay event, but unfortunately,
// that event does not fire when loading into the tactical game directly.
class UIScreenListener_TwitchTacticalHud extends UIScreenListener;

event OnInit(UIScreen Screen) {
    local UITacticalHud TacticalHud;

    TacticalHud = UITacticalHud(Screen);
    if (TacticalHud == none) {
        return;
    }

    // Add our mid-battle rename UI
    if (!HasUITwitchTacticalRenamePanel()) {
        // TODO: attaching to the HUD's m_kStatsContainer directly would simplify a lot
        Screen.Spawn(class'UITwitchTacticalRename', Screen).InitPanel();
    }

    // Wait a few seconds; when the tactical HUD first loads there may still be a cinematic or loading
    // screen up, so any temporary things we do (like a 'connection successful' toast) will disappear
    // without being seen by the player
    `BATTLE.SetTimer(5.0, /* inBLoop */ false, nameof(SpawnStateManagerIfNeeded), self);

    // Set up a timer to periodically check if units enter/leave LOS and handle their nameplates accordingly
    `BATTLE.SetTimer(0.2, /* inBLoop */ true, nameof(CheckUnitLosStatus), self);
}

event OnRemoved(UIScreen Screen) {
    if (UITacticalHud(Screen) == none) {
        return;
    }

    // Remove timers so we don't leak
    `BATTLE.ClearTimer(nameof(CheckUnitLosStatus), self);
}

protected function bool HasUITwitchTacticalRenamePanel() {
    local UITwitchTacticalRename TacRename;

    foreach `XCOMGAME.AllActors(class'UITwitchTacticalRename', TacRename) {
        return true;
    }

    return false;
}

protected function CheckUnitLosStatus() {
    local bool bCivilianNameplatesEnabled;
    local bool bShowNameplate;
    local UIUnitFlagManager UnitFlagManager;
	local UIUnitFlag UnitFlag;
    local XGUnit Unit;

    UnitFlagManager = `PRES.m_kUnitFlagManager;

    if (UnitFlagManager == none) {
        `TILOG("No UnitFlagManager, skipping update to nameplates");
        return;
    }

    bCivilianNameplatesEnabled = !class'X2DownloadableContentInfo_TwitchIntegration'.default.bCivilianNameplatesDisabled;

    foreach `XCOMGAME.AllActors(class'XGUnit', Unit) {
        UnitFlag = UnitFlagManager.GetFlagForObjectID(Unit.ObjectID);

        // We're putting the Twitch name in the unit flag as much as possible, so only show the name as
        // a world message if we can't put it in the unit flag for some reason

        // If a unit flag exists, simply tie into its state; we'll want to match it as often as possible
        if (!bCivilianNameplatesEnabled || UnitFlag != none || !Unit.IsCivilianChar()) {
            bShowNameplate = false;
        }
        else {
            bShowNameplate = class'X2TacticalVisibilityHelpers'.static.CanXComSquadSeeTarget(Unit.ObjectID);
        }

        if (bShowNameplate) {
            class'UIUtilities_Twitch'.static.ShowTwitchName(Unit.ObjectID, , /* bPermanent */ true);
        }
        else {
            class'UIUtilities_Twitch'.static.HideTwitchName(Unit.ObjectID);
        }
    }
}

private function SpawnStateManagerIfNeeded() {
    if (`TISTATEMGR == none) {
        `XCOMGAME.Spawn(class'TwitchStateManager').Initialize();
    }
}