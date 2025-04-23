class UIScreenListener_TwitchAvengerHud extends UIScreenListener;

event OnInit(UIScreen Screen) {
    local UIAvengerHUD AvengerHud;

    AvengerHud = UIAvengerHUD(Screen);
    if (AvengerHud == none) {
        return;
    }

    if (`TISTATEMGR == none) {
        `TILOG("No TwitchStateManager found; spawning one now");
        `XCOMGAME.Spawn(class'TwitchStateManager').Initialize();
    }
}