class UIChatLog extends UIPanel;

struct ChatMessage {
    var string Sender;
    var string Body;
};

var private UITextContainer m_TextContainer;

var private array<ChatMessage> Messages;

// TODO: need a way to hide or minimize the chat log so it isn't taking up a ton of space constantly

function UIChatLog InitChatLog(int InitX, int InitY, int InitWidth, int InitHeight) {
    InitPanel();
    SetPosition(InitX, InitY);
    SetSize(InitWidth, InitHeight);

    m_TextContainer = Spawn(class'UITextContainer', self);
    m_TextContainer.InitTextContainer('', "", InitX, InitY, InitWidth, InitHeight, /* addBG */ true, class'UIUtilities_Controls'.const.MC_X2BackgroundSimple);
    m_TextContainer.SetAlpha(0.8);

    return self;
}

simulated function AddMessage(string Sender, string Body) {
    local ChatMessage Message;

    Message.Body = SanitizeText(Body);
    Message.Sender = Sender;

    // TODO: add configurable filter
    Messages.AddItem(Message);

    UpdateUI();
}

private simulated function string SanitizeText(string Text)
{
	local string SanitizedText;
	SanitizedText = Repl(Text, "<", "&lt;");
	SanitizedText = Repl(SanitizedText, ">", "&gt;");
	return SanitizedText;
}

private simulated function UpdateUI() {
    local string FullChat;
    local string FormattedMessage;
    local ChatMessage Message;

    foreach Messages(Message) {
        // TODO include the full unit name?
        FormattedMessage = "[" $ Message.Sender $ "]: " $ Message.Body;

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
}