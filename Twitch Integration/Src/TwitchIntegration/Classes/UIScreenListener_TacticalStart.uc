// Usually we connect to Twitch by responding to the OnTacticalBeginPlay event, but unfortunately,
// that event does not fire when loading into the tactical game directly.
class UIScreenListener_TacticalStart extends UIScreenListener;

event OnInit(UIScreen Screen)
{
    if (UITacticalHud(Screen) != none) {
        `TILOGCLS("Tactical HUD loaded");
        // Wait a few seconds; when the tactical HUD first loads there may still be a cinematic or loading
        // screen up, so any temporary things we do (like a 'connection successful' toast) will disappear
        // without being seen by the player
        `BATTLE.SetTimer(5.0, /* inBLoop */ false, nameof(SpawnStateManagerIfNeeded), self);
    }
}

private function SpawnStateManagerIfNeeded() {
    if (`TISTATEMGR == none) {
        `XCOMGAME.Spawn(class'TwitchStateManager').Initialize();
    }
}