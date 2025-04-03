class X2TwitchChatCommandTemplateManager extends X2DataTemplateManager;

static function X2TwitchChatCommandTemplateManager GetChatCommandTemplateManager() {
    return X2TwitchChatCommandTemplateManager(class'Engine'.static.GetTemplateManager(class'X2TwitchChatCommandTemplateManager'));
}

function X2TwitchChatCommandTemplate FindChatCommandTemplate(name TemplateName) {
    return X2TwitchChatCommandTemplate(FindDataTemplate(TemplateName));
}

function X2TwitchChatCommandTemplate GetChatCommandTemplateForAlias(string CommandAlias) {
    local X2DataTemplate Template;
    local X2TwitchChatCommandTemplate ChatCommandTemplate;

    foreach IterateTemplates(Template) {
        ChatCommandTemplate = X2TwitchChatCommandTemplate(Template);

        if (ChatCommandTemplate.CommandAliases.Find(CommandAlias) != INDEX_NONE) {
            return ChatCommandTemplate;
        }
    }

    return none;
}

function array<X2TwitchChatCommandTemplate> GetAllChatCommandTemplates() {
    local X2DataTemplate Template;
    local array<X2TwitchChatCommandTemplate> Templates;

    foreach IterateTemplates(Template) {
        Templates.AddItem(X2TwitchChatCommandTemplate(Template));
    }

    return Templates;
}

defaultproperties
{
    TemplateDefinitionClass=class'X2TwitchChatCommandDataSet'
    ManagedTemplateClass=class'X2TwitchChatCommandTemplate'
}