/// <summary>
/// Abstracts functionality for loading emote images in the game. Emotes are expected to be placed in a specific location which is used by
/// XCOM 2's Photobooth functionality. This is then piggybacked to load the images as if they were user-taken photos, which makes them
/// available for use by UI elements.
///
/// This method is capable of loading images which did not exist when the game was started, so if emote images are placed in the correct
/// location by a third-party program, they can be dynamically loaded. Note that if an image is loaded, and then the underlying file is
/// deleted externally, the texture will remain cached within the photo manager. Similarly, loaded images are not updated if the underlying
/// file changes. Cached entries are not modified until the game is restarted.
/// </summary>
/// <remarks>Credit to bountygiver for identifying that X2PhotoBooth_PhotoManager could be used to import arbitrary textures at runtime.</remarks>
class TwitchEmoteManager extends Object
    config(Twitch__ShouldNotExist);

// Campaign ID used when registering images with the photo manager
const CAMPAIGN_ID = 123456789;
const EMOTE_HEIGHT = 28;
const EMOTE_WIDTH = 28;
const IMAGE_PATH = "..\\..\\XComGame\\Photobooth\\Campaign_123456789\\UserPhotos";

struct EmoteCacheEntry {
    var int PosterIndex; // Poster index according to X2PhotoBooth_PhotoManager
    var string EmoteCode;
};

var private config array<EmoteCacheEntry> EmoteCache;
var private config bool m_bInitialized;

static function Initialize() {
    local X2PhotoBooth_PhotoManager PhotoMgr;
    local EmoteCacheEntry CacheEntry;
    local int CampaignIndex, PosterIndex;

    if (default.m_bInitialized) {
        return;
    }

    default.m_bInitialized = true;

    // Pre-populate the emote cache
    PhotoMgr = `XENGINE.m_kPhotoManager;
    CampaignIndex = PhotoMgr.m_PhotoDatabase.Find('CampaignID', CAMPAIGN_ID);

    if (CampaignIndex != INDEX_NONE) {
        for (PosterIndex = 0; PosterIndex < PhotoMgr.m_PhotoDatabase[CampaignIndex].Posters.Length; PosterIndex++) {
            CacheEntry.PosterIndex = PosterIndex;
            CacheEntry.EmoteCode = ConvertFileNameToEmoteCode(PhotoMgr.m_PhotoDatabase[CampaignIndex].Posters[PosterIndex].PhotoFilename);
            default.EmoteCache.AddItem(CacheEntry);

            `TILOG("Mapped photo file \"" $ PhotoMgr.m_PhotoDatabase[CampaignIndex].Posters[PosterIndex].PhotoFilename $ "\" to emote code " $ CacheEntry.EmoteCode);
        }
    }
}

static function string GetEmotePath(string EmoteCode) {
    local int CacheIndex;

    CacheIndex = default.EmoteCache.Find('EmoteCode', EmoteCode);

    if (CacheIndex != INDEX_NONE) {
        return GetPosterObjectPath(default.EmoteCache[CacheIndex].PosterIndex);
    }

    `TILOG("WARNING: emote " $ EmoteCode $ " is not registered and will not be looked up");
    return "";
}

static function RegisterEmote(string EmoteCode) {
    local EmoteCacheEntry CacheEntry;
    local array<Color> PixelData;
    local array<int> ObjectIDs;
    local string FileName;
    local int PosterIndex;

    // Check if the emote is already registered, or else the poster database will grow without bound
    if (default.EmoteCache.Find('EmoteCode', EmoteCode) != INDEX_NONE) {
        return;
    }

    PixelData.Length = 0;
    ObjectIDs.Length = 0;

    FileName = GetEmoteFileName(EmoteCode);
    `XENGINE.m_kPhotoManager.AddPosterToDatabase(FileName, CAMPAIGN_ID, ObjectIDs, ePDT_User, EMOTE_WIDTH, EMOTE_HEIGHT, PixelData);

    PosterIndex = FindPosterIndexFromFileName(FileName);

    if (PosterIndex != INDEX_NONE) {
        CacheEntry.PosterIndex = PosterIndex;
        CacheEntry.EmoteCode = EmoteCode;

        default.EmoteCache.AddItem(CacheEntry);
    }
}

private static function string ConvertFileNameToEmoteCode(string FileName) {
    local string EmoteCode;

    EmoteCode = Repl(FileName, IMAGE_PATH $ "\\TwitchEmote_", "");
    EmoteCode = Repl(EmoteCode, ".png", "");

    return EmoteCode;
}

private static function int FindPosterIndexFromFileName(string FileName) {
    local int CampaignIndex, PosterIndex;
    local X2PhotoBooth_PhotoManager PhotoMgr;

    PhotoMgr = `XENGINE.m_kPhotoManager;
    CampaignIndex = PhotoMgr.m_PhotoDatabase.Find('CampaignID', CAMPAIGN_ID);

    if (CampaignIndex != INDEX_NONE) {
        // We're probably in this function because we just registered a new emote, which will be near the end of the array,
        // so iterate backwards to reduce how many expensive string comparisons we have to do
        for (PosterIndex = PhotoMgr.m_PhotoDatabase[CampaignIndex].Posters.Length - 1; PosterIndex >= 0 ; PosterIndex--) {
            if (PhotoMgr.m_PhotoDatabase[CampaignIndex].Posters[PosterIndex].PhotoFilename == FileName) {
                `TILOG("Found file name " $ FileName $ " at index " $ PosterIndex);
                return PosterIndex;
            }
        }
    }

    `TILOG("Did not find file name " $ FileName $ " in photo manager");
    return INDEX_NONE;
}

private static function string GetEmoteFileName(string EmoteCode) {
    return IMAGE_PATH $ "\\TwitchEmote_" $ EmoteCode $ ".png";
}

private static function string GetPosterObjectPath(int PosterIndex) {
    local Texture2D Tex;

    Tex = `XENGINE.m_kPhotoManager.GetPosterTexture(CAMPAIGN_ID, PosterIndex);

    if (Tex == none) {
        return "";
    }

    return class'UIUtilities_Image'.static.ValidateImagePath(PathName(Tex));
}