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

var private UIBGBox BGBox;
var private UIListItemString TwitchListItem;
var private UIText Text;
var private UIImage TwitchIcon;

const LogScreenNames = false;

delegate OnItemSelectedCallback(UIList ContainerList, int ItemIndex);

event OnInit(UIScreen Screen) {
    `TILOGCLS("OnInit screen: " $ Screen.Class.Name, LogScreenNames);

    RealizeUI(Screen);
}

event OnReceiveFocus(UIScreen Screen)
{
    `TILOGCLS("OnReceiveFocus screen: " $ Screen.Class.Name, LogScreenNames);

    RealizeUI(Screen);
}

event OnRemoved(UIScreen Screen) {
    if (UIArmory_MainMenu(Screen) != none) {
        CleanUpUsernameElements(/* bCleanUpMainMenuList */ true);

        // Clear references to things we don't own
        ArmoryMainMenu = none;
        OriginalOnItemClicked = none;
        OriginalOnSelectionChanged = none;
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

private function bool CheckForUISoldierHeader(UIScreen Screen, out int ImageX, out int ImageY, out int UnitObjectID) {
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
        return false;
    }

    return true;
}

private function CleanUpUsernameElements(bool bCleanUpMainMenuList) {
    // Destroy claims it's working but these elements are still visible, so to be safe we're hiding them first

    if (BGBox != none) {
        BGBox.Hide();
        BGBox.Destroy();
        BGBox = none;
    }

    if (Text != none) {
        Text.Hide();
        Text.Destroy();
        Text = none;
    }

    if (TwitchIcon != none) {
        TwitchIcon.Hide();
        TwitchIcon.Destroy();
        TwitchIcon = none;
    }

    if (TwitchListItem != none && bCleanUpMainMenuList) {
        TwitchListItem.Hide();
        TwitchListItem.Destroy();
        TwitchListItem = none;
    }
}

private function CreateUsernameElements(UIScreen Screen, int ImageX, int ImageY, int UnitObjectID) {
    local XComGameState_TwitchObjectOwnership OwnershipState;

    OwnershipState = class'XComGameState_TwitchObjectOwnership'.static.FindForObject(UnitObjectID);

    if (OwnershipState == none) {
        return;
    }

    BGBox = Screen.Spawn(class'UIBGBox', Screen).InitBG(, ImageX - 6, ImageY - 6, /* TODO, dynamic width */ 180, 40);
    BGBox.SetAlpha(0.7);

	TwitchIcon = Screen.Spawn(class'UIImage', Screen).InitImage(, "img:///TwitchIntegration_UI.Icon_Twitch_3D");
    TwitchIcon.SetPosition(ImageX, ImageY);
    TwitchIcon.SetSize(28, 28);

    Text = Screen.Spawn(class'UIText', Screen);
    Text.OnTextSizeRealized = OnTextSizeRealized;
    Text.InitText(, OwnershipState.TwitchLogin);
    Text.SetPosition(TwitchIcon.X + 34, ImageY - 5);
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

private function OnNameInputBoxClosed(string TextVal) {
    local XComGameState NewGameState;
    local XComGameState_TwitchObjectOwnership OwnershipState;

    OwnershipState = class'XComGameState_TwitchObjectOwnership'.static.FindForObject(ArmoryMainMenu.UnitReference.ObjectID);

    if (OwnershipState != none && OwnershipState.TwitchLogin == TextVal) {
        // Player didn't change anything
        return;
    }

    if (TextVal == "" && OwnershipState == none) {
        // There was no owner before, and still isn't
        return;
    }

	NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Assign Twitch Owner From UI");

    if (TextVal == "") {
        // There was an owner but now is not
        NewGameState.RemoveStateObject(OwnershipState.ObjectID);
    }
    else {
        if (OwnershipState == none) {
	        OwnershipState = XComGameState_TwitchObjectOwnership(NewGameState.CreateNewStateObject(class'XComGameState_TwitchObjectOwnership'));
        }
        else {
            OwnershipState = XComGameState_TwitchObjectOwnership(NewGameState.ModifyStateObject(class'XComGameState_TwitchObjectOwnership', OwnershipState.ObjectID));
        }

        OwnershipState.OwnedObjectRef = ArmoryMainMenu.UnitReference;
        OwnershipState.TwitchLogin = TextVal;
    }

    `GAMERULES.SubmitGameState(NewGameState);

    // This callback is invoked after the input screen pops itself, so the main menu UI has already been rendered
    // without consideration for our newest game state
    RealizeUI(`SCREENSTACK.GetCurrentScreen(), /* bInjectToMainMenu */ false);

    if (TwitchListItem != none) {
        TwitchListItem.NeedsAttention(TextVal == "");
    }
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

private function OnTextSizeRealized() {
    if (Text != none && BGBox != none) {
        BGBox.SetWidth(Text.Width + /* icon width */ 28 + /* post-name padding */ 24);
    }
}

private function RealizeUI(UIScreen Screen, bool bInjectToMainMenu = true) {
    local int ImageX, ImageY, UnitObjectID;

    // Logic for these UI elements is tricky: the most recent screen to receive focus
    // isn't always the one being displayed for some reason. To handle that, we create the UI
    // elements whenever an appropriate screen is focused, and only delete them if we're about to
    // recreate them for another screen. Since they're parented to the UIScreen objects, they will
    // automatically show and hide as needed whenever the parent does.
    if (CheckForUISoldierHeader(Screen, ImageX, ImageY, UnitObjectID)) {
        CleanUpUsernameElements(/* bCleanUpMainMenuList */ bInjectToMainMenu);

        // When entering a Twitch name, the sequence of events is slightly off and causes us to remove and add
        // our list item in the main menu multiple times, which makes the menu too large. Due to this we only touch
        // the main menu if specifically requested.
        if (bInjectToMainMenu) {
            CheckForArmoryMainMenuScreen(Screen);
        }

        CreateUsernameElements(Screen, ImageX, ImageY, UnitObjectID);
    }
}
