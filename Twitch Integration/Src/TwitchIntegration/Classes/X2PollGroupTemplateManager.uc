class X2PollGroupTemplateManager extends X2DataTemplateManager;

static function X2PollGroupTemplateManager GetPollGroupTemplateManager()
{
    return X2PollGroupTemplateManager(class'Engine'.static.GetTemplateManager(class'X2PollGroupTemplateManager'));
}

function X2PollGroupTemplate GetPollGroupTemplate(name TemplateName)
{
    return X2PollGroupTemplate(FindDataTemplate(TemplateName));
}

function array<X2PollGroupTemplate> GetEligiblePollGroupTemplates() {
    local X2DataTemplate Template;
	local XComGameState_HeadquartersAlien AlienHQ;
    local X2PollGroupTemplate PollGroupTemplate;
    local array<X2PollGroupTemplate> ValidPollGroups;
    local bool IsStrategyLayer, IsTacticalLayer;
    local int ForceLevel;

    IsStrategyLayer = `TI_IS_STRAT_GAME;
    IsTacticalLayer = `TI_IS_TAC_GAME;

    AlienHQ = XComGameState_HeadquartersAlien(`XCOMHISTORY.GetSingleGameStateObjectForClass(class'XComGameState_HeadquartersAlien'));

    if (AlienHQ == none) {
        `TILOG("WARNING: couldn't find an AlienHQ object in X2PollGroupTemplateManager!");
        return ValidPollGroups;
    }

    ForceLevel = AlienHQ.GetForceLevel();

    foreach IterateTemplates(Template) {
        PollGroupTemplate = X2PollGroupTemplate(Template);

        if (PollGroupTemplate.IsSelectable(IsStrategyLayer, IsTacticalLayer, ForceLevel)) {
            ValidPollGroups.AddItem(PollGroupTemplate);
        }
    }

    return ValidPollGroups;
}

defaultproperties
{
    TemplateDefinitionClass=class'X2PollGroupDataSet'
    ManagedTemplateClass=class'X2PollGroupTemplate'
}