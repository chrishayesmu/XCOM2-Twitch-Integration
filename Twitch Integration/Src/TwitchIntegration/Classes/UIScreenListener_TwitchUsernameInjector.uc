// Detects when the UIArmory_MainMenu screen is opened, and injects a menu item to set the
// soldier's Twitch username, so that ownership can be established for soldiers.
// Also injects itself on any screen with a UISoldierHeader, in order to show the Twitch
// username as part of the header.
class UIScreenListener_TwitchUsernameInjector extends UIScreenListener
    config(TwitchUI);

struct TUnitLabel {
    var bool bAddBackground;
    var int UnitObjectID;
    var int PosX;
    var int PosY;

    var UIBGBox BGBox;
    var UIText Text;
    var UIImage TwitchIcon;
};

struct TLabelPosition {
    var int X;
    var int Y;

    structdefaultproperties
    {
        X=0
        Y=0
    }
};

var localized string strButtonLabel;
var localized string strDescription;
var localized string strDialogTitle;

// #region Config variables: position of UI elements

var config bool bLogPositionVariables;
var config TLabelPosition NamePosition_ArmoryScreens;
var config TLabelPosition NamePosition_CustomizeScreen;
var config TLabelPosition NamePosition_HeroPromotionScreen;
var config TLabelPosition NamePosition_SoldierBondAlertScreen_1;
var config TLabelPosition NamePosition_SoldierBondAlertScreen_2;
var config TLabelPosition NamePosition_SoldierBondScreen;
var config TLabelPosition NamePosition_SoldierCapturedScreen;
var config TLabelPosition NamePosition_SoldierList;
var config TLabelPosition NamePosition_SquadSelectScreen;

// #endregion

var private UIArmory_MainMenu ArmoryMainMenu;
var private delegate<OnItemSelectedCallback> OriginalOnItemClicked;
var private delegate<OnItemSelectedCallback> OriginalOnSelectionChanged;

var private array<TUnitLabel> m_kUnitLabels;
var private array<TUnitLabel> m_kPersonnelListLabels;
var private UIListItemString TwitchListItem;

var private bool bRegisteredForEvents;

const LogScreenNames = true;

delegate OnItemSelectedCallback(UIList ContainerList, int ItemIndex);

event OnInit(UIScreen Screen) {
    local Object ThisObj;

    `TILOG("OnInit screen: " $ Screen.Class.Name, LogScreenNames);

    // FIXME: for some reason, if we don't register every time OnInit is called, our event listener is lost
    ThisObj = self;
    `XEVENTMGR.RegisterForEvent(ThisObj, 'UIPersonnel_OnSortFinished', OnScreenSorted, ELD_Immediate);

    if (UIPersonnel(Screen) == none) {
        RealizeUI(Screen);
    }
}

event OnReceiveFocus(UIScreen Screen)
{
    `TILOG("OnReceiveFocus screen: " $ Screen.Class.Name, LogScreenNames);

    if (UIPersonnel(Screen) == none) {
        RealizeUI(Screen);
    }
}

event OnRemoved(UIScreen Screen) {
    if (UIArmory_MainMenu(Screen) != none) {
        CleanUpUsernameElements(/* bCleanUpMainMenuList */ true);

        // Clear references to things we don't own
        ArmoryMainMenu = none;
        OriginalOnItemClicked = none;
        OriginalOnSelectionChanged = none;
    }

    if (UIPersonnel(Screen) != none) {
        // Zero out length so these labels become eligible for garbage collection
        m_kPersonnelListLabels.Length = 0;
    }
}

private function EventListenerReturn OnScreenSorted(Object EventData, Object EventSource, XComGameState GameState, Name Event, Object CallbackData) {
    local UIScreen Screen;

    Screen = UIScreen(EventSource);

    if (Screen != none) {
        RealizeUI(Screen);
    }

    return ELR_NoInterrupt;
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

private function HandleSquadSelectScreen(UISquadSelect Screen, out array<TUnitLabel> Labels) {
    local int Index;
    local TUnitLabel EmptyLabel, Label;
    local UIList_SquadEditor List;
    local UISquadSelect_ListItem ListItem;

    List = Screen.m_kSlotList;

    `TILOG("In HandleSquadSelectScreen; list has " $ List.GetItemCount() $ " items");
    `TILOG("Using position variable NamePosition_SquadSelectScreen", bLogPositionVariables);

    for (Index = 0; Index < List.GetItemCount(); Index++) {
        ListItem = UISquadSelect_ListItem(List.GetItem(Index));

        Label.bAddBackground = true;
        Label.PosX = NamePosition_SquadSelectScreen.X;
        Label.PosY = NamePosition_SquadSelectScreen.Y;
        Label.UnitObjectID = ListItem.GetUnitRef().ObjectID;

        CreateTwitchUI(ListItem, Label, OnTextSizeRealized_SquadSelect);

        // Needs to be narrower than normal to fit
        Label.BGBox.SetHeight(32);
        Label.BGBox.SetY(Label.PosY - 2);

        Labels.AddItem(Label);
        Label = EmptyLabel;
    }
}

private function ParseUIPersonnelScreen(UIPersonnel Screen, out UIList List, out array<int> ObjectIDs, out array<UIPanel> ParentPanels) {
    local UIPanel Panel;
    local UIPersonnel_SoldierListItem ListItem;

    List = Screen.m_kList;

    foreach List.itemContainer.ChildPanels(Panel) {
        ListItem = UIPersonnel_SoldierListItem(Panel);

        if (ListItem == none) {
            continue;
        }

        ObjectIDs.AddItem(ListItem.UnitRef.ObjectID);
        ParentPanels.AddItem(ListItem);
    }
}

private function ParseUISoldierBondScreen(UISoldierBondScreen Screen, out UIList List, out array<int> ObjectIDs, out array<UIPanel> ParentPanels) {
    local UIPanel Panel;
    local UISoldierBondListItem ListItem;

    List = Screen.List;

    foreach List.itemContainer.ChildPanels(Panel) {
        ListItem = UISoldierBondListItem(Panel);

        if (ListItem == none) {
            continue;
        }

        ObjectIDs.AddItem(ListItem.UnitRef.ObjectID);
        ParentPanels.AddItem(ListItem);
    }
}

private function CheckForSoldierList(UIScreen Screen) {
    local int Index;
    local array<int> ObjectIDs;
    local TUnitLabel EmptyLabel, Label;
    local UIList List;
    local array<UIPanel> ParentPanels;

    // TODO: handle type eUIPersonnel_Deceased
    // TODO: support UISoldierBondScreen with UISoldierBondListItem
    if (UIPersonnel(Screen) != none && UIPersonnel(Screen).m_eListType == eUIPersonnel_Soldiers) {
        ParseUIPersonnelScreen(UIPersonnel(Screen), List, ObjectIDs, ParentPanels);
    }
    else if (UISoldierBondScreen(Screen) != none) {
        ParseUISoldierBondScreen(UISoldierBondScreen(Screen), List, ObjectIDs, ParentPanels);
    }
    else {
        return;
    }

    // Increase the list's mask size so that we can go outside of it with our UI elements
    List.LeftMaskOffset = -1000;
    List.RealizeMaskAndScrollbar();

    m_kPersonnelListLabels.Length = 0;

    `TILOG("Using position variable NamePosition_SoldierList", bLogPositionVariables);


    for (Index = 0; Index < ObjectIDs.Length; Index++) {
        Label.bAddBackground = true;
        Label.PosX = NamePosition_SoldierList.X;
        Label.PosY = NamePosition_SoldierList.Y;
        Label.UnitObjectID = ObjectIDs[Index];

        CreateTwitchUI(ParentPanels[Index], Label, OnPersonnelListTextSizeRealized);

        m_kPersonnelListLabels.AddItem(Label);
        Label = EmptyLabel;
    }
}

private function bool CheckForUISoldierHeader(UIScreen Screen, out array<TUnitLabel> Labels) {
    local TUnitLabel Label;

    Labels.Length = 0;

    // The UISoldierHeader's position doesn't appear to exist outside of Flash on some (all?) screens,
    // but it only appears in a few different spots, so we just have a hard-coded list of where those spots are

    // Need to check UIArmory_PromotionHero first because it extends UIArmory_Promotion
    if (UIArmory_PromotionHero(Screen) != none) {
        `TILOG("Using position variable NamePosition_HeroPromotionScreen", bLogPositionVariables);

        Label.bAddBackground = true;
        Label.PosX = NamePosition_HeroPromotionScreen.X;
        Label.PosY = NamePosition_HeroPromotionScreen.Y;
        Label.UnitObjectID = UIArmory(Screen).UnitReference.ObjectID;

        Labels.AddItem(Label);
    }
    else if (UISoldierBondScreen(Screen) != none) {
        `TILOG("Using position variable NamePosition_SoldierBondScreen", bLogPositionVariables);

        Label.bAddBackground = true;
        Label.PosX = NamePosition_SoldierBondScreen.X;
        Label.PosY = NamePosition_SoldierBondScreen.Y;
        Label.UnitObjectID = UISoldierBondScreen(Screen).UnitRef.ObjectID;

        Labels.AddItem(Label);
    }
    else if (UIArmory_Loadout(Screen) != none
          || UIArmory_MainMenu(Screen) != none
          || UIArmory_Promotion(Screen) != none)
    {
        `TILOG("Using position variable NamePosition_ArmoryScreens", bLogPositionVariables);

        Label.bAddBackground = true;
        Label.PosX = NamePosition_ArmoryScreens.X;
        Label.PosY = NamePosition_ArmoryScreens.Y;
        Label.UnitObjectID = UIArmory(Screen).UnitReference.ObjectID;

        Labels.AddItem(Label);
    }
    else if (UICustomize(Screen) != none) {
        `TILOG("Using position variable NamePosition_CustomizeScreen", bLogPositionVariables);

        Label.bAddBackground = true;
        Label.PosX = NamePosition_CustomizeScreen.X;
        Label.PosY = NamePosition_CustomizeScreen.Y;
        Label.UnitObjectID = UICustomize(Screen).UnitRef.ObjectID;

        Labels.AddItem(Label);
    }
    else if (UISoldierCaptured(Screen) != none) {
        `TILOG("Using position variable NamePosition_SoldierCapturedScreen", bLogPositionVariables);

        Label.bAddBackground = false;
        Label.PosX = NamePosition_SoldierCapturedScreen.X;
        Label.PosY = NamePosition_SoldierCapturedScreen.Y;
        Label.UnitObjectID = UISoldierCaptured(Screen).TargetRef.ObjectID;

        Labels.AddItem(Label);
    }
    else if (UISoldierBondAlert(Screen) != none) {
        `TILOG("Using position variables NamePosition_SoldierBondAlertScreen_1 and NamePosition_SoldierBondAlertScreen_2", bLogPositionVariables);

        Label.bAddBackground = false;
        Label.PosX = NamePosition_SoldierBondAlertScreen_1.X;
        Label.PosY = NamePosition_SoldierBondAlertScreen_1.Y;
        Label.UnitObjectID = UISoldierBondAlert(Screen).UnitRef1.ObjectID;

        Labels.AddItem(Label);

        Label.PosX = NamePosition_SoldierBondAlertScreen_2.X;
        Label.PosY = NamePosition_SoldierBondAlertScreen_2.Y;
        Label.UnitObjectID = UISoldierBondAlert(Screen).UnitRef2.ObjectID;

        Labels.AddItem(Label);
    }
    else if (UISquadSelect(Screen) != none) {
        // This one needs to create its own UI, so handle it a little differently
        HandleSquadSelectScreen(UISquadSelect(Screen), Labels);
        return true;
    }

    if (Labels.Length == 0) {
        return false;
    }

    return true;
}

private function CleanUpUsernameElements(bool bCleanUpMainMenuList) {
    local TUnitLabel Label;

    // Destroy claims it's working but these elements are still visible, so to be safe we're hiding them first
    if (TwitchListItem != none && bCleanUpMainMenuList) {
        TwitchListItem.Hide();
        TwitchListItem.Destroy();
        TwitchListItem = none;
    }

    foreach m_kUnitLabels(Label) {
        if (Label.BGBox != none) {
            Label.BGBox.Hide();
            Label.BGBox.Destroy();
            Label.BGBox = none;
        }

        if (Label.Text != none) {
            Label.Text.Hide();
            Label.Text.Destroy();
            Label.Text = none;
        }

        if (Label.TwitchIcon != none) {
            Label.TwitchIcon.Hide();
            Label.TwitchIcon.Destroy();
            Label.TwitchIcon = none;
        }
    }

    m_kUnitLabels.Length = 0;
}

private function CreateTwitchUI(UIPanel ParentPanel, out TUnitLabel Label, delegate<UIText.OnTextSizeRealized> TextSizeRealizedDelegate) {
    local XComGameState_TwitchObjectOwnership OwnershipState;

    OwnershipState = class'XComGameState_TwitchObjectOwnership'.static.FindForObject(Label.UnitObjectID);

    if (OwnershipState == none) {
        return;
    }

    if (Label.bAddBackground) {
        Label.BGBox = ParentPanel.Spawn(class'UIBGBox', ParentPanel).InitBG(, Label.PosX - 6, Label.PosY - 6, /* width, will change when realized */ 180, 40);
        Label.BGBox.SetAlpha(0.7);
    }

    Label.TwitchIcon = ParentPanel.Spawn(class'UIImage', ParentPanel).InitImage(, "img:///TwitchIntegration_UI.Icon_Twitch_3D");
    Label.TwitchIcon.SetPosition(Label.PosX, Label.PosY);
    Label.TwitchIcon.SetSize(28, 28);

    Label.Text = ParentPanel.Spawn(class'UIText', ParentPanel);
    Label.Text.OnTextSizeRealized = TextSizeRealizedDelegate;
    Label.Text.InitText(, OwnershipState.TwitchLogin);
    Label.Text.SetPosition(Label.TwitchIcon.X + 34, Label.PosY - 2);
}

private function CreateUsernameElements(UIScreen Screen, out array<TUnitLabel> Labels) {
    local int Index;
    local TUnitLabel Label;

    for (Index = 0; Index < Labels.Length; Index++) {
        Label = Labels[Index];

        if (Label.BGBox != none || Label.Text != none || Label.TwitchIcon != none) {
            continue;
        }

        CreateTwitchUI(Screen, Label, OnTextSizeRealized);

        Labels[Index] = Label;
    }
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

private function OnPersonnelListTextSizeRealized() {
    local TUnitLabel Label;

    foreach m_kPersonnelListLabels(Label) {
        if (Label.Text != none && Label.BGBox != none) {
            ScaleBGBoxToText(Label);

            // Move everything left so they don't overlap the list itself
            MoveLabel(Label, -1 * Label.BGBox.Width - 10);
        }
    }
}

private function OnTextSizeRealized() {
    local TUnitLabel Label;

    foreach m_kUnitLabels(Label) {
        ScaleBGBoxToText(Label);
    }
}

private function OnTextSizeRealized_SquadSelect() {
    local TUnitLabel Label;
    local float PosX;

    foreach m_kUnitLabels(Label) {
        ScaleBGBoxToText(Label);

        // The UI panel we're parented to doesn't actually know its own width, so it's just hardcoded here
        PosX = (286 - Label.BGBox.Width) / 2;
        MoveLabel(Label, PosX);
    }
}

private function RealizeUI(UIScreen Screen, optional bool bInjectToMainMenu = true) {
    local array<TUnitLabel> NewLabels;

    CheckForSoldierList(Screen);

    if (CheckForUISoldierHeader(Screen, NewLabels)) {
        // TODO: is cleanup necessary, or will these be deleted automatically because they're parented to a screen? (assuming we don't keep refs)
        CleanUpUsernameElements(/* bCleanUpMainMenuList */ bInjectToMainMenu);

        m_kUnitLabels = NewLabels;

        // When entering a Twitch name, the sequence of events is slightly off and causes us to remove and add
        // our list item in the main menu multiple times, which makes the menu too large. Due to this we only touch
        // the main menu if specifically requested.
        if (bInjectToMainMenu) {
            CheckForArmoryMainMenuScreen(Screen);
        }

        CreateUsernameElements(Screen, m_kUnitLabels);
    }
}

private function MoveLabel(TUnitLabel Label, float NewPosX) {
    Label.BGBox.SetX(NewPosX);
    Label.TwitchIcon.SetX(Label.BGBox.X + 6);
    Label.Text.SetX(Label.TwitchIcon.X + 34);
}

private function ScaleBGBoxToText(TUnitLabel Label) {
    if (Label.Text != none && Label.BGBox != none) {
        Label.BGBox.SetWidth(Label.Text.Width + /* icon width */ 28 + /* post-name padding */ 24);
    }
}