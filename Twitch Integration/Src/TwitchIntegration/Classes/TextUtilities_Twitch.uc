class TextUtilities_Twitch extends Object;

static function string SanitizeText(string Text) {
	local string SanitizedText;
	SanitizedText = Repl(Text, "<", "&lt;");
	SanitizedText = Repl(SanitizedText, ">", "&gt;");
	return SanitizedText;
}

static function string UrlEncode(string Text) {
    local string EncodedText;

    EncodedText = Text;

    EncodedText = Repl(EncodedText, "%",  "%25"); // has to happen first!
    EncodedText = Repl(EncodedText, " ",  "%20");
    EncodedText = Repl(EncodedText, "!",  "%21");
    EncodedText = Repl(EncodedText, "\"", "%22");
    EncodedText = Repl(EncodedText, "#",  "%23");
    EncodedText = Repl(EncodedText, "$",  "%24");
    EncodedText = Repl(EncodedText, "&",  "%26");
    EncodedText = Repl(EncodedText, "'",  "%27");
    EncodedText = Repl(EncodedText, "(",  "%28");
    EncodedText = Repl(EncodedText, ")",  "%29");
    EncodedText = Repl(EncodedText, "*",  "%2A");
    EncodedText = Repl(EncodedText, "+",  "%2B");
    EncodedText = Repl(EncodedText, ",",  "%2C");
    EncodedText = Repl(EncodedText, "-",  "%2D");
    EncodedText = Repl(EncodedText, ".",  "%2E");
    EncodedText = Repl(EncodedText, "/",  "%2F");
    EncodedText = Repl(EncodedText, "`",  "%30");
    EncodedText = Repl(EncodedText, ":",  "%3A");
    EncodedText = Repl(EncodedText, ";",  "%3B");
    EncodedText = Repl(EncodedText, "=",  "%3D");
    EncodedText = Repl(EncodedText, "?",  "%3F");
    EncodedText = Repl(EncodedText, "@",  "%40");
    EncodedText = Repl(EncodedText, "[",  "%5B");
    EncodedText = Repl(EncodedText, "]",  "%5D");

    return EncodedText;
}