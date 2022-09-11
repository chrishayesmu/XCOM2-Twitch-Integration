class TwitchUnitFlagManager extends Actor
    config(TwitchUI)
    dependson(UIScreenListener_TwitchUsernameInjector);

struct TwitchFlag {
    var int AttachedObjectID;
    var UIBGBox BGBox;
    var TwitchUnitFlagEmote TwitchEmote;
    var UIImage TwitchIcon;
    var UIText TwitchName;
};

var config TLabelPosition FriendlyEmotePosition;
var config TLabelPosition FriendlyEmoteSize;
var config TLabelPosition FriendlyNamePosition;
var config TLabelPosition UnalliedEmotePosition;
var config TLabelPosition UnalliedEmoteSize;
var config TLabelPosition UnalliedNamePosition;
var config float BackgroundOpacity;

var private array<TwitchFlag> m_kTwitchFlags;

const ICON_HEIGHT = 28;
const ICON_WIDTH = 28;
const TEXT_HEIGHT = 48;

function Initialize() {
    local XComGameStateHistory History;
    local XComGameState_TwitchObjectOwnership OwnershipState;
    local XComGameState_Unit Unit;

    History = `XCOMHISTORY;

    `TILOG("Creating Twitch unit flags");

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

    `TILOG("AddOrUpdateFlag for Unit = " $ Unit $ ", Ownership = " $ Ownership);
    Pres = `PRES;
    UnitObjID = Unit.GetReference().ObjectID;
    UnitFlag = Pres.m_kUnitFlagManager.GetFlagForObjectID(UnitObjID);

    if (UnitFlag == none) {
        `TILOG("Flag is none; creating new flag");
        `XWORLDINFO.ConsoleCommand("flushlogs");
        Pres.m_kUnitFlagManager.AddFlag(Unit.GetReference());
        `TILOG("Flag created, getting it");
        `XWORLDINFO.ConsoleCommand("flushlogs");
        UnitFlag = Pres.m_kUnitFlagManager.GetFlagForObjectID(UnitObjID);
        `TILOG("Flag retrieved: " $ UnitFlag);
        `XWORLDINFO.ConsoleCommand("flushlogs");
    }

    `XWORLDINFO.ConsoleCommand("flushlogs");

    if (Ownership == none) {
        `TILOG("Ownership is none; retrieving it");
        Ownership = class'XComGameState_TwitchObjectOwnership'.static.FindForObject(Unit.ObjectID);
    }

    `XWORLDINFO.ConsoleCommand("flushlogs");

    if (GetFlagForObject(UnitObjID, TFlag)) {
        `TILOG("Already found internal Twitch flag for obj ID " $ UnitObjID);
        `XWORLDINFO.ConsoleCommand("flushlogs");

        if (Ownership != none) {
            TFlag.TwitchName.SetText(Ownership.TwitchLogin);
            TFlag.TwitchName.Show();
        }
        else {
            TFlag.TwitchName.SetText("");
            TFlag.BGBox.Hide();
            TFlag.TwitchEmote.Hide();
            TFlag.TwitchIcon.Hide();
            TFlag.TwitchName.Hide();
        }
    }
    else if (Ownership != none) {
        `TILOG("Creating new Twitch flag");
        `XWORLDINFO.ConsoleCommand("flushlogs");

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

function SetTwitchEmoteImage(XComGameState_Unit Unit, string ImagePath) {
    local TwitchFlag TFlag;

    if (GetFlagForObject(Unit.GetReference().ObjectID, TFlag)) {
        TFlag.TwitchEmote.LoadImage(ImagePath);
    }
}

private function TwitchFlag CreateTwitchFlag(UIUnitFlag UnitFlag, XComGameState_Unit Unit, XComGameState_TwitchObjectOwnership Ownership) {
    local TLabelPosition EmoteSize;
    local TwitchFlag TFlag;
    local TwitchViewer Viewer;

    `TISTATEMGR.TwitchChatConn.GetViewer(Ownership.TwitchLogin, Viewer);

    TFlag.AttachedObjectID = UnitFlag.StoredObjectID;
    EmoteSize = Unit.GetTeam() == eTeam_XCom ? FriendlyEmoteSize : UnalliedEmoteSize;

    // Random width; it'll be changed later when the viewer's name is set and realized
    TFlag.BGBox = Spawn(class'UIBGBox', UnitFlag).InitBG(,,, /* InitWidth */ 50, ICON_HEIGHT + 4);
    TFlag.BGBox.SetAlpha(BackgroundOpacity);

    TFlag.TwitchEmote = Spawn(class'TwitchUnitFlagEmote', UnitFlag).Init(EmoteSize.X, EmoteSize.Y);

    TFlag.TwitchIcon = Spawn(class'UIImage', UnitFlag).InitImage(, "img:///TwitchIntegration_UI.Icon_Twitch_3D");
    TFlag.TwitchIcon.SetSize(ICON_WIDTH, ICON_HEIGHT);

    TFlag.TwitchName = Spawn(class'UIText', UnitFlag);
    TFlag.TwitchName.OnTextSizeRealized = OnTextSizeRealized;
    TFlag.TwitchName.InitText(, `TIVIEWERNAME(Viewer));

    // Position differently for friendly units, because the action points indicator is in the way
    if (Unit.GetTeam() == eTeam_XCom) {
        TFlag.BGBox.SetPosition(FriendlyNamePosition.X, FriendlyNamePosition.Y - 2);
        TFlag.TwitchIcon.SetPosition(FriendlyNamePosition.X + 2, FriendlyNamePosition.Y);
        TFlag.TwitchName.SetPosition(FriendlyNamePosition.X + ICON_WIDTH + 4, FriendlyNamePosition.Y - 2);

        TFlag.TwitchEmote.SetPosition(FriendlyEmotePosition.X, FriendlyEmotePosition.Y);
        TFlag.TwitchEmote.SetSize(FriendlyEmoteSize.X, FriendlyEmoteSize.Y);
    }
    else {
        TFlag.BGBox.SetPosition(UnalliedNamePosition.X, UnalliedNamePosition.Y - 2);
        TFlag.TwitchIcon.SetPosition(UnalliedNamePosition.X + 2, UnalliedNamePosition.Y);
        TFlag.TwitchName.SetPosition(UnalliedNamePosition.X + ICON_WIDTH + 4, UnalliedNamePosition.Y - 2);

        TFlag.TwitchEmote.SetPosition(UnalliedEmotePosition.X, UnalliedEmotePosition.Y);
        TFlag.TwitchEmote.SetSize(UnalliedEmoteSize.X, UnalliedEmoteSize.Y);
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