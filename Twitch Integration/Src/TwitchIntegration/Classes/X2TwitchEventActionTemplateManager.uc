class X2TwitchEventActionTemplateManager extends X2DataTemplateManager;

static function X2TwitchEventActionTemplateManager GetTwitchEventActionTemplateManager()
{
    return X2TwitchEventActionTemplateManager(class'Engine'.static.GetTemplateManager(class'X2TwitchEventActionTemplateManager'));
}

final function X2TwitchEventActionTemplate FindTwitchEventActionTemplate(const name DataName)
{
    return X2TwitchEventActionTemplate(FindDataTemplate(DataName));
}

DefaultProperties
{
    TemplateDefinitionClass=class'X2TwitchEventActionDataSet'
    ManagedTemplateClass=class'X2TwitchEventActionTemplate'
}