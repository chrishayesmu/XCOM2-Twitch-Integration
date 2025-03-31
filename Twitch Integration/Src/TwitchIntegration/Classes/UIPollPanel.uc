class UIPollPanel extends UIPanel
    dependson(UIPollChoice, XComGameState_TwitchEventPoll)
    config(TwitchIntegration);

// ------------------------------------
// Localization strings
var localized string strTotalVotesPlural;
var localized string strTotalVotesSingular;
var localized string strTimeRemaining;
var localized string strTurnsRemainingPlural;
var localized string strTurnsRemainingSingular;

// ------------------------------------
// Internally-handled config
var private int BottomPadding;
var private int HeaderHeight;
var private int HorizontalPadding;
var private int InterChoicePadding;
var private int Padding;
var private int SubtitleHeight;
var private int SubtitlePadding;

// ------------------------------------
// Internally-handled state
var private UIBGBox m_bgBox;
var private UIX2PanelHeader	m_TitleHeader;
var private UIText m_TimeRemaining;
var private UIText m_TotalVotes;
var private array<UIPollChoice> m_PollChoices;

// ------------------------------------
// Poll data
var privatewrite name m_PollGroupTemplateName;
var float m_PollEndTime;

// ------------------------------------
// Public interface
// ------------------------------------

simulated function UIPollPanel InitPollPanel(name PollGroupTemplateName, TwitchPollModel Poll, int DurationInTurns) {
    local EUIState ColorState;
	local string PollColor, DurationString;
    local X2PollGroupTemplate Template;

    m_PollGroupTemplateName = PollGroupTemplateName;
	Template = class'X2PollGroupTemplateManager'.static.GetPollGroupTemplateManager().GetPollGroupTemplate(PollGroupTemplateName);

    if (Template == none) {
        `TILOG("ERROR: couldn't find a poll group template named " $ PollGroupTemplateName);
        return none;
    }

    m_PollEndTime = WorldInfo.RealTimeSeconds + Poll.SecondsRemaining;
    ColorState = Template.ColorState;
	PollColor = Template.TextColor;

	// Positioning/sizing data just based on what looks good
    // TODO pass these in so tactical/strategy panels can be in different spots
	InitPanel();
	AnchorTopRight();
	SetPosition(-430, 275);
	SetSize(400, 150);

	m_bgBox = Spawn(class'UIBGBox', self).InitBG('', 0, 0, self.width, self.height, ColorState);
	m_bgBox.SetAlpha(0.75);

	m_TitleHeader = Spawn(class'UIX2PanelHeader', self);
	m_TitleHeader.InitPanelHeader('', Template.PollTitle, Template.PollSubtitle);
	m_TitleHeader.SetColor(PollColor);
	m_TitleHeader.SetHeaderWidth(self.width - 2 * HorizontalPadding);
	m_TitleHeader.SetPosition(HorizontalPadding, 0);

    // Show time remaining rather than turns, when needed
    if (DurationInTurns > 0) {
        DurationString = DurationInTurns @ (DurationInTurns == 1 ? strTurnsRemainingSingular : strTurnsRemainingPlural);
    }
    else {
        DurationString = class'X2TwitchUtils'.static.SecondsToTimeString(Poll.SecondsRemaining) @ strTimeRemaining;
    }

	m_TimeRemaining = Spawn(class'UIText', self);
    m_TimeRemaining.OnTextSizeRealized = OnTextSizeRealized;
	m_TimeRemaining.InitText('', DurationString);
	m_TimeRemaining.SetColor(PollColor);
	m_TimeRemaining.SetAlpha(0.9);

    m_TotalVotes = Spawn(class'UIText', self);
	m_TotalVotes.InitText('', "0" @ strTotalVotesPlural);
	m_TotalVotes.SetColor(PollColor);
	m_TotalVotes.SetAlpha(0.9);
    m_TotalVotes.SetX(HorizontalPadding);

	SetChoices(Poll.Choices);

	return self;
}

event Tick(float DeltaTime) {
    local float SecondsRemaining;

    SecondsRemaining = Max(0, m_PollEndTime - WorldInfo.RealTimeSeconds);

    SetTimeRemainingText(int(SecondsRemaining));
}

function UIPollPanel SetTimeRemainingText(int SecondsRemaining) {
    local string TimeString;

    TimeString = class'X2TwitchUtils'.static.SecondsToTimeString(SecondsRemaining);

	m_TimeRemaining.SetText(TimeString @ strTimeRemaining);

    return self;
}

function UIPollPanel SetTurnsRemaining(int NumTurnsRemaining) {
	m_TimeRemaining.SetText(NumTurnsRemaining @ (NumTurnsRemaining == 1 ? strTurnsRemainingSingular : strTurnsRemainingPlural));

	return self;
}

function UIPollPanel SetVotes(int ChoiceIndex, int NumVotes, int NumTotalVotes) {
	if (ChoiceIndex >= m_PollChoices.Length) {
		return self;
	}

	m_PollChoices[ChoiceIndex].SetVotes(NumVotes, NumTotalVotes);
    m_TotalVotes.SetText(NumTotalVotes @ (NumTotalVotes == 1 ? strTotalVotesSingular : strTotalVotesPlural));

	return self;
}

/// <summary>
/// Update the UI for an in-progress poll. Normally this would be handled by the visualization system,
/// but for some reason that kept recentering the camera on the selected unit.
/// </summary>
static function UpdateInProgress(TwitchPollModel Poll) {
    local int Index;
    local int TotalVotes;
    local XComGameState_TwitchEventPoll PollGameState;
    local UIPollPanel PollPanel;
    local PollChoice Choice;

    PollGameState = class'X2TwitchUtils'.static.GetActivePoll();

    if (PollGameState == none) {
        `TILOG("ERROR: game state doesn't contain a Twitch poll, cannot update UI");
        return;
    }

    // This function doesn't handle polls that have ended
    if (PollGameState.RemainingTurns == 0 || Poll.Status != "ACTIVE") {
        return;
    }

    PollPanel = static.GetPanel();

    if (PollPanel == none) {
        `TILOG("Spawning a PollPanel");

        // Poll is being shown for the first time
        PollPanel = `XCOMGAME.Spawn(class'UIPollPanel', `SCREENSTACK.GetFirstInstanceOf(class'UITacticalHud'));
        PollPanel.InitPollPanel(PollGameState.Data.PollGroupTemplateName, Poll, PollGameState.Data.DurationInTurns);
    }
    else {
        if (PollGameState.RemainingTurns > 0) {
            PollPanel.SetTurnsRemaining(PollGameState.RemainingTurns);
        }

        // First iterate to count total votes
        foreach Poll.Choices(Choice) {
            TotalVotes += Choice.NumVotes;
        }

        // Now iterate to update the UI
        for (Index = 0; Index < Poll.Choices.Length; Index++) {
            PollPanel.SetVotes(Index, Poll.Choices[Index].NumVotes, TotalVotes);
        }
    }
}

static function UIPollPanel GetPanel() {
    local UIPollPanel PollPanel;

    foreach `XCOMGAME.AllActors(class'UIPollPanel', PollPanel) {
        break;
    }

    return PollPanel;
}

static function HidePanel() {
    local UIPollPanel PollPanel;

    PollPanel = static.GetPanel();

    if (PollPanel != none) {
        PollPanel.Remove();
        PollPanel.Destroy();
    }
}

// ------------------------------------
// Private functions
// ------------------------------------

private function SetChoices(array<PollChoice> Choices) {
	local UIPollChoice PollChoice;
	local int Index;
	local int TotalHeight;

	TotalHeight = HeaderHeight + SubtitleHeight + 2 * SubtitlePadding + 2 * Padding;

	for (Index = 0; Index < Choices.Length; Index++) {
		if (Index < m_PollChoices.Length && m_PollChoices[Index] != none) {
			PollChoice = m_PollChoices[Index];
		}
		else {
			PollChoice = Spawn(class'UIPollChoice', self);
			PollChoice.InitPollChoice(Index + 1, '', , 2 * HorizontalPadding, , self.width - 2 * Padding, , OnChoiceSizeRealized);
		}

		PollChoice.SetText(Choices[Index].Title);
		PollChoice.SetY(HeaderHeight + SubtitleHeight + 2 * SubtitlePadding + Index * PollChoice.GetTextHeight() + Index * InterChoicePadding);
		PollChoice.SetVotes(0, 0);

		TotalHeight += PollChoice.GetTextHeight() + InterChoicePadding;

		m_PollChoices[Index] = PollChoice;
	}

	SetHeight(TotalHeight);
	m_bgBox.SetHeight(TotalHeight);
	m_TimeRemaining.SetY(self.Height - SubtitleHeight - BottomPadding);
	m_TotalVotes.SetY(self.Height - SubtitleHeight - BottomPadding);
}

private function OnChoiceSizeRealized() {
    local int MaxChoiceWidth;
	local UIPollChoice PollChoice;

    // Find the widest choice
    foreach m_PollChoices(PollChoice) {
        if (PollChoice.Width > MaxChoiceWidth) {
            MaxChoiceWidth = PollChoice.Width;
        }
    }

    // Now make them all that width for consistency
    foreach m_PollChoices(PollChoice) {
        PollChoice.SetChoiceWidth(MaxChoiceWidth);
    }

    // TODO: size the container as well
    //SetWidth(MaxChoiceWidth + 2 * HorizontalPadding);
	m_bgBox.SetWidth(Width);
}

private function OnTextSizeRealized() {
    m_TimeRemaining.SetX(self.Width - Padding - m_TimeRemaining.Width);
}

defaultproperties
{
    BottomPadding = 4
	HeaderHeight = 28
    HorizontalPadding = 8
	InterChoicePadding = 3
	Padding = 16
	SubtitleHeight = 28
	SubtitlePadding = 8
}