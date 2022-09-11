class X2Action_Twitch_ToggleNameplate extends X2Action;

var bool bEnableNameplate;

simulated state Executing
{
    function SetNameplate() {
        if (bEnableNameplate) {
            class'UIUtilities_Twitch'.static.ShowTwitchName(Unit.ObjectID, , true); // /* bPermanent */ `TI_CFG(bPermanentNameplatesEnabled));
        }
        else {
            class'UIUtilities_Twitch'.static.HideTwitchName(Unit.ObjectID);
        }
    }

Begin:
    SetNameplate();
    CompleteAction();
}