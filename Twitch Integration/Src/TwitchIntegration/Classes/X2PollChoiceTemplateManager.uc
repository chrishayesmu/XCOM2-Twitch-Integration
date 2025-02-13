class X2PollChoiceTemplateManager extends X2DataTemplateManager;

static function X2PollChoiceTemplateManager GetPollChoiceTemplateManager()
{
    return X2PollChoiceTemplateManager(class'Engine'.static.GetTemplateManager(class'X2PollChoiceTemplateManager'));
}

function X2PollChoiceTemplate GetPollChoiceTemplate(name TemplateName)
{
    return X2PollChoiceTemplate(FindDataTemplate(TemplateName));
}

defaultproperties
{
    TemplateDefinitionClass=class'X2PollChoiceDataSet'
    ManagedTemplateClass=class'X2PollChoiceTemplate'
}