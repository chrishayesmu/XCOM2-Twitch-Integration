class UITwitchTacticalRename extends UIPanel
    dependson(TwitchStateManager);

var private UIButton ChangeButton;
var private UIText Text;
var private UIImage TwitchIcon;

simulated function OnInit() {
    local UITacticalHud TacticalHud;

    super.OnInit();

    TacticalHud = UITacticalHud(ParentPanel);

    if (TacticalHud == none) {
        `TILOG("ERROR: UITwitchTacticalRename needs to be parented to a UITacticalHud!");
        Hide();
        return;
    }

    AnchorBottomLeft();
    SetPosition(34, -180);

    ChangeButton = Spawn(class'UIButton', self).InitButton('', "Change Owner", OnChangeButtonClicked);
    ChangeButton.SetPosition(0, -30);

    TwitchIcon = Spawn(class'UIImage', self).InitImage(, "img:///TwitchIntegration_UI.Icon_Twitch_3D");
    TwitchIcon.SetPosition(0, 0);
    TwitchIcon.SetSize(28, 28);

    Text = Spawn(class'UIText', self);
    Text.InitText();
    Text.SetPosition(30, -2);

	WorldInfo.MyWatchVariableMgr.RegisterWatchVariable(XComTacticalController(PC),        'm_kActiveUnit',        self, RealizeUI);
	WorldInfo.MyWatchVariableMgr.RegisterWatchVariable(UITacticalHUD(Screen),             'm_isMenuRaised',       self, RealizeUI);
	WorldInfo.MyWatchVariableMgr.RegisterWatchVariable(XComPresentationLayer(Movie.Pres), 'm_kInventoryTactical', self, RealizeUI);

    RealizeUI();
}

function OnChangeButtonClicked(UIButton Button) {
	local TInputDialogData kData;
    local XComGameState_TwitchObjectOwnership OwnershipState;
	local XGUnit ActiveUnit;

	ActiveUnit = XComTacticalController(PC).GetActiveUnit();
    OwnershipState = class'XComGameState_TwitchObjectOwnership'.static.FindForObject(ActiveUnit.ObjectID);

	kData.strTitle = "Change Twitch Owner";
	kData.iMaxChars = 40;
	kData.strInputBoxText = OwnershipState != none ? OwnershipState.TwitchLogin : "";
	kData.fnCallback = OnChangeOwnerInputClosed;

	Movie.Pres.UIInputDialog(kData);
}

function OnChangeOwnerInputClosed(string NewViewerLogin) {
    local XComGameState_TwitchObjectOwnership UnitOwnershipState, ViewerOwnershipState;
	local XGUnit ActiveUnit;

	ActiveUnit = XComTacticalController(PC).GetActiveUnit();
    UnitOwnershipState = class'XComGameState_TwitchObjectOwnership'.static.FindForObject(ActiveUnit.ObjectID);

    if (NewViewerLogin == "") {
        if (UnitOwnershipState != none) {
            `TILOG("Deleting ownership of unit from owner " $ UnitOwnershipState.TwitchLogin);
            class'XComGameState_TwitchObjectOwnership'.static.DeleteOwnership(UnitOwnershipState);
        }
    }
    else if (!(NewViewerLogin ~= UnitOwnershipState.TwitchLogin)) {
        ViewerOwnershipState = class'XComGameState_TwitchObjectOwnership'.static.FindForUser(NewViewerLogin);

        if (ViewerOwnershipState != none) {
            `TILOG("Viewer already owns a unit");
            class'X2TwitchUtils'.static.RaiseViewerLoginAlreadyInUseDialog(NewViewerLogin);

            return;
        }
        else {
            `TILOG("Assigning unit to new owner " $ NewViewerLogin);
            class'X2EventListener_TwitchNames'.static.AssignOwnership(NewViewerLogin, ActiveUnit.ObjectID, , /* OverridePreviousOwnership */ true);
        }
    }

    RealizeUI();
}

function RealizeUI() {
    local string ViewerName;
    local TwitchChatter Viewer;
	local XComGameState_Effect_TemplarFocus FocusState;
    local XComGameState_Unit UnitState;
    local XComGameState_TwitchObjectOwnership OwnershipState;
	local XGUnit ActiveUnit;

	if (!bIsInited) {
		return;
	}

	ActiveUnit = XComTacticalController(PC).GetActiveUnit();

	if (ActiveUnit == none) {
		Hide();
        return;
	}

    Show();

    OwnershipState = class'XComGameState_TwitchObjectOwnership'.static.FindForObject(ActiveUnit.ObjectID);

    if (OwnershipState == none) {
        ViewerName = "&lt;Unowned&gt;";
    }
    else {
        `TISTATEMGR.GetViewer(OwnershipState.TwitchLogin, Viewer);
        ViewerName = `TIVIEWERNAME(Viewer);
    }

    Text.SetText(ViewerName);

    UnitState = XComGameState_Unit(`XCOMHISTORY.GetGameStateForObjectID(ActiveUnit.ObjectID));
	FocusState = UnitState.GetTemplarFocusEffectState();

	if (FocusState != none) {
        // Move our UI up slightly to avoid covering the focus UI
        SetPosition(34, -235);
    }
    else {
        SetPosition(34, -180);
    }
}