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

var private float fTimeSinceLastFlagCheck;
var private array<int> UnitIDsPendingFlagUpdate;
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

event Tick(float DeltaTime) {
    local XComGameState_Unit UnitState;
    local int Index;

    super.Tick(DeltaTime);

    fTimeSinceLastFlagCheck += DeltaTime;

    if (fTimeSinceLastFlagCheck >= 2.0f) {
        fTimeSinceLastFlagCheck = 0.0f;

        for (Index = UnitIDsPendingFlagUpdate.Length - 1; Index >= 0; Index--) {
            `TILOG("Index = " $ Index $ "; UnitIDsPendingFlagUpdate.Length = " $ UnitIDsPendingFlagUpdate.Length);

            UnitState = XComGameState_Unit(`XCOMHISTORY.GetGameStateForObjectID(UnitIDsPendingFlagUpdate[Index]));

            if (AddOrUpdateFlag(UnitState)) {
                UnitIDsPendingFlagUpdate.Remove(Index, 1);
            }
        }
    }
}

function bool AddOrUpdateFlag(XComGameState_Unit Unit, optional XComGameState_TwitchObjectOwnership Ownership = none) {
    local int UnitObjID;
    local TwitchFlag TFlag;
    local UIUnitFlag UnitFlag;
    local XComPresentationLayer Pres;

    `TILOG("AddOrUpdateFlag for Unit = " $ Unit $ ", Ownership = " $ Ownership);
    `XWORLDINFO.ConsoleCommand("flushlogs");

    if (Unit == none) {
        `TILOG("ERROR: asked to update unit flag but Unit was none!");
        return false;
    }

    Pres = `PRES;
    UnitObjID = Unit.GetReference().ObjectID;
    UnitFlag = Pres.m_kUnitFlagManager.GetFlagForObjectID(UnitObjID);

    if (Ownership == none) {
        `TILOG("Ownership is none; retrieving it");
        Ownership = class'XComGameState_TwitchObjectOwnership'.static.FindForObject(Unit.ObjectID);
    }

    if (Unit.GetMyTemplate().bIsCosmetic || Unit.IsCivilian() || Unit.bRemovedFromPlay) {
        `TILOG("This unit will never have a flag; skipping it");
        SetUnitName(Unit, Ownership);
        return true; // act like we added a flag, because retrying is a waste
    }

    if (UnitFlag == none) {
        `TILOG("Unit has no flag; adding to list of units to sync later");

        if (UnitIDsPendingFlagUpdate.Find(UnitObjID) == INDEX_NONE) {
            UnitIDsPendingFlagUpdate.AddItem(UnitObjID);
        }

        return false;
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

        // Once our flag is created, it's time to set the unit's name. We don't want to do this
        // before the unit flag is fully initialized, because we want the base game's flag to show
        // the unit's original name, and not include the Twitch name in it.
        SetUnitName(Unit, Ownership);
    }

    return true;
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

private function SetUnitName(XComGameState_Unit Unit, XComGameState_TwitchObjectOwnership Ownership) {

    local XComGameState NewGameState;
    local XComGameState_Unit OriginalUnit;
    local TwitchViewer Viewer;
	local string FirstName, LastName;

    if (Unit.GetTeam() == eTeam_XCom && ( Unit.IsSoldier() || Unit.GetMyTemplate().bIsCosmetic )) {
        // Don't do anything in this case; we don't modify soldiers because the player has full agency to do that
        return;
    }

    `TISTATEMGR.TwitchChatConn.GetViewer(Ownership.TwitchLogin, Viewer);

    if (Unit.bReadOnly) {
        NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("TwitchIntegration: Set Unit Name");
        Unit = XComGameState_Unit(NewGameState.ModifyStateObject(class'XComGameState_Unit', Unit.GetReference().ObjectID));
    }

    if (Unit.IsCivilian() || Unit.IsSoldier()) {
        // For civilians and Resistance soldiers, we only show the viewer name. We want to make sure it's
        // in the LastName slot, because the name shows as "First Last", so if LastName is empty there's
        // two spaces in a row, which is noticeable.
        FirstName = "";
        LastName = `TIVIEWERNAME(Viewer);
    }
    else {
        OriginalUnit = XComGameState_Unit(`XCOMHISTORY.GetOriginalGameStateRevision(Unit.GetReference().ObjectID));

        FirstName = `TIVIEWERNAME(Viewer);
        LastName = "(" $ OriginalUnit.GetName(eNameType_Full) $ ")";
    }

    `TILOG("Setting unit name");
    `XWORLDINFO.ConsoleCommand("flushlogs");
    Unit.SetUnitName(FirstName, LastName, "");

    if (NewGameState != none) {
        `GAMERULES.SubmitGameState(NewGameState);
    }
}

private function OnTextSizeRealized() {
    local TwitchFlag TFlag;

    // We don't get any indication of which Text object just got realized,
    // so we have no choice but to go through all of our flags
    foreach m_kTwitchFlags(TFlag) {
        TFlag.BGBox.SetWidth(ICON_WIDTH + TFlag.TwitchName.Width + 12);
    }
}