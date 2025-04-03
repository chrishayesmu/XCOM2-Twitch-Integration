class X2TwitchChatCommandDataSet extends X2DataSet
    config(TwitchChatCommands);

var private config array<string> TemplateClasses;

static function array<X2DataTemplate> CreateTemplates()
{
    local int I, J;
    local array<X2DataTemplate> AllTemplates, NewTemplates;
    local Class<X2TwitchChatCommandTemplate> kClass;

    for (I = 0; I < default.TemplateClasses.Length; I++) {
        kClass = Class<X2TwitchChatCommandTemplate>(class'Engine'.static.FindClassType(default.TemplateClasses[I]));

        if (kClass == none) {
            `TILOG("ERROR: couldn't load a X2TwitchChatCommandTemplate class called " $ default.TemplateClasses[I]);
            continue;
        }

        NewTemplates = class'TwitchDataSetUtils'.static.CreateTemplatesFromConfig(kClass);

        for (J = 0; J < NewTemplates.Length; J++) {
            AllTemplates.AddItem(NewTemplates[J]);
        }
    }

    AllTemplates.AddItem(XEmote());
    AllTemplates.AddItem(XSay());

    return AllTemplates;
}

static function X2TwitchChatCommandTemplate XEmote() {
	local X2TwitchChatCommandTemplate Template;

	`CREATE_X2TEMPLATE(class'X2TwitchChatCommandTemplate_XEmote', Template, 'TwitchChatCommand_XEmote');

    return Template;
}

static function X2TwitchChatCommandTemplate XSay() {
	local X2TwitchChatCommandTemplate Template;

	`CREATE_X2TEMPLATE(class'X2TwitchChatCommandTemplate_XSay', Template, 'TwitchChatCommand_XSay');

    return Template;
}