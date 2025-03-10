class TwitchChatCommand_XSay extends TwitchChatCommand
    dependson(TwitchStateManager);

struct TNarrativeQueueItem {
    var XComGameState_TwitchXSay GameState;
    var XComNarrativeMoment NarrativeMoment;
    var bool bUnitWasDead;
};

struct TUnitContentConfig {
    var name CharacterGroupName;
    var string CommlinkImage;
    var array<string> CommlinkSoundsFemale;
    var array<string> CommlinkSoundsMale;
};

struct TViewerXSayOverride {
    var string ViewerLogin;
    var string CommLinkImageOverride;
    var array<string> Sounds;
    var bool bCanAlwaysSpeakOnStrat;
    var bool bCanAlwaysSpeakOnTac;
};

var config bool bRequireUnitInLOS;
var config bool bShowToast;
var config bool bShowFlyover;
var config float LookAtDuration;
var config array<TUnitContentConfig> UnitContentCfg;
var config array<TViewerXSayOverride> ViewerOverrides;

const LookAtDurationMin = 1.5;
const LookAtDurationMax = 2.75; // after this point the text has faded anyway
const LookAtDurationPerChar = 0.02; // 1 second per 50 characters

const MaxFlyoverLength = 45;
const MaxToastLength = 40;
const MaxNarrativeQueueLength = 5;

const MaxQueuedCommLinkNarratives = 10;

var private array<TNarrativeQueueItem> PendingNarrativeItems;

// Sound cues for when civilians speak
var private array<name> CivilianSoundCues_English_Female;
var private array<name> CivilianSoundCues_English_Male;
var private array<name> CivilianSoundCues_French_Female;
var private array<name> CivilianSoundCues_French_Male;
var private array<name> CivilianSoundCues_German_Female;
var private array<name> CivilianSoundCues_German_Male;
var private array<name> CivilianSoundCues_Italian_Female;
var private array<name> CivilianSoundCues_Italian_Male;
var private array<name> CivilianSoundCues_Polish_Female;
var private array<name> CivilianSoundCues_Polish_Male;
var private array<name> CivilianSoundCues_Spanish_Female;
var private array<name> CivilianSoundCues_Spanish_Male;
var private array<name> CivilianSoundCues_Russian_Female;
var private array<name> CivilianSoundCues_Russian_Male;

// Need multiple narrative moments in order to cycle between them
var private XComNarrativeMoment NarrativeMomentShort01;
var private XComNarrativeMoment NarrativeMomentShort02;
var private XComNarrativeMoment NarrativeMomentMedium01;
var private XComNarrativeMoment NarrativeMomentMedium02;
var private XComNarrativeMoment NarrativeMomentLong01;
var private XComNarrativeMoment NarrativeMomentLong02;

var private XComNarrativeMoment NextNarrativeMomentShort;
var private XComNarrativeMoment NextNarrativeMomentMedium;
var private XComNarrativeMoment NextNarrativeMomentLong;

function Initialize(TwitchStateManager StateMgr) {
    local Object ThisObj;

    if (NarrativeMomentShort01 == none) {
        NarrativeMomentShort01 = XComNarrativeMoment(DynamicLoadObject("TwitchIntegration_UI.XSayBlank_Short_01", class'XComNarrativeMoment'));
    }

    if (NarrativeMomentShort02 == none) {
        NarrativeMomentShort02 = XComNarrativeMoment(DynamicLoadObject("TwitchIntegration_UI.XSayBlank_Short_02", class'XComNarrativeMoment'));
    }

    if (NarrativeMomentMedium01 == none) {
        NarrativeMomentMedium01 = XComNarrativeMoment(DynamicLoadObject("TwitchIntegration_UI.XSayBlank_Medium_01", class'XComNarrativeMoment'));
    }

    if (NarrativeMomentMedium02 == none) {
        NarrativeMomentMedium02 = XComNarrativeMoment(DynamicLoadObject("TwitchIntegration_UI.XSayBlank_Medium_02", class'XComNarrativeMoment'));
    }

    if (NarrativeMomentLong01 == none) {
        NarrativeMomentLong01 = XComNarrativeMoment(DynamicLoadObject("TwitchIntegration_UI.XSayBlank_Long_01", class'XComNarrativeMoment'));
    }

    if (NarrativeMomentLong02 == none) {
        NarrativeMomentLong02 = XComNarrativeMoment(DynamicLoadObject("TwitchIntegration_UI.XSayBlank_Long_02", class'XComNarrativeMoment'));
    }

    if (NextNarrativeMomentShort == none) {
        NextNarrativeMomentShort = NarrativeMomentShort01;
    }

    if (NextNarrativeMomentMedium == none) {
        NextNarrativeMomentMedium = NarrativeMomentMedium01;
    }

    if (NextNarrativeMomentLong == none) {
        NextNarrativeMomentLong = NarrativeMomentLong01;
    }

    ThisObj = self;
    `XEVENTMGR.RegisterForEvent(ThisObj, 'TwitchChatMessageDeleted', OnMessageDeleted, ELD_Immediate);

    `XWORLDINFO.MyWatchVariableMgr.RegisterWatchVariable(`PRESBASE.m_kNarrativeUIMgr, 'm_arrConversations', self, EnqueueXSayToCommLinkIfPossible);
}

function bool Invoke(string CommandAlias, string Body, string MessageId, TwitchChatter Viewer) {
    local bool bIsTacticalGame, bShowInCommLink;
    local TNarrativeQueueItem NarrativeItem;
    local TViewerXSayOverride ViewerOverride;
	local XComGameStateContext_ChangeContainer NewContext;
	local XComGameState NewGameState;
	local XComGameState_TwitchXSay XSayGameState;
	local XComGameState_Unit Unit;

    if (!CanViewerXSay(Viewer.Login, Unit, ViewerOverride)) {
        `TILOG("Viewer is not able to xsay right now; skipping");
        return false;
    }

    bIsTacticalGame = `TI_IS_TAC_GAME;
    bShowInCommLink = true; // TODO: hook up to config

    NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Twitch XSay");
	XSayGameState = XComGameState_TwitchXSay(CreateChatCommandGameState(NewGameState, Body, MessageId, Viewer));

    // Need to include a new game state for the unit or else the visualizer may think it's still
    // visualizing an old ability and fail to do the flyover
    if (Unit != none) {
        Unit = XComGameState_Unit(NewGameState.ModifyStateObject(class'XComGameState_Unit', Unit.ObjectID));
    }

    if (bIsTacticalGame) {
        NewContext = XComGameStateContext_ChangeContainer(NewGameState.GetContext());
	    NewContext.BuildVisualizationFn = BuildVisualization_TacLayer;
    }

    `GAMERULES.SubmitGameState(NewGameState);

    // Submit to chat log immediately to avoid delays from waiting on visualization
    class'X2TwitchUtils'.static.AddMessageToChatLog(XSayGameState.SenderLogin, XSayGameState.MessageBody, Unit, XSayGameState.TwitchMessageId);

    // TODO: turn off comm link if not in LOS, or make it not show unit type, to avoid spoilers
    if (bShowInCommLink) {
        // Don't record a unit was dead if we're on the strat layer, unless they're a dead soldier
        // TODO: this won't work when Chosen are permanently killed
        NarrativeItem.GameState = XSayGameState;
        NarrativeItem.bUnitWasDead = Unit != none && Unit.IsDead() && (bIsTacticalGame || Unit.IsSoldier());

        EnqueueCommLink(NarrativeItem);
    }

    return true;
}

protected function BuildVisualization_TacLayer(XComGameState VisualizeGameState) {
    local bool bUnitIsVisibleToSquad;
    local string SanitizedMessageBody;
    local string ViewerName;
    local EWidgetColor MessageColor;
    local TwitchChatter Chatter;
	local VisualizationActionMetadata ActionMetadata;
	local X2Action_PlayMessageBanner MessageAction;
	local X2Action_PlaySoundAndFlyOver SoundAndFlyover;
	local XComGameState_TwitchXSay XSayGameState;
	local XComGameState_Unit Unit;
	local XComGameStateHistory History;
	local XComTacticalController LocalController;

	History = `XCOMHISTORY;

	foreach VisualizeGameState.IterateByClassType(class'XComGameState_TwitchXSay', XSayGameState) {
		break;
	}

    // Make sure this message wasn't deleted from Twitch chat before we visualize it
    if (XSayGameState.bMessageDeleted) {
        return;
    }

    `TISTATEMGR.GetViewer(XSayGameState.SenderLogin, Chatter);
    ViewerName = `TIVIEWERNAME(Chatter);
    Unit = class'X2TwitchUtils'.static.FindUnitOwnedByViewer(Chatter.Login);
    bUnitIsVisibleToSquad = Unit != none && class'X2TacticalVisibilityHelpers'.static.CanXComSquadSeeTarget(Unit.ObjectID);

	ActionMetadata.StateObject_OldState = Unit;
	ActionMetadata.StateObject_NewState = Unit;

    if (Unit != none) {
    	ActionMetadata.VisualizeActor = History.GetVisualizer(Unit.ObjectID);
    }

    // Don't do the flyover if we can't see the unit, regardless of settings
    if (bShowFlyover && bUnitIsVisibleToSquad) {
        if (Unit.IsDead()) {
            MessageColor = eColor_Gray;
        }
        else {
            switch (Unit.GetTeam()) {
                case eTeam_Alien:
                    MessageColor = eColor_Alien;
                    break;
                case eTeam_TheLost:
                    MessageColor = eColor_TheLost;
                    break;
                default:
                    MessageColor = eColor_Xcom;
                    break;
            }
        }

        SanitizedMessageBody = class'TextUtilities_Twitch'.static.SanitizeText(TruncateMessage(XSayGameState.MessageBody, MaxFlyoverLength));

	    SoundAndFlyOver = X2Action_PlaySoundAndFlyOver(class'X2Action_PlaySoundAndFlyOver'.static.AddToVisualizationTree(ActionMetadata, VisualizeGameState.GetContext(), false, ActionMetadata.LastActionAdded));
	    SoundAndFlyOver.SetSoundAndFlyOverParameters(none, SanitizedMessageBody, '', MessageColor, /* _FlyOverIcon */,
                                                     CalcLookAtDuration(SanitizedMessageBody), /* _BlockUntilFinished */, /* _VisibleTeam */, class'UIWorldMessageMgr'.const.FXS_MSG_BEHAVIOR_FLOAT);
    }

    if (SoundAndFlyOver == none || SoundAndFlyOver.LookAtDuration <= 0)
    {
        // If we aren't doing a flyover, we need to prevent the tactical controller from automatically panning back to the selected unit.
        // The only way to do that is to make it think the player selected a different unit while visualizing.
        LocalController = XComTacticalController(class'WorldInfo'.static.GetWorldInfo().GetALocalPlayerController());
        LocalController.bManuallySwitchedUnitsWhileVisualizerBusy = true;
    }

    if (bShowToast) {
        SanitizedMessageBody = class'TextUtilities_Twitch'.static.SanitizeText(TruncateMessage(XSayGameState.MessageBody, MaxToastLength));

        MessageAction = X2Action_PlayMessageBanner(class'X2Action_PlayMessageBanner'.static.AddToVisualizationTree(ActionMetadata, VisualizeGameState.GetContext()));
        MessageAction.AddMessageBanner("Twitch Message", "", ViewerName, SanitizedMessageBody, eUIState_Normal);
        MessageAction.bDontPlaySoundEvent = true;
    }
}

private function float CalcLookAtDuration(string Message) {
    if (default.LookAtDuration > 0) {
        // User-configured value: just use it directly
        return default.LookAtDuration;
    }

    if (default.LookAtDuration < 0) {
        // Negative value: disable look-at
        return 0.0;
    }

    // Set to 0: automatically determine a duration based on message length
    return Clamp(Len(Message) * LookAtDurationPerChar, LookAtDurationMin, LookAtDurationMax);
}

function EventListenerReturn OnMessageDeleted(Object EventData, Object EventSource, XComGameState GameState, Name Event, Object CallbackData) {
    local bool bCreatedNewGameState, bHasGameState;
    local string MsgId;
    local XComGameState_TwitchXSay XSayGameState;
    local XComLWTuple Tuple;

    Tuple = XComLWTuple(EventData);
    MsgId = Tuple.Data[0].s;

    // Check if there's an XSay tied to this message
    foreach `XCOMHISTORY.IterateByClassType(class'XComGameState_TwitchXSay', XSayGameState) {
        if (XSayGameState.TwitchMessageId == MsgId) {
            bHasGameState = true;
            break;
        }
    }

    if (!bHasGameState) {
        `TILOG("Didn't find an XSayGameState for MsgId " $ MsgId);
        return ELR_NoInterrupt;
    }

    // Need to submit a new version of the object so we don't visualize something that got deleted
    if (GameState == none || GameState.bReadOnly) {
        GameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Mark XSay Deleted");
        bCreatedNewGameState = true;
    }

    XSayGameState = XComGameState_TwitchXSay(GameState.ModifyStateObject(class'XComGameState_TwitchXSay', XSayGameState.ObjectID));
    XSayGameState.bMessageDeleted = true;

    if (bCreatedNewGameState) {
        `GAMERULES.SubmitGameState(GameState);
    }

    return ELR_NoInterrupt;
}

private function string TruncateMessage(string Message, int MaxLength) {
    if (Len(Message) > MaxLength) {
        Message = Left(Message, MaxLength) $ " ...";
    }

    return Message;
}

private function bool CanViewerXSay(string ViewerLogin, out XComGameState_Unit UnitState, out TViewerXSayOverride ViewerOverride) {
    local bool bIsTacticalGame, bUnitIsVisibleToSquad, bOverrideExists;

    bIsTacticalGame = `TI_IS_TAC_GAME;
    bOverrideExists = FindViewerOverride(ViewerLogin, ViewerOverride);

    if (bIsTacticalGame) {
        // Tac game: your unit has to be on the mission
        UnitState = class'X2TwitchUtils'.static.GetViewerUnitOnMission(ViewerLogin);
    }
    else {
        // Strat game: if you own a unit, you can chat
        // TODO: how should we handle dead units on strat layer? esp Chosen
        UnitState = class'X2TwitchUtils'.static.FindUnitOwnedByViewer(ViewerLogin);
    }

    if (UnitState != none) {
        if (bIsTacticalGame && bRequireUnitInLOS && !ViewerOverride.bCanAlwaysSpeakOnTac) {
            bUnitIsVisibleToSquad = class'X2TacticalVisibilityHelpers'.static.CanXComSquadSeeTarget(UnitState.ObjectID);

            if (!bUnitIsVisibleToSquad) {
                return false;
            }
        }

        return true;
    }

    // Without a unit, you need an override to talk
    if (!bOverrideExists) {
        return false;
    }

    if (bIsTacticalGame && ViewerOverride.bCanAlwaysSpeakOnTac) {
        return true;
    }

    if (!bIsTacticalGame && ViewerOverride.bCanAlwaysSpeakOnStrat) {
        return true;
    }

    return false;
}

private function EnqueueCommLink(TNarrativeQueueItem NarrativeItem) {
    if (PendingNarrativeItems.Length >= MaxQueuedCommLinkNarratives) {
        return;
    }

    NarrativeItem.NarrativeMoment = PickNarrativeMoment(NarrativeItem.GameState.MessageBody);
    PendingNarrativeItems.AddItem(NarrativeItem);

    EnqueueXSayToCommLinkIfPossible();
}

private function EnqueueXSayToCommLinkIfPossible() {
    local int Index;
    local UINarrativeMgr kNarrativeMgr;

    kNarrativeMgr = `PRESBASE.m_kNarrativeUIMgr;

    for (Index = 0; Index < PendingNarrativeItems.Length; Index++) {
        if (PendingNarrativeItems[Index].GameState.bMessageDeleted) {
            PendingNarrativeItems.Remove(Index, 1);
            Index--;
            continue;
        }
    }

    if (kNarrativeMgr.m_arrConversations.Length != 0 || kNarrativeMgr.PendingConversations.Length != 0 || PendingNarrativeItems.Length == 0) {
        return;
    }

    // Add our message, but don't remove it from queue; that's the job of OverrideCommLinkFields
    `PRESBASE.UINarrative(PendingNarrativeItems[0].NarrativeMoment);

    // End this timer if it's running or else our next conversation may get ended immediately
    if (kNarrativeMgr.IsTimerActive('EndCurrentConversation')) {
        kNarrativeMgr.ClearTimer('EndCurrentConversation');
    }

    `TISTATEMGR.SetTimer(0.1, /* inbLoop */ true, nameof(OverrideCommLinkFields), self);
}

private function bool FindViewerOverride(string ViewerLogin, out TViewerXSayOverride ViewerOverride) {
    local TViewerXSayOverride PossibleOverride;

    ViewerLogin = Locs(ViewerLogin);

    foreach ViewerOverrides(PossibleOverride) {
        if (Locs(PossibleOverride.ViewerLogin) == ViewerLogin) {
            ViewerOverride = PossibleOverride;
            return true;
        }
    }

    return false;
}

private function string GetMessageBody(TNarrativeQueueItem NarrativeItem) {
    local string Body;

    Body = class'TextUtilities_Twitch'.static.SanitizeText(NarrativeItem.GameState.MessageBody);
    Body = class'UIUtilities_Twitch'.static.InsertEmotes(Body);

    if (NarrativeItem.bUnitWasDead && `TI_CFG(bFormatDeadMessages)) {
        Body = class'UIUtilities_Twitch'.static.FormatDeadMessage(Body);
    }

    return Body;
}

private function string GetUnitPortrait(XComGameState_Unit Unit) {
    local Name CharGroupName;
    local XComGameState_Unit SourceUnit;
    local TUnitContentConfig ContentCfg;

    if (Unit == none) {
        return "";
    }

    if (Unit.IsSoldier()) {
        // Strip the "img:///" because the caller is expecting to add that
        return Repl(GetSoldierHeadshot(Unit.GetReference().ObjectID), "img:///", "");
    }

    CharGroupName = Unit.GetMyTemplate().CharacterGroupName;

    if (CharGroupName == 'PsiZombie' || CharGroupName == 'PsiZombieHuman') {
        SourceUnit = class'X2TwitchUtils'.static.FindSourceUnitFromSpawnEffect(Unit);

        if (SourceUnit != none) {
            CharGroupName = SourceUnit.GetMyTemplate().CharacterGroupName;
        }
    }

    if (!GetContentConfig(CharGroupName, ContentCfg))
    {
        return "TwitchIntegration_UI.AlienCowboy_A";
    }

    return ContentCfg.CommlinkImage;
}

private function AkBaseSoundObject GetCivilianSound(XComGameState_Unit Unit) {
    local bool bUnitIsFemale;
    local int LanguageIndex;
    local array<name> PossibleLanguages;
    local array<name> PossibleSounds;
    local name Language, CueName;

    bUnitIsFemale = Unit.kAppearance.iGender == 2;

    // Sound cues exist for English, French, German, Italian, Polish, Russian and Spanish
    `TILOG("GetCivilianSound: bUnitIsFemale = " $ bUnitIsFemale $ "; Country = " $ Unit.GetCountry());

    // Populate language pool. Some languages are added multiple times to shift their likelihood.
    switch (Unit.GetCountry()) {
        case 'Country_Australia':
        case 'Country_Canada':
        case 'Country_China':
        case 'Country_Egypt':
        case 'Country_India':
        case 'Country_Indonesia':
        case 'Country_Iran':
        case 'Country_Ireland':
        case 'Country_Israel':
        case 'Country_Japan':
        case 'Country_Norway':
        case 'Country_Pakistan':
        case 'Country_Scotland':
        case 'Country_SouthAfrica':
        case 'Country_SouthKorea':
        case 'Country_Turkey':
        case 'Country_UK':
        case 'Country_USA':
            PossibleLanguages.AddItem('ENG');
            break;
        case 'Country_France':
            PossibleLanguages.AddItem('FRA');
            break;
        case 'Country_Germany':
            PossibleLanguages.AddItem('GER');
            break;
        case 'Country_Italy':
            PossibleLanguages.AddItem('ITA');
            break;
        case 'Country_Argentina':
        case 'Country_Mexico':
        case 'Country_Spain':
            PossibleLanguages.AddItem('SPA');
            break;
        case 'Country_Brazil':
            PossibleLanguages.AddItem('ENG');
            PossibleLanguages.AddItem('ENG');
            PossibleLanguages.AddItem('GER');
            PossibleLanguages.AddItem('GER');
            PossibleLanguages.AddItem('ITA');
            PossibleLanguages.AddItem('SPA');
            PossibleLanguages.AddItem('SPA');
            PossibleLanguages.AddItem('SPA');
            PossibleLanguages.AddItem('SPA');
            break;
        case 'Country_Greece':
            PossibleLanguages.AddItem('ENG');
            PossibleLanguages.AddItem('ENG');
            PossibleLanguages.AddItem('ENG');
            PossibleLanguages.AddItem('ENG');
            PossibleLanguages.AddItem('ENG');
            PossibleLanguages.AddItem('FRA');
            PossibleLanguages.AddItem('GER');
            PossibleLanguages.AddItem('ITA');
            break;
        case 'Country_Nigeria':
            PossibleLanguages.AddItem('ENG');
            PossibleLanguages.AddItem('ENG');
            PossibleLanguages.AddItem('ENG');
            PossibleLanguages.AddItem('ENG');
            PossibleLanguages.AddItem('ENG');
            PossibleLanguages.AddItem('FRA');
            break;
        case 'Country_Belgium':
        case 'Country_Netherlands':
        case 'Country_Sweden':
            PossibleLanguages.AddItem('ENG');
            PossibleLanguages.AddItem('FRA');
            PossibleLanguages.AddItem('FRA');
            PossibleLanguages.AddItem('GER');
            PossibleLanguages.AddItem('GER');
            PossibleLanguages.AddItem('GER');
            break;
        case 'Country_Poland':
            PossibleLanguages.AddItem('ENG');
            PossibleLanguages.AddItem('GER');
            PossibleLanguages.AddItem('POL');
            PossibleLanguages.AddItem('POL');
            PossibleLanguages.AddItem('POL');
            PossibleLanguages.AddItem('POL');
            PossibleLanguages.AddItem('RUS');
            break;
        case 'Country_Columbia':
        case 'Country_Portugal':
        case 'Country_Venezuela':
            PossibleLanguages.AddItem('ENG');
            PossibleLanguages.AddItem('SPA');
            PossibleLanguages.AddItem('SPA');
            PossibleLanguages.AddItem('SPA');
            PossibleLanguages.AddItem('SPA');
            break;
        case 'Country_Russia':
        case 'Country_Ukraine':
            PossibleLanguages.AddItem('RUS');
            break;
        default:
            PossibleLanguages.AddItem('ENG');
            break;
    }

    if (PossibleLanguages.Length == 0) {
        return none;
    }

    // We want each unit to speak the same language consistently; use their object ID to do so
    LanguageIndex = Unit.ObjectID % PossibleLanguages.Length;
    Language = PossibleLanguages[LanguageIndex];

    //`TILOG("Unit " $ Unit.GetFullName() $ " will speak language " $ Language $ " at index " $ LanguageIndex);

    switch (Language) {
        case 'ENG':
            PossibleSounds = bUnitIsFemale ? default.CivilianSoundCues_English_Female : default.CivilianSoundCues_English_Male;
            break;
        case 'FRA':
            PossibleSounds = bUnitIsFemale ? default.CivilianSoundCues_French_Female : default.CivilianSoundCues_French_Male;
            break;
        case 'GER':
            PossibleSounds = bUnitIsFemale ? default.CivilianSoundCues_German_Female : default.CivilianSoundCues_German_Male;
            break;
        case 'ITA':
            PossibleSounds = bUnitIsFemale ? default.CivilianSoundCues_Italian_Female : default.CivilianSoundCues_Italian_Male;
            break;
        case 'POL':
            PossibleSounds = bUnitIsFemale ? default.CivilianSoundCues_Polish_Female : default.CivilianSoundCues_Polish_Male;
            break;
        case 'RUS':
            PossibleSounds = bUnitIsFemale ? default.CivilianSoundCues_Russian_Female : default.CivilianSoundCues_Russian_Male;
            break;
        case 'SPA':
            PossibleSounds = bUnitIsFemale ? default.CivilianSoundCues_Spanish_Female : default.CivilianSoundCues_Spanish_Male;
            break;
        default:
            `TILOG("Language " $ Language $ " should not be possible!");
            return none;
    }

    if (PossibleSounds.Length == 0) {
        `TILOG("No sounds are configured for a " $ (bUnitIsFemale ? "female" : "male") $ " civilian with language " $ Language);
        return None;
    }

    CueName = PossibleSounds[Rand(PossibleSounds.Length)];
    //`TILOG("Using SoundCue " $ CueName $ " for civilian out of a possible " $ PossibleSounds.Length);

    return SoundCue(DynamicLoadObject(string(CueName), class'SoundCue'));
}

private function bool GetContentConfig(name CharacterGroupName, out TUnitContentConfig ContentCfg)
{
    local int Index;

    Index = UnitContentCfg.Find('CharacterGroupName', CharacterGroupName);

    if (Index == INDEX_NONE)
    {
        return false;
    }

    ContentCfg = UnitContentCfg[Index];
    return true;
}

private function AkBaseSoundObject GetUnitSound(TNarrativeQueueItem NarrativeItem, XComGameState_Unit Unit) {
    local bool bUnitIsFemale;
    local name CharGroupName;
    local string SelectedSoundPath;
    local array<string> SoundPaths;
    local TUnitContentConfig ContentCfg;

    if (Unit == none) {
        return none;
    }

    if (Unit.IsSoldier()) {
        // TODO: see XCOMGameState_Unit.kAppearance.nmVoice and XComHumanPawn.SetVoice
        return none;
    }

    // Non-militia civilians don't have a CharacterGroupName
    if (XGUnit(Unit.GetVisualizer()).IsCivilianChar()) {
        return GetCivilianSound(Unit);
    }

    CharGroupName = Unit.GetMyTemplate().CharacterGroupName;
    bUnitIsFemale = Unit.kAppearance.iGender == 2;

    if (!GetContentConfig(CharGroupName, ContentCfg))
    {
        return none;
    }

    // Sounds might be configured for either gender since some units have none; only use the unit's gender if
    // both male and female sounds are configured, else fall back to whatever is populated
    if (ContentCfg.CommlinkSoundsFemale.Length > 0 && ContentCfg.CommlinkSoundsMale.Length > 0)
    {
        SoundPaths = bUnitIsFemale ? ContentCfg.CommlinkSoundsFemale : ContentCfg.CommlinkSoundsMale;
    }
    else if (ContentCfg.CommlinkSoundsFemale.Length > 0)
    {
        SoundPaths = ContentCfg.CommlinkSoundsFemale;
    }
    else
    {
        SoundPaths = ContentCfg.CommlinkSoundsMale;
    }

    if (SoundPaths.Length == 0)
    {
        return none;
    }

    SelectedSoundPath = SoundPaths[Rand(SoundPaths.Length)];
    return AkBaseSoundObject(DynamicLoadObject(SelectedSoundPath, class'AkBaseSoundObject'));
}

private function OverrideCommLinkFields() {
    local bool bHasViewerOverride;
    local string UnitPortrait;
    local AkBaseSoundObject Sound;
    local TNarrativeQueueItem NarrativeItem;
    local TViewerXSayOverride ViewerOverride;
    local UINarrativeCommLink CommLink;
	local UINarrativeMgr kNarrativeMgr;
    local XComGameState_Unit Unit;

    if (PendingNarrativeItems.Length == 0) {
        `TISTATEMGR.ClearTimer(nameof(OverrideCommLinkFields), self);

        return;
    }

    CommLink = `PRESBASE.GetUIComm();
	kNarrativeMgr = CommLink.Movie.Pres.m_kNarrativeUIMgr;

    // Make sure the narrative manager has advanced to something we queued
    if (kNarrativeMgr.CurrentOutput.strTitle != "Twitch_Chat") {
        return;
    }

    // Dequeue the current narrative item
    NarrativeItem = PendingNarrativeItems[0];
    PendingNarrativeItems.Remove(0, 1);

    if (PendingNarrativeItems.Length == 0) {
        // Don't call this again until another XSay state has been sent to the narrative manager
        `TISTATEMGR.ClearTimer(nameof(OverrideCommLinkFields), self);
    }

    if (NarrativeItem.GameState.SendingUnitObjectID > 0) {
        Unit = XComGameState_Unit(`XCOMHISTORY.GetGameStateForObjectID(NarrativeItem.GameState.SendingUnitObjectID));
    }

    // Swap in our XSay data. We aren't using CurrentOutput ourselves, but if the comm link UI refreshes for some reason,
    // we want to be sure our data is there. (Opening and closing the menu is one way this can happen.)
    kNarrativeMgr.CurrentOutput.strTitle = NarrativeItem.GameState.SenderLogin;
    kNarrativeMgr.CurrentOutput.strText = GetMessageBody(NarrativeItem);
    kNarrativeMgr.CurrentOutput.strImage = "img:///TwitchIntegration_UI.Icon_Twitch_3D";

    // Call the AS functions directly, because if we call AS_SetPortrait too much the UI gets weird and moves to the wrong part of the screen
    CommLink.AS_SetTitle(kNarrativeMgr.CurrentOutput.strTitle);
    CommLink.AS_SetText(kNarrativeMgr.CurrentOutput.strText);
    CommLink.AS_ShowSubtitles(); // since we have no audio, we need the text shown regardless of global subtitle settings

    // Figure out what picture to actually use for the comm link UI
    bHasViewerOverride = FindViewerOverride(NarrativeItem.GameState.SenderLogin, ViewerOverride);

    if (bHasViewerOverride && ViewerOverride.CommLinkImageOverride != "") {
        // If viewer has an override with a picture set, use that always
        kNarrativeMgr.CurrentOutput.strImage = "img:///" $ ViewerOverride.CommLinkImageOverride;
        CommLink.AS_SetPortrait("img:///" $ ViewerOverride.CommLinkImageOverride);
    }
    else if (Unit != none && Unit.IsSoldier() && `TI_IS_STRAT_GAME) {
        // On strat layer, generate a headshot
		`HQPRES.GetPhotoboothAutoGen().AddHeadShotRequest(Unit.GetReference(), 512, 512, OnHeadshotReady, , , /* bHighPriority */ true);
		`HQPRES.GetPhotoboothAutoGen().RequestPhotos();
    }
    else {
        // On tac layer, use the unit portrait (which may include an old headshot for soldiers)
        UnitPortrait = GetUnitPortrait(Unit);

        if (UnitPortrait != "") {
            kNarrativeMgr.CurrentOutput.strImage = "img:///" $ UnitPortrait;
            CommLink.AS_SetPortrait(kNarrativeMgr.CurrentOutput.strImage);
        }
    }

    // Now that we know our dialogue's on the UI, play the associated sound
    if (bHasViewerOverride && ViewerOverride.Sounds.Length > 0) {
        Sound = SoundCue(DynamicLoadObject(ViewerOverride.Sounds[Rand(ViewerOverride.Sounds.Length)], class'SoundCue'));
    }
    else {
        Sound = GetUnitSound(NarrativeItem, Unit);
    }

    if (Sound != none) {
        if (Unit != none && Unit.GetVisualizer() != none) {
            Unit.GetVisualizer().PlaySoundBase(Sound, true);
        }
        else {
            class'WorldInfo'.static.GetWorldInfo().PlaySoundBase(Sound, true);
        }
    }
}

function XComNarrativeMoment PickNarrativeMoment(string Message) {
    local XComNarrativeMoment NarrativeMoment;

    NarrativeMoment = NextNarrativeMomentLong;
    NextNarrativeMomentLong = NextNarrativeMomentLong == NarrativeMomentLong01 ? NarrativeMomentLong02 : NarrativeMomentLong01;

    // TODO: these are all way too short, figure something out later
/*
    // Since we can't dynamically change the duration of a NarrativeMoment, we have 3 different lengths built into the mod.
    // The narrative manager won't let us queue the same NarrativeMoment twice in a row, so we have to alternate.
    if (Len(Message) < 50) {
        NarrativeMoment = NextNarrativeMomentShort;
        NextNarrativeMomentShort = NextNarrativeMomentShort == NarrativeMomentShort01 ? NarrativeMomentShort02 : NarrativeMomentShort01;
    }
    else if (Len(Message) < 250) {
        NarrativeMoment = NextNarrativeMomentMedium;
        NextNarrativeMomentMedium = NextNarrativeMomentMedium == NarrativeMomentMedium01 ? NarrativeMomentMedium02 : NarrativeMomentMedium01;
    }
    else {
        NarrativeMoment = NextNarrativeMomentLong;
        NextNarrativeMomentLong = NextNarrativeMomentLong == NarrativeMomentLong01 ? NarrativeMomentLong02 : NarrativeMomentLong01;
    }
 */

    return NarrativeMoment;
}

function string GetSoldierHeadshot(int UnitObjectID) {
    local string HeadshotPath;
    local Texture2D HeadshotTex;
	local XComGameState_CampaignSettings SettingsState;

	SettingsState = XComGameState_CampaignSettings(`XCOMHISTORY.GetSingleGameStateObjectForClass(class'XComGameState_CampaignSettings'));
    HeadshotTex = `XENGINE.m_kPhotoManager.GetHeadshotTexture(SettingsState.GameIndex, UnitObjectID, 512, 512);

    if (HeadshotTex != none) {
        HeadshotPath = class'UIUtilities_Image'.static.ValidateImagePath(PathName(HeadshotTex));
    }

    return HeadshotPath;
}

simulated function OnHeadshotReady(StateObjectReference UnitRef) {
    local UINarrativeCommLink CommLink;
	local UINarrativeMgr kNarrativeMgr;

    CommLink = `PRESBASE.GetUIComm();

	kNarrativeMgr = CommLink.Movie.Pres.m_kNarrativeUIMgr;
    kNarrativeMgr.CurrentOutput.strImage = GetSoldierHeadshot(UnitRef.ObjectID);

    CommLink.AS_SetPortrait(kNarrativeMgr.CurrentOutput.strImage);
}

defaultproperties
{
    GameStateClass=class'XComGameState_TwitchXSay'

    CivilianSoundCues_English_Female[0]=""
    CivilianSoundCues_English_Male.Add("MaleVoice1_English_Data.SM01AlienSighting08_Cue")
    CivilianSoundCues_English_Male.Add("MaleVoice1_English_Data.SM01AlienSighting15_Cue")
    CivilianSoundCues_English_Male.Add("MaleVoice2_English_Data.SM02CloseCombatSpecialist05_Cue")
    CivilianSoundCues_French_Female[0]=""
    CivilianSoundCues_French_Male.Add("MaleVoice1_French_Data.SM01GenericResponse05_Cue")
    CivilianSoundCues_French_Male.Add("MaleVoice1_French_Data.SM01GenericResponse09_Cue")
    CivilianSoundCues_French_Male.Add("MaleVoice1_French_Data.SM01BattleScanner16_Cue")
    CivilianSoundCues_French_Male.Add("MaleVoice5_French_Data.SM05GenericResponse05_Cue")
    CivilianSoundCues_French_Male.Add("MaleVoice5_French_Data.SM05GenericResponse11_Cue")
    CivilianSoundCues_French_Male.Add("MaleVoice5_French_Data.SM05DestroyingCover12_Cue")
    CivilianSoundCues_French_Male.Add("MaleVoice6_French_Data.SM06CivilianRescue19_Cue")
    CivilianSoundCues_German_Female[0]=""
    CivilianSoundCues_German_Male.Add("MaleVoice1_German_Data.SM01TakingDamage02_Cue")
    CivilianSoundCues_German_Male.Add("MaleVoice1_German_Data.SM01TakingDamage14_Cue")
    CivilianSoundCues_German_Male.Add("MaleVoice2_German_Data.SM02TakingDamage31_Cue")
    CivilianSoundCues_German_Male.Add("MaleVoice3_German_Data.SM03TakingDamage01_Cue")
    CivilianSoundCues_German_Male.Add("MaleVoice3_German_Data.SM03TakingDamage02_Cue")
    CivilianSoundCues_German_Male.Add("MaleVoice3_German_Data.SM03TakingDamage06_Cue")
    CivilianSoundCues_German_Male.Add("MaleVoice5_German_Data.SM05TakingDamage07_Cue")
    CivilianSoundCues_Italian_Female[0]=""
    CivilianSoundCues_Italian_Male[0]=""
    CivilianSoundCues_Polish_Female[0]=""
    CivilianSoundCues_Polish_Male[0]=""
    CivilianSoundCues_Spanish_Female[0]=""
    CivilianSoundCues_Spanish_Male.Add("MaleVoice1_Spanish_Data.SM01GenericResponse05_Cue")
    CivilianSoundCues_Spanish_Male.Add("MaleVoice3_Spanish_Data.SM03Moving05_Cue")
    CivilianSoundCues_Russian_Female[0]=""
    CivilianSoundCues_Russian_Male.Add("MaleVoice2_Russian_Data.SM02TakingDamage31_Cue")
    CivilianSoundCues_Russian_Male.Add("MaleVoice2_Russian_Data.SM02TakingDamage32_Cue")
    CivilianSoundCues_Russian_Male.Add("MaleVoice3_Russian_Data.SM03TakingDamage04_Cue")
    CivilianSoundCues_Russian_Male.Add("MaleVoice4_Russian_Data.SM04TakingDamage14_Cue")
    CivilianSoundCues_Russian_Male.Add("MaleVoice5_Russian_Data.SM05TakingDamage08_Cue")
    CivilianSoundCues_Russian_Male.Add("MaleVoice5_Russian_Data.SM05TakingDamage14_Cue")
}