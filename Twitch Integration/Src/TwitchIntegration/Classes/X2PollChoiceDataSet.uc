class X2PollChoiceDataSet extends X2DataSet;

static function array<X2DataTemplate> CreateTemplates()
{
    return class'TwitchDataSetUtils'.static.CreateTemplatesFromConfig(class'X2PollChoiceTemplate');
}