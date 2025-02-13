class TwitchDataSetUtils extends Object;

/// <summary>
/// Generates templates for a given class based on their specification in config.
/// </summary>
static function array<X2DataTemplate> CreateTemplatesFromConfig(class<X2DataTemplate> kClass) {
    local array<string> Parts, ConfigSectionNames;
    local array<X2DataTemplate> Templates;
    local X2DataTemplate Template;
    local string TemplateName;
    local int I;

    GetPerObjectConfigSections(kClass, ConfigSectionNames, /* ObjectOuter */ , /* MaxResults */ 4096);

    for (I = 0; I < ConfigSectionNames.Length; I++)
    {
        Parts = SplitString(ConfigSectionNames[I], " ", /* bCullEmpty */ true);

        if (Parts.Length != 2)
        {
            `TILOG("WARNING: config section with header '" $ ConfigSectionNames[I] $ "' is in an invalid format and will be ignored");
            continue;
        }

        TemplateName = Parts[0];

        Template = new(None, TemplateName) kClass;
        Template.SetTemplateName(name(TemplateName));

        Templates.AddItem(Template);
    }

    `TILOG("Created " $ Templates.Length $ " templates from config of type " $ kClass.Name);

    return Templates;
}