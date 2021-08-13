// This class isn't actually an event listener, but you have to be one of the known subclasses of
// X2DataSet for your CreateTemplates to be called, and this one has the least implications.
class X2PollEvent extends X2EventListener
	config(TwitchEvents)
	dependson(X2PollEventTemplate);

var config array<name> PossiblePollEventNames;

static function array<X2DataTemplate> CreateTemplates()
{
	local array<X2DataTemplate> Templates;
	local X2PollEventTemplate Template;
	local name TemplateName;

	foreach default.PossiblePollEventNames(TemplateName)
	{
		`CREATE_X2TEMPLATE(class'X2PollEventTemplate', Template, TemplateName);
		Templates.AddItem(Template);
	}

	`TILOG("Created " $ Templates.Length $ " X2PollEventTemplates");

	return Templates;
}