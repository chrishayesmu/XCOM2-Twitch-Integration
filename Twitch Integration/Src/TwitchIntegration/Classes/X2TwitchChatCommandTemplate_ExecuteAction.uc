class X2TwitchChatCommandTemplate_ExecuteAction extends X2TwitchChatCommandTemplate;

var config array<name> Actions;

function bool Invoke(string CommandAlias, string Body, array<EmoteData> Emotes, string MessageId, TwitchChatter Viewer) {
    local XComGameState_Unit InvokingUnit;
    local X2TwitchEventActionTemplateManager TemplateMgr;
    local array<X2TwitchEventActionTemplate> ValidTemplates;
    local X2TwitchEventActionTemplate ActionTemplate;
    local name Action;

    TemplateMgr = class'X2TwitchEventActionTemplateManager'.static.GetTwitchEventActionTemplateManager();
    InvokingUnit = class'X2TwitchUtils'.static.FindUnitOwnedByViewer(Viewer.Login);

    foreach Actions(Action) {
        ActionTemplate = TemplateMgr.FindTwitchEventActionTemplate(Action);

        if (ActionTemplate == none) {
            `TILOG("ERROR: couldn't find an action template called " $ Action);
            continue;
        }

        if (ActionTemplate.IsValid(InvokingUnit)) {
            ValidTemplates.AddItem(ActionTemplate);
        }
    }

    if (ValidTemplates.Length == 0) {
        return false;
    }

    if (!super.Invoke(CommandAlias, Body, Emotes, MessageId, Viewer)) {
        return false;
    }

    foreach ValidTemplates(ActionTemplate) {
        ActionTemplate.Apply(InvokingUnit);
    }

    return true;
}