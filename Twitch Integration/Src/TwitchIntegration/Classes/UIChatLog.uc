class UIChatLog extends UIPanel config(TwitchChatCommands);

var localized string ClearButtonLabel;

var config bool bShowChatLog;
var config bool bColorMessagesByTeam;
var config bool bColorMessagesSameAsTwitch;    // takes priority over bColorMessagesByTeam
var config bool bShowFullEnemyUnitName;
var config bool bShowFullFriendlyUnitName;
var config float TimeToShowOnMessageReceived;

struct ChatMessage {
    var string Sender;
    var string Body;
};

var private int XPos;

var private UIButton m_ClearButton;
var private UIButton m_ExpandCollapseButton;
var private UITextContainer m_TextContainer;

var private array<ChatMessage> Messages;

function UIChatLog InitChatLog(int InitX, int InitY, int InitWidth, int InitHeight) {
    InitPanel();
    SetPosition(InitX, InitY);
    SetSize(InitWidth, InitHeight);

    m_TextContainer = Spawn(class'UITextContainer', self);
    m_TextContainer.InitTextContainer('', "", InitX, InitY, InitWidth, InitHeight, /* addBG */ true, class'UIUtilities_Controls'.const.MC_X2BackgroundSimple);
    m_TextContainer.SetAlpha(0.8);

    m_ClearButton = Spawn(class'UIButton', self);
    m_ClearButton.InitButton(/* InitName */, ClearButtonLabel, OnClearButtonClicked);
    m_ClearButton.SetAlpha(0.8);
    m_ClearButton.SetPosition(InitX, m_TextContainer.Y + m_TextContainer.Height + 8);

    // TODO: get an actual icon on this button somehow
    m_ExpandCollapseButton = Spawn(class'UIButton', self);
    m_ExpandCollapseButton.ResizeToText = false;
    m_ExpandCollapseButton.InitButton(/* InitName */, "&lt;", OnExpandCollapseButtonClicked);
    m_ExpandCollapseButton.SetAlpha(0.8);
    m_ExpandCollapseButton.SetPosition(InitX + m_TextContainer.Width + 3, m_TextContainer.Y);
    m_ExpandCollapseButton.SetSize(28, 28);

    Collapse();

    return self;
}

function AddMessage(string Sender, string Body, optional XComGameState_Unit Unit) {
    local ChatMessage Message;

    Message.Body = class'TextUtilities_Twitch'.static.SanitizeText(Body);
    Message.Sender = FormatSenderName(Sender, Unit);

    Messages.AddItem(Message);

    // TODO: don't expand if it was manually collapsed; make expand button flash instead
    UpdateUI();
    Expand();
    ClearTimer('Collapse');

    if (TimeToShowOnMessageReceived > 0) {
        SetTimer(TimeToShowOnMessageReceived, /* inBLoop */ false, 'Collapse');
    }
}

function Collapse() {
    XPos = X;

    // animate off screen
    AnimateX(-m_TextContainer.width);
    m_ExpandCollapseButton.SetText("&gt;");
}

function Expand() {
    // animate back on screen
    AnimateX(XPos);
    m_ExpandCollapseButton.SetText("&lt;");
}

function bool IsCollapsed() {
    return X < 0;
}

private function string FormatSenderName(string Sender, optional XComGameState_Unit Unit) {
    local string SenderColor;

    if (Unit == none) {
        return Sender;
    }

    if (bShowFullEnemyUnitName && (Unit.GetTeam() == eTeam_Alien || Unit.GetTeam() == eTeam_TheLost)) {
        Sender = Sender $ " " $ Unit.GetLastName(); // original unit name is kept in the last name
    }

    // TODO add full name for friendly units

    if (bColorMessagesByTeam) {
        switch (Unit.GetTeam()) {
            case eTeam_Alien:
                SenderColor = class'UIUtilities_Colors'.const.BAD_HTML_COLOR;
                break;
            case eTeam_TheLost:
                SenderColor = class'UIUtilities_Colors'.const.THELOST_HTML_COLOR;
                break;
            default:
                SenderColor = class'UIUtilities_Colors'.const.NORMAL_HTML_COLOR;
                break;
        }

        Sender = "<font color='#" $ SenderColor $ "'>" $ Sender $ "</font>";
    }

    return Sender;
}

private function OnClearButtonClicked(UIButton Button) {
    Messages.Length = 0;
    UpdateUI();
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

private function UpdateUI() {
    local string FullChat;
    local string FormattedMessage;
    local ChatMessage Message;

    foreach Messages(Message) {
        FormattedMessage = Message.Sender $ ": " $ Message.Body;

        if (FullChat == "") {
            FulLChat = FormattedMessage;
        }
        else {
            FullChat = FullChat $ "\n" $ FormattedMessage;
        }
    }

    // Individual messages can wrap but UITextContainer doesn't realize that when scrolling, so
    // we add a couple of newlines to move it along
    FullChat = FullChat $ "\n\n";

    m_TextContainer.SetHTMLText(FullChat);
    m_TextContainer.Scrollbar.SetThumbAtPercent(1.0);
}