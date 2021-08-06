class TextUtilities_Twitch extends Object;

static function string SanitizeText(string Text) {
	local string SanitizedText;
	SanitizedText = Repl(Text, "<", "&lt;");
	SanitizedText = Repl(SanitizedText, ">", "&gt;");
	return SanitizedText;
}