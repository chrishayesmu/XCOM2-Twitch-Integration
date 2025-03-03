class X2TwitchEventActionTemplate_TimeoutUser extends X2TwitchEventActionTemplate;

var config int TimeoutDurationInSeconds;

function Apply(optional XComGameState_Unit InvokingUnit) {
    local XComGameState_TwitchObjectOwnership Ownership;

    if (InvokingUnit == none) {
        `TILOG("Can't run this action without an invoking unit");
        return;
    }

    Ownership = class'XComGameState_TwitchObjectOwnership'.static.FindForObject(InvokingUnit.ObjectID);

    if (Ownership == none) {
        `TILOG("Couldn't find a Twitch owner for unit " $ InvokingUnit.GetFullName());
        return;
    }

    `TISTATEMGR.TimeoutViewer(Ownership.TwitchLogin, TimeoutDurationInSeconds);
}

function bool IsValid(optional XComGameState_Unit InvokingUnit) {
    return InvokingUnit != none;
}
