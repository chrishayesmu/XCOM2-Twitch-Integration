class UITwitchTacticalRename extends UIPanel;

var private UIButton ChangeButton;
var private UIText Text;
var private UIImage TwitchIcon;

simulated function OnInit() {
    local UITacticalHud TacticalHud;

    super.OnInit();

    `TILOG("OnInit");
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

function OnChangeOwnerInputClosed(string Value) {
    local XComGameState_TwitchObjectOwnership OwnershipState;
	local XGUnit ActiveUnit;

	ActiveUnit = XComTacticalController(PC).GetActiveUnit();
    OwnershipState = class'XComGameState_TwitchObjectOwnership'.static.FindForObject(ActiveUnit.ObjectID);

    if (Value == "") {
        if (OwnershipState != none) {
            `TILOG("Deleting ownership of unit from owner " $ OwnershipState.TwitchLogin);
            class'XComGameState_TwitchObjectOwnership'.static.DeleteOwnership(OwnershipState);
        }
    }
    else if (!(Value ~= OwnershipState.TwitchLogin)) {
        `TILOG("Assigning unit to new owner " $ Value);
        class'X2EventListener_TwitchNames'.static.AssignOwnership(Value, ActiveUnit.ObjectID, , /* OverridePreviousOwnership */ true);
    }

    RealizeUI();
}

function RealizeUI() {
    local string ViewerName;
    local TwitchViewer Viewer;
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

    `TILOG("Retrieving ownership for object ID " $ ActiveUnit.ObjectID);
    OwnershipState = class'XComGameState_TwitchObjectOwnership'.static.FindForObject(ActiveUnit.ObjectID);

    if (OwnershipState == none) {
        `TILOG("Ownership state not found");
        ViewerName = "&lt;Unowned&gt;";
    }
    else {
        `TISTATEMGR.TwitchChatConn.GetViewer(OwnershipState.TwitchLogin, Viewer);
        ViewerName = `TIVIEWERNAME(Viewer);
    }

    Text.SetText(ViewerName);
}