class UIPollResultsScreen extends UIScreen
    dependson(XComGameState_TwitchEventPoll);

// ----------------------------
// Localized strings
var localized string strCloseButton;
var localized string strDialogTitle;
var localized string strTotalVotesPlural;
var localized string strTotalVotesSingular;

var localized string strSubtitle_Harbinger;
var localized string strSubtitle_Providence;
var localized string strSubtitle_Sabotage;

// ----------------------------
// Externally accessible state

// The game state to refer to when rendering the UI - must be set before calling InitScreen
var XComGameState_TwitchEventPoll PollGameState;

// ----------------------------
// Private state
var private UIBGBox m_bgBox;
var private UIButton m_CloseButton;
var private UIText m_PollTypeFlavorText;
var private UIText m_TotalVotesText;
var private UIX2PanelHeader	m_TitleHeader;

var private array<UIPollChoice> m_PollChoices;

simulated function InitScreen(XComPlayerController InitController, UIMovie InitMovie, optional name InitName) {
    local array<string> ChoiceNames;
    local int Index;
    local int TotalVotes;
    local PollChoice WinningPollChoice;
    local X2PollEventTemplate WinningEventTemplate;
    local int WinningPollChoiceIndex;
    local EUIState ColorState;
	local string PollColor;

    super.InitScreen(InitController, InitMovie, InitName);

    if (PollGameState == none) {
        `RedScreen("No PollGameState provided to UIPollResultsScreen!");
        return;
    }

    ColorState = class'X2TwitchUtils'.static.GetPollColorState(PollGameState.PollType);
	PollColor = class'X2TwitchUtils'.static.GetPollColor(PollGameState.PollType);
    WinningPollChoice = class'X2TwitchUtils'.static.GetWinningPollChoice(PollGameState, WinningPollChoiceIndex);
    WinningEventTemplate = class'X2TwitchUtils'.static.GetPollEventTemplate(WinningPollChoice.PollEventTemplateName);

    SetAnchor(class'UIUtilities'.const.ANCHOR_MIDDLE_CENTER);

    m_bgBox = Spawn(class'UIBGBox', self);
    m_bgBox.InitBG('', 0, 0, 500, 300, ColorState);

    m_CloseButton = Spawn(class'UIButton', self);
    m_CloseButton.InitButton('ClosePollResultsButton', strCloseButton, OnCloseResultsButtonPress);
    m_CloseButton.OnSizeRealized = RealizeUI;

	m_TitleHeader = Spawn(class'UIX2PanelHeader', self);
	m_TitleHeader.InitPanelHeader('', strDialogTitle, GetSubtitleText(PollGameState.PollType));
	m_TitleHeader.SetColor(PollColor);

    m_PollTypeFlavorText = Spawn(class'UIText', self);
    m_PollTypeFlavorText.InitText('', WinningEventTemplate.Explanation, , RealizeUI);
    m_PollTypeFlavorText.SetColor(PollColor);

    ChoiceNames = GetChoiceNames();
    TotalVotes = GetTotalVotes();

    m_PollChoices.Length = PollGameState.Choices.Length;
    for (Index = 0; Index < m_PollChoices.Length; Index++) {
        m_PollChoices[Index] = Spawn(class'UIPollChoice', self).InitPollChoice(1, '', ChoiceNames[Index], 0, 0, m_bgBox.Width - 50, , , /* bShowResults */ true, /* bDidWinPoll */ Index == WinningPollChoiceIndex);
        m_PollChoices[Index].SetVotes(PollGameState.Choices[Index].NumVotes, TotalVotes);
    }

    m_TotalVotesText = Spawn(class'UIText', self);
    m_TotalVotesText.InitText('', TotalVotes @ (TotalVotes == 1 ? strTotalVotesSingular : strTotalVotesPlural));
}

private function array<string> GetChoiceNames() {
    local array<string> ChoiceNames;
    local PollChoice Choice;
    local X2PollEventTemplate PollEventTemplate;

    foreach PollGameState.Choices(Choice) {
        PollEventTemplate = class'X2TwitchUtils'.static.GetPollEventTemplate(Choice.PollEventTemplateName);
        ChoiceNames.AddItem(PollEventTemplate.FriendlyName);
    }

    return ChoiceNames;
}

private function string GetSubtitleText(ePollType PollType) {
	switch (PollType) {
		case ePollType_Harbinger:
			return strSubtitle_Harbinger;
		case ePollType_Providence:
			return strSubtitle_Providence;
		case ePollType_Sabotage:
			return strSubtitle_Sabotage;
	}
}

private function int GetTotalVotes() {
    local int Total;
    local PollChoice Choice;

    foreach PollGameState.Choices(Choice) {
        Total += Choice.NumVotes;
    }

    return Total;
}

private function OnCloseResultsButtonPress(UIButton Button) {
    `SCREENSTACK.Pop(self);
}

private function RealizeUI() {
    local int BgTop, BgLeft, BgBottom, BgRight;
    local int Index;

    BgBottom = m_bgBox.Height / 2;
    BgRight = m_bgBox.Width / 2;
    BgTop = -BgBottom;
    BgLeft = -BgRight;

    m_bgBox.AnchorCenter();
    m_bgBox.SetPosition(BgLeft, BgTop);

    m_CloseButton.AnchorCenter();
    m_CloseButton.SetPosition(-m_CloseButton.Width / 2, BgBottom - m_CloseButton.Height - 10);

    m_TitleHeader.AnchorCenter();
    m_TitleHeader.SetWidth(m_bgBox.Width - 20);
    m_TitleHeader.SetPosition(-m_TitleHeader.width / 2, BgTop + 10);

    m_PollTypeFlavorText.AnchorCenter();
    m_PollTypeFlavorText.SetPosition(-m_PollTypeFlavorText.Width / 2, m_TitleHeader.Y + 70);

    for (Index = 0; Index < m_PollChoices.Length; Index++) {
        m_PollChoices[Index].AnchorCenter();
        m_PollChoices[Index].SetChoiceWidth(m_bgBox.Width - 40);

        if (Index == 0) {
            m_PollChoices[Index].SetPosition(-m_PollChoices[Index].width / 2, m_PollTypeFlavorText.Y + 35);
        }
        else {
            m_PollChoices[Index].SetPosition(-m_PollChoices[Index].width / 2, m_PollChoices[Index - 1].Y + 35);
        }
    }

    // Total Votes text should be right after the last poll choice
    m_TotalVotesText.AnchorCenter();
    m_TotalVotesText.SetPosition(m_PollChoices[0].X, m_PollChoices[m_PollChoices.Length - 1].Y + 30);
}

defaultproperties
{
	bConsumeMouseEvents	= true;
}