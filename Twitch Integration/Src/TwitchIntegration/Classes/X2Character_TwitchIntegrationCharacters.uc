class X2Character_TwitchintegrationCharacters extends X2Character;

static function array<X2DataTemplate> CreateTemplates()
{
	local array<X2DataTemplate> Templates;

    Templates.AddItem(CreateSpeakerTemplate('Twitch_Chat', "Twitch_Chat", "img:///UILibrary_Common.Head_Empty"));

    return Templates;
}

static function X2CharacterTemplate CreateSpeakerTemplate(Name CharacterName, optional string CharacterSpeakerName = "", optional string CharacterSpeakerPortrait = "", optional EGender Gender = eGender_Female)
{
	local X2CharacterTemplate CharTemplate;

	`CREATE_X2CHARACTER_TEMPLATE(CharTemplate, CharacterName);

	CharTemplate.CharacterGroupName = 'Speaker';
    CharTemplate.strCharacterName = CharacterSpeakerName;
	CharTemplate.SpeakerPortrait = CharacterSpeakerPortrait;
	CharTemplate.DefaultAppearance.iGender = int(Gender);

	CharTemplate.bShouldCreateDifficultyVariants = false;

	return CharTemplate;
}