class UIChatLog extends UIPanel
    config(TwitchChatCommands)
    dependson(TwitchChatTcpLink, TwitchIntegrationConfig, UIScreenListener_TwitchUsernameInjector);

const MaxMessagesStored = 100;

var localized string ClearButtonLabel;

var config float TimeToShowOnMessageReceived;
var config(TwitchUI) TLabelPosition Position;
var config(TwitchUI) TLabelPosition Size;
var config(TwitchUI) float Opacity;

struct ChatMessage {
    var string Sender;
    var string Body;
    var string MsgId;
    var XComGameState_Unit Unit;

    var bool bUnitWasDead; // Whether the unit was dead when this message was sent
    var ETeam UnitTeam;
};

var private int XPos;
var private bool bUnreadMessages;

var private UIButton m_ClearButton;
var private UIButton m_ExpandCollapseButton;
var private UITextContainer m_TextContainer;

var private array<ChatMessage> Messages;

function UIChatLog InitChatLog() {
    local Object ThisObj;
    InitPanel();
    SetPosition(Position.X, Position.Y);
    SetSize(Size.X, Size.Y);

    m_TextContainer = Spawn(class'UITextContainer', self);
    m_TextContainer.InitTextContainer('', "", Position.X, Position.Y, Size.X, Size.Y, /* addBG */ true, class'UIUtilities_Controls'.const.MC_X2BackgroundSimple);
    m_TextContainer.SetAlpha(Opacity);

    m_ClearButton = Spawn(class'UIButton', self);
    m_ClearButton.InitButton(/* InitName */, ClearButtonLabel, OnClearButtonClicked);
    m_ClearButton.SetAlpha(Opacity);
    m_ClearButton.SetPosition(Position.X, m_TextContainer.Y + m_TextContainer.Height + 8);

    // TODO: get an actual icon on this button somehow
    m_ExpandCollapseButton = Spawn(class'UIButton', self);
    m_ExpandCollapseButton.ResizeToText = false;
    m_ExpandCollapseButton.InitButton(/* InitName */, "&lt;", OnExpandCollapseButtonClicked);
    m_ExpandCollapseButton.SetAlpha(Opacity);
    m_ExpandCollapseButton.SetPosition(Position.X + m_TextContainer.Width + 3, m_TextContainer.Y);
    m_ExpandCollapseButton.SetSize(28, 28);

    ThisObj = self;
	`XEVENTMGR.RegisterForEvent(ThisObj, 'TwitchChatMessageDeleted', OnMessageDeleted, ELD_Immediate);
	`XEVENTMGR.RegisterForEvent(ThisObj, 'TwitchModConfigSaved', OnModConfigChanged, ELD_Immediate);

    Expand();

    if (!`TI_CFG(bShowChatLog)) {
        Hide();
    }

    return self;
}

function AddMessage(string Sender, string Body, optional XComGameState_Unit Unit, optional string MsgId) {
    local ChatMessage Message;

    // Do formatting on display, not storage, in case user config changes at runtime
    Message.Body = Body;
    Message.Sender = Sender;
    Message.Unit = Unit;
    Message.MsgId = MsgId;

    if (Unit != none) {
        Message.bUnitWasDead = Unit.IsDead();
        Message.UnitTeam = Unit.GetTeam();
    }

    `TILOG("Adding message to chat log. Unit is none: " $ (Unit == none) $ "; " $ `SHOWVAR(Message.bUnitWasDead) $ "; " $ `SHOWVAR(Message.UnitTeam));

    Messages.AddItem(Message);

    while (Messages.Length > MaxMessagesStored)
    {
        Messages.Remove(0, 1);
    }

    // TODO: don't expand if it was manually collapsed; make expand button flash instead
    UpdateUI();

    if (IsCollapsed())
    {
        bUnreadMessages = true;
    }

    if (TimeToShowOnMessageReceived > 0) {
        ClearTimer('Collapse');
        SetTimer(TimeToShowOnMessageReceived, /* inBLoop */ false, 'Collapse');
    }
}

function EventListenerReturn OnMessageDeleted(Object EventData, Object EventSource, XComGameState GameState, Name Event, Object CallbackData) {
    local int Index;
    local XComLWTuple Tuple;

    Tuple = XComLWTuple(EventData);
    Index = Messages.Find('MsgId', Tuple.Data[0].s);

    if (Index != INDEX_NONE) {
        Messages.Remove(Index, 1);
        UpdateUI();
    }

    return ELR_NoInterrupt;
}

function Collapse() {
    XPos = X;

    // animate off screen
    // TODO: make the button flash/pulse
    AnimateX(-m_TextContainer.width);
    m_ExpandCollapseButton.SetText("&gt;");
}

function Expand() {
    // animate back on screen
    AnimateX(XPos);
    m_ExpandCollapseButton.SetText("&lt;");
    bUnreadMessages = false;
}

function bool IsCollapsed() {
    return X < 0;
}

private function string FormatMessageBody(ChatMessage Message) {
    local string Body;

    Body = class'TextUtilities_Twitch'.static.SanitizeText(Message.Body);

    if (Message.Unit == none) {
        return Body;
    }

    if (Message.bUnitWasDead && `TI_CFG(bFormatDeadMessages)) {
        Body = class'UIUtilities_Twitch'.static.FormatDeadMessage(Body);
    }

    return Body;
}

private function string FormatSenderName(ChatMessage Message) {
    local bool bIsFriendlyUnit;
    local string SenderColor, Sender;
    local eTwitchConfig_ChatLogColorScheme ColorScheme;
    local eTwitchConfig_ChatLogNameFormat NameFormat;
    local TwitchViewer Viewer;
    local XComGameState_TwitchObjectOwnership Ownership;

    Sender = Message.Sender;

    if (Message.Unit == none) {
        return Sender;
    }

    bIsFriendlyUnit = Message.UnitTeam == eTeam_XCom;
    NameFormat = bIsFriendlyUnit ? `TI_CFG(ChatLogFriendlyNameFormat) : `TI_CFG(ChatLogEnemyNameFormat);
    Ownership = class'XComGameState_TwitchObjectOwnership'.static.FindForObject(Message.Unit.GetReference().ObjectID);

    // Only use full name for friendly units, or visible enemy units
    if (NameFormat == ETC_UnitNameOnly && (bIsFriendlyUnit || class'X2TacticalVisibilityHelpers'.static.CanXComSquadSeeTarget(Message.Unit.ObjectID))) {
        Sender = Message.Unit.GetFullName();
    }

    ColorScheme = `TI_CFG(ChatLogColorScheme);

    if (ColorScheme == ETC_TwitchColors) {
        if (`TISTATEMGR.TwitchChatConn.GetViewer(Ownership.TwitchLogin, Viewer) != INDEX_NONE) {
            SenderColor = Mid(Viewer.ChatColor, 1); // strip leading # from color
        }
    }
    else if (ColorScheme == ETC_TeamColors) {
        switch (Message.UnitTeam) {
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
    }

    // bFormatDeadMessages takes priority over other color options
    if (`TI_CFG(bFormatDeadMessages) && Message.bUnitWasDead) {
        SenderColor = class'UIUtilities_Colors'.const.DISABLED_HTML_COLOR;
    }

    if (SenderColor != "") {
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

private function EventListenerReturn OnModConfigChanged(Object EventData, Object EventSource, XComGameState GameState, Name Event, Object CallbackData) {
    // Re-render all messages in case we've changed our display settings
    UpdateUI();

    return ELR_NoInterrupt;
}

private function UpdateUI() {
    local string FullChat;
    local string FormattedMessage;
    local ChatMessage Message;

    if (!`TI_CFG(bShowChatLog)) {
        Hide();
        return;
    }

    Show();

    foreach Messages(Message) {
        FormattedMessage = FormatSenderName(Message) $ ": " $ FormatMessageBody(Message);

        if (FullChat == "") {
            FullChat = FormattedMessage;
        }
        else {
            FullChat = FullChat $ "\n" $ FormattedMessage;
        }
    }

    // Individual messages can wrap but UITextContainer doesn't realize that when scrolling, so
    // we add a couple of newlines to move it along
    FullChat = FullChat $ "\n\n";

    m_TextContainer.SetHTMLText(FullChat);

    // TODO don't scroll if the player is using the scroll bar
    m_TextContainer.Scrollbar.SetThumbAtPercent(0.99);
    SetTimer(0.1, /* inBLoop */ false, 'ScrollToBottom');
}

private function ScrollToBottom()
{
    m_TextContainer.Scrollbar.SetThumbAtPercent(1.0);
}