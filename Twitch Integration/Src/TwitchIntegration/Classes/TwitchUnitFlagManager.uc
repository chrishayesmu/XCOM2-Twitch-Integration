class TwitchUnitFlagManager extends Actor
    config(TwitchUI)
    dependson(UIScreenListener_TwitchUsernameInjector);

const VERBOSE_LOGS = false;

struct TwitchFlag {
    var int AttachedObjectID;
    var UIUnitFlag AttachedFlag;
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
var private array<TwitchFlag> m_arrTwitchFlags;
var private UIUnitFlagManager  m_kUnitFlagManager;

const ICON_HEIGHT = 28;
const ICON_WIDTH = 28;
const TEXT_HEIGHT = 48;

function Initialize() {
    local XComGameStateHistory History;
    local XComGameState_TwitchObjectOwnership OwnershipState;
    local XComGameState_Unit Unit;

    History = `XCOMHISTORY;
    m_kUnitFlagManager = `PRES.m_kUnitFlagManager;

    `TILOG("Creating Twitch unit flags; UnitFlagManager = " $ m_kUnitFlagManager);

    // When loading into tactical, we need to make sure our UI is present
    foreach History.IterateByClassType(class'XComGameState_TwitchObjectOwnership', OwnershipState) {
        Unit = XComGameState_Unit(History.GetGameStateForObjectID(OwnershipState.OwnedObjectRef.ObjectID));

        `TILOG("Syncing unit flag for unit " $ Unit.GetFullName() $ " to owner " $ OwnershipState.TwitchLogin);
        AddOrUpdateFlag(Unit, OwnershipState);
    }

	`XWORLDINFO.MyWatchVariableMgr.RegisterWatchVariable(m_kUnitFlagManager, 'm_arrFlags', self, OnUnitFlagsArrayChanged);
}

event Tick(float DeltaTime) {
    local XComGameState_Unit UnitState;
    local int Index;

    super.Tick(DeltaTime);

    fTimeSinceLastFlagCheck += DeltaTime;

    if (fTimeSinceLastFlagCheck >= 2.0f) {
        fTimeSinceLastFlagCheck = 0.0f;

        for (Index = UnitIDsPendingFlagUpdate.Length - 1; Index >= 0; Index--) {
            `TILOG("Index = " $ Index $ "; UnitIDsPendingFlagUpdate.Length = " $ UnitIDsPendingFlagUpdate.Length, VERBOSE_LOGS);

            UnitState = XComGameState_Unit(`XCOMHISTORY.GetGameStateForObjectID(UnitIDsPendingFlagUpdate[Index]));

            if (AddOrUpdateFlag(UnitState)) {
                UnitIDsPendingFlagUpdate.Remove(Index, 1);
            }
        }
    }
}

function bool AddOrUpdateFlag(XComGameState_Unit Unit, optional XComGameState_TwitchObjectOwnership Ownership = none) {
    local int FlagIndex, UnitObjID;
    local TwitchFlag TFlag;
    local UIUnitFlag UnitFlag;
    local XComPresentationLayer Pres;

    `TILOG("AddOrUpdateFlag for Unit = " $ Unit $ ", Ownership = " $ Ownership, VERBOSE_LOGS);

    if (Unit == none) {
        `TILOG("ERROR: asked to update unit flag but Unit was none!");
        return false;
    }

    if (Unit.bRemovedFromPlay) {
        `TILOG("Unit is removed from play; skipping");
        return false;
    }

    Pres = `PRES;
    UnitObjID = Unit.GetReference().ObjectID;
    UnitFlag = Pres.m_kUnitFlagManager.GetFlagForObjectID(UnitObjID);

    if (Ownership == none) {
        `TILOG("Ownership is none; retrieving it", VERBOSE_LOGS);
        Ownership = class'XComGameState_TwitchObjectOwnership'.static.FindForObject(Unit.ObjectID);
    }

    if (Unit.GetMyTemplate().bIsCosmetic || Unit.IsCivilian()) {
        `TILOG("This unit will never have a flag; skipping it", VERBOSE_LOGS);
        SetUnitName(Unit, Ownership);
        return true; // act like we added a flag, because retrying is a waste
    }

    if (UnitFlag == none) {
        `TILOG("Unit has no flag; adding to list of units to sync later", VERBOSE_LOGS);

        if (UnitIDsPendingFlagUpdate.Find(UnitObjID) == INDEX_NONE) {
            UnitIDsPendingFlagUpdate.AddItem(UnitObjID);
        }

        return false;
    }

    if (GetFlagForObject(UnitObjID, TFlag, FlagIndex)) {
        `TILOG("Already found internal Twitch flag for obj ID " $ UnitObjID, VERBOSE_LOGS);

        if (TFlag.AttachedFlag != UnitFlag) {
            `TILOG("Original unit flag has changed; swapping to the new one");

            RecreateTwitchFlag(TFlag, UnitFlag, Unit, Ownership);
            m_arrTwitchFlags[FlagIndex] = TFlag;
        }
        else if (Ownership != none) {
            TFlag.TwitchName.SetText(Ownership.TwitchLogin);
            TFlag.TwitchName.Show();
            TFlag.BGBox.Show();
            TFlag.TwitchEmote.Show();
            TFlag.TwitchIcon.Show();
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
        `TILOG("Creating new Twitch flag", VERBOSE_LOGS);

        TFlag = CreateTwitchFlag(UnitFlag, Unit, Ownership);
        m_arrTwitchFlags.AddItem(TFlag);

        // Once our flag is created, it's time to set the unit's name. We don't want to do this
        // before the unit flag is fully initialized, because we want the base game's flag to show
        // the unit's original name, and not include the Twitch name in it.
        SetUnitName(Unit, Ownership);
    }

    return true;
}

function bool GetFlagForObject(int ObjectID, out TwitchFlag TFlag, optional out int Index) {
    Index = m_arrTwitchFlags.Find('AttachedObjectID', ObjectID);

    if (Index == INDEX_NONE) {
        return false;
    }

    TFlag = m_arrTwitchFlags[Index];
    return true;
}

function OnUnitFlagsArrayChanged() {
    local XComGameState_Unit Unit;
    local int Index, ObjectID;

    `TILOG("Unit flag array changed; processing " $ m_kUnitFlagManager.m_arrFlags.Length $ " flags");

    for (Index = 0; Index < m_kUnitFlagManager.m_arrFlags.Length; Index++) {
        ObjectID = m_kUnitFlagManager.m_arrFlags[Index].StoredObjectID;
        Unit = XComGameState_Unit(`XCOMHISTORY.GetGameStateForObjectID(ObjectID));

        AddOrUpdateFlag(Unit);
    }
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
    local TwitchChatter Chatter;

    `TISTATEMGR.GetViewer(Ownership.TwitchLogin, Chatter);

    TFlag.AttachedObjectID = UnitFlag.StoredObjectID;
    TFlag.AttachedFlag = UnitFlag;

    EmoteSize = Unit.GetTeam() == eTeam_XCom ? FriendlyEmoteSize : UnalliedEmoteSize;

    // Random width; it'll be changed later when the viewer's name is set and realized
    TFlag.BGBox = Spawn(class'UIBGBox', UnitFlag).InitBG(,,, /* InitWidth */ 50, ICON_HEIGHT + 4);
    TFlag.BGBox.SetAlpha(BackgroundOpacity);

    TFlag.TwitchEmote = Spawn(class'TwitchUnitFlagEmote', UnitFlag).Init(EmoteSize.X, EmoteSize.Y);

    TFlag.TwitchIcon = Spawn(class'UIImage', UnitFlag).InitImage(, "img:///TwitchIntegration_UI.Icon_Twitch_3D");
    TFlag.TwitchIcon.SetSize(ICON_WIDTH, ICON_HEIGHT);

    TFlag.TwitchName = Spawn(class'UIText', UnitFlag);
    TFlag.TwitchName.OnTextSizeRealized = OnTextSizeRealized;
    TFlag.TwitchName.InitText(, `TIVIEWERNAME(Chatter));

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

private function RecreateTwitchFlag(out TwitchFlag TFlag, UIUnitFlag UnitFlag, XComGameState_Unit Unit, XComGameState_TwitchObjectOwnership Ownership) {
    local TwitchFlag NewTFlag;

    // Create a new flag and destroy the old one after copying its data
    NewTFlag = CreateTwitchFlag(UnitFlag, Unit, Ownership);
    NewTFlag.TwitchEmote.DirectLoadImage(TFlag.TwitchEmote.ImagePath);

    TFlag.BGBox.Destroy();
    TFlag.TwitchEmote.Destroy();
    TFlag.TwitchIcon.Destroy();
    TFlag.TwitchName.Destroy();

    TFlag = NewTFlag;
}

private function SetUnitName(XComGameState_Unit Unit, XComGameState_TwitchObjectOwnership Ownership) {
    local XComGameState NewGameState;
    local XComGameState_Unit OriginalUnit;
    local TwitchChatter Viewer;
	local string FirstName, LastName;

    if (!class'X2DownloadableContentInfo_TwitchIntegration'.const.SET_UNIT_NAMES) {
        return;
    }

    if (Unit.GetMyTemplate().bIsCosmetic) {
        return;
    }

    if (Unit.GetTeam() != eTeam_Resistance && Unit.IsSoldier()) {
        // Don't do anything in this case; we don't modify soldiers because the player has full agency to do that
        return;
    }

    `TISTATEMGR.GetViewer(Ownership.TwitchLogin, Viewer);

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
        // Always pull the unit name from its original version, so we don't accidentally append onto our own name if running more than once
        OriginalUnit = XComGameState_Unit(`XCOMHISTORY.GetOriginalGameStateRevision(Unit.GetReference().ObjectID));

        FirstName = `TIVIEWERNAME(Viewer);
        LastName = "(" $ OriginalUnit.GetName(eNameType_Full) $ ")";
    }

    `TILOG("Setting unit name", VERBOSE_LOGS);
    Unit.SetUnitName(FirstName, LastName, "");

    if (NewGameState != none) {
        `GAMERULES.SubmitGameState(NewGameState);
    }
}

private function OnTextSizeRealized() {
    local TwitchFlag TFlag;

    // We don't get any indication of which Text object just got realized,
    // so we have no choice but to go through all of our flags
    foreach m_arrTwitchFlags(TFlag) {
        TFlag.BGBox.SetWidth(ICON_WIDTH + TFlag.TwitchName.Width + 12);
    }
}