class UIRaffleWinnersPanel extends UIPanel
    config(TwitchUI)
    dependson(TwitchChatTcpLink, TwitchIntegrationConfig, UIScreenListener_TwitchUsernameInjector);

var config TLabelPosition Position;
var config TLabelPosition Size;
var config float Opacity;

var private UIButton m_ExpandCollapseButton;
var private UITextContainer m_TextContainer;
var private UITextContainer m_TitleHeader;

function UIRaffleWinnersPanel InitRafflePanel() {
    local Object ThisObj;

    InitPanel();
    SetPosition(Position.X, Position.Y);
    SetSize(Size.X, Size.Y);

    m_TextContainer = Spawn(class'UITextContainer_Twitch', self);
    m_TextContainer.InitTextContainer('', "", 0, 42, Size.X, Size.Y, /* addBG */ true, class'UIUtilities_Controls'.const.MC_X2BackgroundSimple, /* initAutoScroll */ true);
    m_TextContainer.SetAlpha(Opacity);

	m_TitleHeader = Spawn(class'UITextContainer_Twitch', self);
	m_TitleHeader.InitTextContainer('', "", 0, 0, Size.X, 45.0f, /* addBG */ true, class'UIUtilities_Controls'.const.MC_X2BackgroundSimple);
    m_TitleHeader.SetAlpha(Opacity);
    m_TitleHeader.SetHtmlText(class'UIUtilities_Text'.static.GetColoredText("RAFFLE WINNERS", eUIState_Highlight, /* fontSize */ 24, /* align */ "CENTER"));

    // TODO: get an actual icon on this button somehow
    m_ExpandCollapseButton = Spawn(class'UIButton', self);
    m_ExpandCollapseButton.ResizeToText = false;
    m_ExpandCollapseButton.InitButton(/* InitName */, "&lt;", OnExpandCollapseButtonClicked);
    m_ExpandCollapseButton.SetAlpha(Opacity);
    m_ExpandCollapseButton.SetPosition(m_TitleHeader.Width + 3, m_TitleHeader.Y);
    m_ExpandCollapseButton.SetSize(28, 28);

    ThisObj = self;
	`XEVENTMGR.RegisterForEvent(ThisObj, 'TwitchUnitOwnerAssigned', OnOwnershipChanged, ELD_Immediate);
	`XEVENTMGR.RegisterForEvent(ThisObj, 'TwitchUnitOwnerRemoved', OnOwnershipChanged, ELD_Immediate);


    Hide();

    // In case of loading a save, no ownership events will fire for a while,
    // so we just have a timer to kick things off in that case
    SetTimer(1.0, /* inBLoop */ false, 'UpdateUI');

    return self;
}

function Collapse() {
    // animate off screen
    AnimateX(-m_TextContainer.width);
    m_ExpandCollapseButton.SetText("&gt;");
}

function Expand() {
    // animate back on screen
    AnimateX(Position.X);
    m_ExpandCollapseButton.SetText("&lt;");
}

private function EventListenerReturn OnOwnershipChanged(Object EventData, Object EventSource, XComGameState GameState, Name Event, Object CallbackData) {
    // Since ownership tends to change in large chunks (e.g. at the start of a mission, or when a Lost swarm arrives),
    // we just debounce these events so we only update the UI once
    ClearTimer('UpdateUI');
    SetTimer(1.0, /* inBLoop */ false, 'UpdateUI');

    return ELR_NoInterrupt;
}

private function OnExpandCollapseButtonClicked(UIButton Button) {
    ClearTimer('Collapse');

    if (IsCollapsed()) {
        Expand();
    }
    else {
        Collapse();
    }
}

function bool IsCollapsed() {
    return X < 0;
}

private function UpdateUI() {
    local array<string> ViewerNames;
    local string Text;
    local XComGameState_TwitchObjectOwnership OwnershipState;
    local XComGameState_Unit UnitState;

    foreach `XCOMHISTORY.IterateByClassType(class'XComGameState_TwitchObjectOwnership', OwnershipState, , /* bUnlimitedSearch */ true) {
        if (OwnershipState.TwitchLogin == "") {
            continue;
        }

        if (ViewerNames.Find(OwnershipState.TwitchLogin) != INDEX_NONE) {
            continue;
        }

        UnitState = class'X2TwitchUtils'.static.GetViewerUnitOnMission(OwnershipState.TwitchLogin);

        // TODO: IsSoldier includes missions with VIP + escort; escort fighters are soldiers.
        // However, resistance fighters on retaliation missions are not. Ideally we would find
        // a way to include escort soldiers in this UI element.
        if (UnitState == none || UnitState.IsSoldier()) {
            continue;
        }

        ViewerNames.AddItem(OwnershipState.TwitchLogin);
    }

    if (ViewerNames.Length == 0) {
        Hide();
        return;
    }

    Show();
    ViewerNames.Sort(SortNames);

    JoinArray(ViewerNames, Text, "\n", /* bIgnoreBlanks */ true);
    m_TextContainer.SetHTMLText(Text);
}

private function int SortNames(string A, string B) {
	if (A < B) {
		return 1;
	}
	else if (A > B) {
		return -1;
	}
	else {
		return 0;
	}
}