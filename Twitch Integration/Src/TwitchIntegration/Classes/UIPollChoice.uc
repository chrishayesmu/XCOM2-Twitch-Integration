class UIPollChoice extends UIPanel;

var private bool ShowingResults;
var private int PersonalNumVotes;
var private int TotalNumVotes;
var private bool IsWidthManuallySet;

var UIText m_ChoiceText;
var UIBGBox m_ChoiceTextBg; // fixed background behind the choice
var UIBGBox m_ChoiceTextOutline; // outline around choice; separate element to stack above everything else
var UIBGBox m_ChoiceTextVotesBar; // background that scales with % of votes received

var UIText m_VotePrompt;
var UIBGBox m_VotePromptBg;

var UIText m_VotePercentage;


var private int ElemHeight;
var private int Padding;
var private int VotePercentageTextWidth;
var private int VotePromptBgWidth;

delegate OnSizeRealized();

simulated function UIPollChoice InitPollChoice(int VoteNumber,
                                               optional name InitName,
                                               optional string Text,
                                               optional float InitX, optional float InitY,
                                               optional float InitWidth, optional float InitHeight,
                                               optional delegate<OnSizeRealized> SizeRealizedDelegate,
                                               optional bool bShowResults = false, optional bool bDidWinPoll = false) {
    InitPanel(InitName);
	SetPosition(InitX, InitY);
	SetSize(InitWidth, InitHeight);

    ShowingResults = bShowResults;
    OnSizeRealized = SizeRealizedDelegate;

    // Choice text and background scale with the container, and consume most of the space
	m_ChoiceTextBg = Spawn(class'UIBGBox', self).InitBG('', 0, 0, , ElemHeight, eUIState_Normal);
	m_ChoiceTextBg.SetBGColor("gray");
	m_ChoiceTextBg.SetAlpha(0.5);
    m_ChoiceTextBg.SetOutline(false);

	m_ChoiceTextVotesBar = Spawn(class'UIBGBox', self).InitBG('', 0, 0, , ElemHeight, eUIState_Normal);
	m_ChoiceTextVotesBar.SetBGColor("gray");
	m_ChoiceTextVotesBar.SetColor(class'UIUtilities_Colors'.const.FADED_HTML_COLOR);
	m_ChoiceTextVotesBar.SetAlpha(0.6);
    m_ChoiceTextVotesBar.SetOutline(false);

    // Choice text doesn't get a width or else it'll line wrap
	m_ChoiceText = Spawn(class'UIText', self);
	m_ChoiceText.InitText('', Text, , OnTextSizeRealized);

    m_VotePercentage = Spawn(class'UIText', self);
	m_VotePercentage.InitText('', "100%");

	m_ChoiceTextOutline = Spawn(class'UIBGBox', self).InitBG('', 0, 0, , ElemHeight, eUIState_Normal);
	m_ChoiceTextOutline.SetAlpha(0.9);
    m_ChoiceTextOutline.SetOutline(true, class'UIUtilities_Colors'.const.FADED_HTML_COLOR);

    if (!ShowingResults) {
        m_VotePromptBg = Spawn(class'UIBGBox', self).InitBG('', 0, 0, , ElemHeight, eUIState_Normal).SetBGColor("gray");
        m_VotePromptBg.SetAlpha(0.9);

        m_VotePrompt = Spawn(class'UIText', self);
        m_VotePrompt.InitText('', "!vote " $ VoteNumber);
        m_VotePrompt.SetColor(class'UIUtilities_Colors'.const.FADED_HTML_COLOR);
    }
    else {
        if (bDidWinPoll) {
            // Highlight the winning option
            m_ChoiceText.SetColor(class'UIUtilities_Colors'.const.HILITE_HTML_COLOR);
            m_ChoiceTextOutline.SetColor(class'UIUtilities_Colors'.const.HILITE_HTML_COLOR);
            m_VotePercentage.SetColor(class'UIUtilities_Colors'.const.HILITE_HTML_COLOR);
        }
        else {
            m_ChoiceText.SetColor(class'UIUtilities_Colors'.const.DISABLED_HTML_COLOR);
            m_ChoiceTextOutline.SetColor(class'UIUtilities_Colors'.const.DISABLED_HTML_COLOR);
            m_VotePercentage.SetColor(class'UIUtilities_Colors'.const.DISABLED_HTML_COLOR);
	        m_ChoiceTextVotesBar.SetAlpha(0.4);
        }
    }

	return self;
}

simulated function int GetTextHeight() {
	return m_ChoiceText.Height;
}

simulated function UIPollChoice SetText(string Text) {
	m_ChoiceText.SetText(Text, OnTextSizeRealized);

	return self;
}

simulated function UIPollChoice SetVotes(int personal, int total) {
	local int Percent;

	TotalNumVotes = total;
	PersonalNumVotes = personal;

	Percent = TotalNumVotes > 0 ? Round(100 *  PersonalNumVotes / TotalNumVotes) : 0;

    m_VotePercentage.SetText(class'UIUtilities_Text'.static.AlignRight(Percent $ "%"));

	if (Percent == 0) {
		m_ChoiceTextVotesBar.Hide();
	}
	else {
		m_ChoiceTextVotesBar.Show();
		m_ChoiceTextVotesBar.SetSize(CalculateBarWidth(Percent / 100.0), ElemHeight);
	}

	return self;
}

simulated function SetChoiceWidth(float NewWidth, bool IsManualSet = true) {
    if (IsWidthManuallySet && !IsManualSet) {
        // Don't let automatically realized width override a manual one
        return;
    }

    IsWidthManuallySet = IsManualSet;

    super.SetWidth(NewWidth);

    DoLayout();
}

private simulated function float CalculateBarWidth(float percentage) {
	return m_ChoiceTextBg.Width * percentage;
}

private simulated function DoLayout() {
	local int ChoiceBgWidth;

    // Choice text takes up the whole element in results mode
    ChoiceBgWidth = ShowingResults ? self.Width : self.Width - VotePromptBgWidth - Padding;

    m_ChoiceTextBg.SetSize(ChoiceBgWidth, ElemHeight);
    m_ChoiceTextOutline.SetSize(ChoiceBgWidth, ElemHeight);

    m_ChoiceText.SetX(Padding); // just inset within the BG

    // Current vote percentage is just after choice text, inside the same BG
    m_VotePercentage.SetWidth(VotePercentageTextWidth);
	m_VotePercentage.SetX(m_ChoiceTextBg.Width - VotePercentageTextWidth - Padding);

    SetVotes(PersonalNumVotes, TotalNumVotes); // this does some sizing

    if (!ShowingResults) {
        // Vote prompt follows vote percentage, takes up remaining units of space
        m_VotePromptBg.SetX(m_ChoiceTextBg.X + m_ChoiceTextBg.Width + Padding);
        m_VotePromptBg.SetSize(VotePromptBgWidth, ElemHeight);
        m_VotePrompt.SetX(m_VotePromptBg.X + 5);
    }
}

private simulated function OnTextSizeRealized() {
    local int ChoiceTextBgWidth;
    local int TotalWidth;

    `TILOGCLS("Text size realized; ChoiceText width is " $ m_ChoiceText.Width);
    ChoiceTextBgWidth = m_ChoiceText.Width + 2 * Padding;

    // The choice text's width is dynamic; everything else is static
    TotalWidth = ChoiceTextBgWidth + VotePercentageTextWidth + Padding;

    if (!ShowingResults) {
        TotalWidth += VotePromptBgWidth + Padding;
    }

    SetChoiceWidth(TotalWidth, false);

    if (OnSizeRealized != none) {
        OnSizeRealized();
    }
}

defaultproperties
{
    ElemHeight = 28
    Padding = 8
    VotePercentageTextWidth = 55
    VotePromptBgWidth = 70
}