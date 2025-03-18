class X2TwitchEventActionTemplate_TimeoutUser extends X2TwitchEventActionTemplate_TargetsUnits;

var config int TimeoutDurationInSeconds;

function Apply(optional XComGameState_Unit InvokingUnit) {
    local XComGameState_Unit Unit;
    local array<XComGameState_Unit> Targets;
    local XComGameState_TwitchObjectOwnership Ownership;

    Targets = FindTargets(InvokingUnit);
    if (Targets.Length == 0) {
        return;
    }

    foreach Targets(Unit) {
        Ownership = class'XComGameState_TwitchObjectOwnership'.static.FindForObject(Unit.ObjectID);

        if (Ownership == none) {
            `TILOG("Couldn't find a Twitch owner for unit " $ Unit.GetFullName());
            continue;
        }

        `TISTATEMGR.TimeoutViewer(Ownership.TwitchLogin, TimeoutDurationInSeconds);
    }
}

function bool IsValid(optional XComGameState_Unit InvokingUnit) {
    return InvokingUnit != none;
}
