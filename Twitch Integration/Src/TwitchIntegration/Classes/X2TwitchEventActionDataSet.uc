class X2TwitchEventActionDataSet extends X2DataSet
	config(TwitchActions);

var private array< Class<X2TwitchEventActionTemplate> > TemplateClasses;

static function array<X2DataTemplate> CreateTemplates()
{
    local int I, J;
    local array<X2DataTemplate> AllTemplates, NewTemplates;

    for (I = 0; I < default.TemplateClasses.Length; I++) {
        NewTemplates = class'TwitchDataSetUtils'.static.CreateTemplatesFromConfig(default.TemplateClasses[I]);

        for (J = 0; J < NewTemplates.Length; J++) {
            AllTemplates.AddItem(NewTemplates[J]);
        }
    }

    return AllTemplates;
}

defaultproperties
{
    TemplateClasses.Add(class'X2TwitchEventActionTemplate_ActivateAbility')
    TemplateClasses.Add(class'X2TwitchEventActionTemplate_CombineActions')
    TemplateClasses.Add(class'X2TwitchEventActionTemplate_ModifyActionPoints')
    TemplateClasses.Add(class'X2TwitchEventActionTemplate_ModifyAmmo')
    TemplateClasses.Add(class'X2TwitchEventActionTemplate_RollTheDice')
    TemplateClasses.Add(class'X2TwitchEventActionTemplate_SpawnUnits')
    TemplateClasses.Add(class'X2TwitchEventActionTemplate_TimeoutUser')
}