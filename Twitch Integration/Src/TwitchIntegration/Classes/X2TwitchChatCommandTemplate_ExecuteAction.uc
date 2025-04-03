class X2TwitchChatCommandTemplate_ExecuteAction extends X2TwitchChatCommandTemplate;

var config array<name> Actions;

function bool Invoke(string CommandAlias, string Body, array<EmoteData> Emotes, string MessageId, TwitchChatter Viewer) {
    local XComGameState_Unit InvokingUnit;
    local X2TwitchEventActionTemplateManager TemplateMgr;
    local X2TwitchEventActionTemplate ActionTemplate;
    local name Action;
    local bool HadValidAction;

    if (!super.Invoke(CommandAlias, Body, Emotes, MessageId, Viewer)) {
        return false;
    }

    TemplateMgr = class'X2TwitchEventActionTemplateManager'.static.GetTwitchEventActionTemplateManager();
    InvokingUnit = class'X2TwitchUtils'.static.FindUnitOwnedByViewer(Viewer.Login);

    foreach Actions(Action) {
        ActionTemplate = TemplateMgr.FindTwitchEventActionTemplate(Action);

        if (ActionTemplate == none) {
            `TILOG("ERROR: couldn't find an action template called " $ Action);
            continue;
        }

        if (ActionTemplate.IsValid(InvokingUnit)) {
            HadValidAction = true;
            ActionTemplate.Apply(InvokingUnit);
        }
    }

    return HadValidAction;
}