// Detects when the UIArmory_MainMenu screen is opened, and injects a menu item to set the
// soldier's Twitch username, so that ownership can be established for soldiers.
// Also injects itself on any screen with a UISoldierHeader, in order to show the Twitch
// username as part of the header.
class UIScreenListener_TwitchUsernameInjector extends UIScreenListener;

var localized string strButtonLabel;
var localized string strDescription;
var localized string strDialogTitle;

var private UIArmory_MainMenu ArmoryMainMenu;
var private delegate<OnItemSelectedCallback> OriginalOnItemClicked;
var private delegate<OnItemSelectedCallback> OriginalOnSelectionChanged;
var private UIListItemString TwitchListItem;
var private UIImage TwitchIcon;

const LogScreenNames = false;

delegate OnItemSelectedCallback(UIList ContainerList, int ItemIndex);

event OnInit(UIScreen Screen)
{
    `TILOGCLS("Init screen: " $ Screen.Class.Name, LogScreenNames);

    CheckForArmoryMainMenuScreen(Screen);
    CheckForUISoldierHeader(Screen);
}

event OnReceiveFocus(UIScreen Screen) {
    `TILOGCLS("OnReceiveFocus screen: " $ Screen.Class.Name, LogScreenNames);

    // The armory main menu UIList is regenerated every time the screen receives focus,
    // so we need to keep injecting our menu item into it
    CheckForArmoryMainMenuScreen(Screen);
}

event OnRemoved(UIScreen Screen) {
    if (UIArmory_MainMenu(Screen) != none) {
        OriginalOnItemClicked = none;
        OriginalOnSelectionChanged = none;
        TwitchListItem = none;
    }
}

private function CheckForArmoryMainMenuScreen(UIScreen Screen) {
    local XComGameState_TwitchObjectOwnership OwnershipState;

    if (UIArmory_MainMenu(Screen) != none) {
        ArmoryMainMenu = UIArmory_MainMenu(Screen);

        // The armory screen isn't very extensible, so we need to hijack some event handlers. We store and invoke
        // the original ones in case another mod has done the same thing, to give us the best chance of
        // playing nicely with them.
        if (OriginalOnItemClicked == none) {
            OriginalOnItemClicked = ArmoryMainMenu.List.OnItemClicked;
        }

        ArmoryMainMenu.List.OnItemClicked = OnArmoryMainMenuItemClicked;

        if (OriginalOnSelectionChanged == none) {
            OriginalOnSelectionChanged = ArmoryMainMenu.List.OnSelectionChanged;
        }

        ArmoryMainMenu.List.OnSelectionChanged = OnArmoryMainMenuSelectionChanged;

        // Connect NeedsAttention to whether there's an ownership state for this soldier yet
        OwnershipState = class'XComGameState_TwitchObjectOwnership'.static.FindForObject(ArmoryMainMenu.UnitReference.ObjectID);

        TwitchListItem = ArmoryMainMenu.Spawn(class'UIListItemString', ArmoryMainMenu.List.ItemContainer);
        TwitchListItem.InitListItem(strButtonLabel)
                      .NeedsAttention(OwnershipState == none);
    }
}

private function CheckForUISoldierHeader(UIScreen Screen) {
    local int ImageX;
    local int ImageY;
    local int UnitObjectID;
    local UIBGBox BGBox;
    local UIImage Image;
    local UIText Text;
    local XComGameState_TwitchObjectOwnership OwnershipState;

    // The UISoldierHeader's position doesn't appear to exist outside of Flash on some (all?) screens,
    // but it only appears in a few different spots, so we just have a hard-coded list of where those spots are

    // Need to check UIArmory_PromotionHero first because it extends UIArmory_Promotion
    if (UIArmory_PromotionHero(Screen) != none) {
        ImageX = 282;
        ImageY = 31;
        UnitObjectID = UIArmory(Screen).UnitReference.ObjectID;
    }
    else if (UISoldierBondScreen(Screen) != none) {
        ImageX = 450;
        ImageY = 74;
        UnitObjectID = UISoldierBondScreen(Screen).UnitRef.ObjectID;
    }
    else if (UIArmory_Loadout(Screen) != none
          || UIArmory_MainMenu(Screen) != none
          || UIArmory_Promotion(Screen) != none)
    {
        ImageX = 1251;
        ImageY = 82;
        UnitObjectID = UIArmory(Screen).UnitReference.ObjectID;
    }
    else if (UICustomize(Screen) != none) {
        ImageX = 105;
        ImageY = 82;
        UnitObjectID = UICustomize(Screen).UnitRef.ObjectID;
    }

    if (UnitObjectID <= 0) {
        return;
    }

    OwnershipState = class'XComGameState_TwitchObjectOwnership'.static.FindForObject(UnitObjectID);

    if (OwnershipState == none) {
        return;
    }

    BGBox = Screen.Spawn(class'UIBGBox', Screen).InitBG(, ImageX - 6, ImageY - 6, /* TODO, dynamic width */ 180, 40);
    BGBox.SetAlpha(0.7);

	Image = Screen.Spawn(class'UIImage', Screen).InitImage(, "img:///TwitchIntegration_UI.Icon_Twitch");
    Image.SetPosition(ImageX, ImageY);
    Image.SetSize(28, 28);

    Text = Screen.Spawn(class'UIText', Screen).InitText(, OwnershipState.TwitchLogin);
    Text.SetPosition(Image.X + 34, ImageY - 5);
}

private simulated function int GetMyItemIndex() {
    return ArmoryMainMenu.List.GetItemIndex(TwitchListItem);
}

private simulated function OpenTwitchNameInputBox() {
    local XComGameState_TwitchObjectOwnership OwnershipState;
	local TInputDialogData kData;

    kData.strTitle = strDialogTitle;
    kData.iMaxChars = 40; // supposedly max Twitch name is 25 but it's not documented
    kData.fnCallbackAccepted = OnNameInputBoxClosed;

    OwnershipState = class'XComGameState_TwitchObjectOwnership'.static.FindForObject(ArmoryMainMenu.UnitReference.ObjectID);
    if (OwnershipState != none) {
        kData.strInputBoxText = OwnershipState.TwitchLogin;
    }

    `PRESBASE.UIInputDialog(kData);
}

private function OnNameInputBoxClosed(string Text) {
    local XComGameState NewGameState;
    local XComGameState_TwitchObjectOwnership OwnershipState;

    OwnershipState = class'XComGameState_TwitchObjectOwnership'.static.FindForObject(ArmoryMainMenu.UnitReference.ObjectID);

    if (OwnershipState != none && OwnershipState.TwitchLogin == Text) {
        // Player didn't change anything
        return;
    }

    if (Text == "" && OwnershipState == none) {
        // There was no owner before, and still isn't
        return;
    }

	NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Assign Twitch Owner");

    if (Text == "") {
        // There was an owner but now is not
        NewGameState.RemoveStateObject(OwnershipState.ObjectID);
    }
    else {
        if (OwnershipState == none) {
	        OwnershipState = XComGameState_TwitchObjectOwnership(NewGameState.CreateStateObject(class'XComGameState_TwitchObjectOwnership'));
        }
        else {
            OwnershipState = XComGameState_TwitchObjectOwnership(NewGameState.ModifyStateObject(class'XComGameState_TwitchObjectOwnership', OwnershipState.ObjectID));
        }

        OwnershipState.OwnedObjectRef = ArmoryMainMenu.UnitReference;
        OwnershipState.TwitchLogin = Text;
    }

    `GAMERULES.SubmitGameState(NewGameState);

    // This callback is invoked after the input screen pops itself, so the main menu UI has already been rendered
    // without consideration for our newest game state
    if (TwitchListItem != none) {
        TwitchListItem.NeedsAttention(Text == "");
    }

    // TODO: update injectedname text also
}

private simulated function OnArmoryMainMenuItemClicked(UIList ContainerList, int ItemIndex) {
    if (ItemIndex == GetMyItemIndex()) {
        OpenTwitchNameInputBox();
    }
    else {
        OriginalOnItemClicked(ContainerList, ItemIndex);
    }
}

private simulated function OnArmoryMainMenuSelectionChanged(UIList ContainerList, int ItemIndex) {
    if (ItemIndex == GetMyItemIndex()) {
	    ArmoryMainMenu.MC.ChildSetString("descriptionText", "htmlText", class'UIUtilities_Text'.static.AddFontInfo(strDescription, ArmoryMainMenu.bIsIn3D));
    }
    else {
        OriginalOnSelectionChanged(ContainerList, ItemIndex);
    }
}
