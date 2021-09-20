class X2Action_Twitch_ToggleNameplate extends X2Action;

var bool bEnableNameplate;

simulated state Executing
{
    function SetNameplate() {
        local TwitchViewer Viewer;
	    local X2Action_PlaySoundAndFlyOver SoundAndFlyover;
        local XComGameState_TwitchObjectOwnership OwnershipState;

        if (bEnableNameplate) {
            class'UIUtilities_Twitch'.static.ShowTwitchName(Unit.ObjectID, , /* bPermanent */ `TI_CFG(bPermanentNameplatesEnabled));
        }
        else {
            class'UIUtilities_Twitch'.static.HideTwitchName(Unit.ObjectID);
        }
    }

Begin:
    SetNameplate();
    CompleteAction();
}