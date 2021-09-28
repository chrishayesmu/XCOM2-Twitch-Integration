class TwitchUnitFlagManager extends Actor;

struct TwitchFlag {
    var int AttachedObjectID;
    var UIBGBox BGBox;
    var UIImage TwitchIcon;
    var UIText TwitchName;
};

var private array<TwitchFlag> m_kTwitchFlags;

const FRIENDLY_FLAG_POS_X = 80;
const FRIENDLY_FLAG_POS_Y = -15;
const FLAG_POS_X = 30;
const FLAG_POS_Y = -24;
const ICON_HEIGHT = 28;
const ICON_WIDTH = 28;
const TEXT_HEIGHT = 48;

function Initialize() {
    local XComGameStateHistory History;
    local XComGameState_TwitchObjectOwnership OwnershipState;
    local XComGameState_Unit Unit;

    History = `XCOMHISTORY;

    `TILOG("OnLoadedSavedGameToTactical: generating UI");

    // When loading into tactical, we need to make sure our UI is present
    foreach History.IterateByClassType(class'XComGameState_TwitchObjectOwnership', OwnershipState) {
        Unit = XComGameState_Unit(History.GetGameStateForObjectID(OwnershipState.OwnedObjectRef.ObjectID));

        `TILOG("Syncing unit flag for unit " $ Unit.GetFullName() $ " to owner " $ OwnershipState.TwitchLogin);
        AddOrUpdateFlag(Unit, OwnershipState);
    }
}

function AddOrUpdateFlag(XComGameState_Unit Unit, optional XComGameState_TwitchObjectOwnership Ownership = none) {
    local int UnitObjID;
    local TwitchFlag TFlag;
    local UIUnitFlag UnitFlag;
    local XComPresentationLayer Pres;

    Pres = `PRES;
    UnitObjID = Unit.GetReference().ObjectID;
    UnitFlag = Pres.m_kUnitFlagManager.GetFlagForObjectID(UnitObjID);

    `TILOGCLS("AddOrUpdateFlag for unit " $ Unit.GetFullName());

    if (UnitFlag == none) {
        `TILOGCLS("Unit doesn't have a unit flag to attach to");
        return;
    }

    if (Ownership == none) {
        Ownership = class'XComGameState_TwitchObjectOwnership'.static.FindForObject(Unit.ObjectID);
    }

    if (GetFlagForObject(UnitObjID, TFlag)) {
        `TILOGCLS("Flag already exists");

        if (Ownership != none) {
            `TILOGCLS("Owner found, updating text");
            TFlag.TwitchName.SetText(Ownership.TwitchLogin);
            TFlag.TwitchName.Show();
        }
        else {
            `TILOGCLS("No owner found, hiding text");
            TFlag.TwitchName.SetText("");
            TFlag.TwitchName.Hide();
        }
    }
    else if (Ownership != none) {
        `TILOGCLS("Flag does not exist, creating new");
        TFlag = CreateTwitchFlag(UnitFlag, Unit, Ownership);

        m_kTwitchFlags.AddItem(TFlag);
    }
}

function bool GetFlagForObject(int ObjectID, out TwitchFlag TFlag) {
    local int Index;

    Index = m_kTwitchFlags.Find('AttachedObjectID', ObjectID);

    if (Index == INDEX_NONE) {
        return false;
    }

    TFlag = m_kTwitchFlags[Index];
    return true;
}

private function TwitchFlag CreateTwitchFlag(UIUnitFlag UnitFlag, XComGameState_Unit Unit, XComGameState_TwitchObjectOwnership Ownership) {
    local TwitchFlag TFlag;
    local TwitchViewer Viewer;

    `TISTATEMGR.TwitchChatConn.GetViewer(Ownership.TwitchLogin, Viewer);

    TFlag.AttachedObjectID = UnitFlag.StoredObjectID;

    // Random width; it'll be changed later when the viewer's name is set and realized
    TFlag.BGBox = Spawn(class'UIBGBox', UnitFlag).InitBG(,,, /* InitWidth */ 50, ICON_HEIGHT + 4);
    TFlag.BGBox.SetAlpha(0.6);

    TFlag.TwitchIcon = Spawn(class'UIImage', UnitFlag).InitImage(, "img:///TwitchIntegration_UI.Icon_Twitch_3D");
    TFlag.TwitchIcon.SetSize(ICON_WIDTH, ICON_HEIGHT);

    TFlag.TwitchName = Spawn(class'UIText', UnitFlag);
    TFlag.TwitchName.OnTextSizeRealized = OnTextSizeRealized;
    TFlag.TwitchName.InitText(, `TIVIEWERNAME(Viewer));

    // Position differently for friendly units, because the action points indicator is in the way
    if (Unit.GetTeam() == eTeam_XCom) {
        TFlag.BGBox.SetPosition(FRIENDLY_FLAG_POS_X, FRIENDLY_FLAG_POS_Y - 2);
        TFlag.TwitchIcon.SetPosition(FRIENDLY_FLAG_POS_X + 2, FRIENDLY_FLAG_POS_Y);
        TFlag.TwitchName.SetPosition(FRIENDLY_FLAG_POS_X + ICON_WIDTH + 4, FRIENDLY_FLAG_POS_Y - 2);
    }
    else {
        TFlag.BGBox.SetPosition(FLAG_POS_X, FLAG_POS_Y - 2);
        TFlag.TwitchIcon.SetPosition(FLAG_POS_X + 2, FLAG_POS_Y);
        TFlag.TwitchName.SetPosition(FLAG_POS_X + ICON_WIDTH + 4, FLAG_POS_Y - 2);
    }

    return TFlag;
}

private function OnTextSizeRealized() {
    local TwitchFlag TFlag;

    // We don't get any indication of which Text object just got realized,
    // so we have no choice but to go through all of our flags
    foreach m_kTwitchFlags(TFlag) {
        TFlag.BGBox.SetWidth(ICON_WIDTH + TFlag.TwitchName.Width + 12);
    }
}