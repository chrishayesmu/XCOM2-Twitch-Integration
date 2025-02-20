class X2TwitchEventActionDataSet extends X2DataSet
	config(TwitchActions);

struct ActionSpecifier {
    var name ActionName;
    var name ClassName;
};

var config array<ActionSpecifier> ActionSpecifiers;

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

/*
    local ActionSpecifier Specifier;
    local class TemplateClass;
	local array<X2DataTemplate> Templates;
	local X2TwitchEventActionTemplate Template;

	foreach default.ActionSpecifiers(Specifier)
	{
        `TILOG("Creating action " $ Specifier.ActionName $ " with class " $ Specifier.ClassName);
        TemplateClass = class'Engine'.static.FindClassType(String(Specifier.ClassName));

        if (TemplateClass != none) {
            // The `CREATE_X2TEMPLATE macro doesn't work with dynamically-specified classes, so the contents are copied here and modified
            Template = X2TwitchEventActionTemplate(new(None, string(Specifier.ActionName)) TemplateClass);
            Template.SetTemplateName(Specifier.ActionName);

            Templates.AddItem(Template);
        }
        else {
            `TILOG("ERROR: Specified class name could not be loaded!");
        }
	}

	`TILOG("Created " $ Templates.Length $ " X2TwitchEventActionTemplates from " $ default.ActionSpecifiers.Length $ " specifiers");

	return Templates;
*/
}

defaultproperties
{
    TemplateClasses.Add(class'X2TwitchEventActionTemplate_ActivateAbility')
    TemplateClasses.Add(class'X2TwitchEventActionTemplate_CombineActions')
    TemplateClasses.Add(class'X2TwitchEventActionTemplate_ModifyActionPoints')
    TemplateClasses.Add(class'X2TwitchEventActionTemplate_ModifyAmmo')
    TemplateClasses.Add(class'X2TwitchEventActionTemplate_RollTheDice')
    TemplateClasses.Add(class'X2TwitchEventActionTemplate_SpawnUnits')
}