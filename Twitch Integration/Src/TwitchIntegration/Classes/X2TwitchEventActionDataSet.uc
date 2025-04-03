class X2TwitchEventActionDataSet extends X2DataSet
	config(TwitchActions);

var private config array<string> TemplateClasses;

static function array<X2DataTemplate> CreateTemplates()
{
    local int I, J;
    local array<X2DataTemplate> AllTemplates, NewTemplates;
    local Class<X2TwitchEventActionTemplate> kClass;

    for (I = 0; I < default.TemplateClasses.Length; I++) {
        kClass = Class<X2TwitchEventActionTemplate>(class'Engine'.static.FindClassType(default.TemplateClasses[I]));

        if (kClass == none) {
            `TILOG("ERROR: couldn't load a X2TwitchEventActionTemplate class called " $ default.TemplateClasses[I]);
            continue;
        }

        NewTemplates = class'TwitchDataSetUtils'.static.CreateTemplatesFromConfig(kClass);

        for (J = 0; J < NewTemplates.Length; J++) {
            AllTemplates.AddItem(NewTemplates[J]);
        }
    }

    return AllTemplates;
}