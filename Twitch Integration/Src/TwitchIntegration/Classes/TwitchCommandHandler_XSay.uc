class TwitchCommandHandler_XSay extends TwitchCommandHandler
    dependson(TwitchStateManager);

var config bool bRequireUnitInLOS;
var config bool bShowToast;
var config bool bShowFlyover;
var config float LookAtDuration;

const LookAtDurationMin = 1.5;
const LookAtDurationMax = 2.75; // after this point the text has faded anyway
const LookAtDurationPerChar = 0.02; // 1 second per 50 characters

struct TNarrativeQueueItem {
    var XComGameState_TwitchXSay GameState;
    var XComNarrativeMoment NarrativeMoment;
    var bool bUnitWasDead;
};

const MaxFlyoverLength = 45;
const MaxToastLength = 40;
const MaxNarrativeQueueLength = 5;

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
}

function Handle(TwitchStateManager StateMgr, TwitchMessage Command, TwitchViewer Viewer) {
    local bool bIsTacticalGame, bShowInCommLink, bUnitIsVisibleToSquad;
    local TNarrativeQueueItem NarrativeItem;
    local XComGameState NewGameState;
	local XComGameStateContext_ChangeContainer NewContext;
	local XComGameState_TwitchXSay XSayGameState;
	local XComGameState_Unit Unit;

    bIsTacticalGame = `TI_IS_TAC_GAME;
    bShowInCommLink = true; // TODO: hook up to config

    if (bIsTacticalGame) {
        // Tac game: your unit has to be on the mission
        Unit = GetViewerUnitOnMission(Viewer.Login);
    }
    else {
        // Strat game: if you own a unit, you can chat
        // TODO: how should we handle dead units on strat layer? esp Chosen
        Unit = class'X2TwitchUtils'.static.FindUnitOwnedByViewer(Viewer.Login);
    }

    if (Unit == none) {
        `TILOGCLS("Did not find a unit for viewer " $ Viewer.Login $ ", aborting");
        return;
    }

    if (bIsTacticalGame && bRequireUnitInLOS) {
        bUnitIsVisibleToSquad = class'X2TacticalVisibilityHelpers'.static.CanXComSquadSeeTarget(Unit.ObjectID);

        if (!bUnitIsVisibleToSquad) {
            return;
        }
    }

	NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("XSay From " $ Viewer.Login);

	XSayGameState = XComGameState_TwitchXSay(NewGameState.CreateNewStateObject(class'XComGameState_TwitchXSay'));
	XSayGameState.MessageBody = GetCommandBody(Command);
	XSayGameState.Sender = Viewer.Login;
    XSayGameState.SendingUnitObjectID = Unit.GetReference().ObjectID;
    XSayGameState.TwitchMessageId = Command.MsgId;

    // Need to include a new game state for the unit or else the visualizer may think it's still
    // visualizing an old ability and fail to do the flyover
    Unit = XComGameState_Unit(NewGameState.ModifyStateObject(class'XComGameState_Unit', Unit.ObjectID));

    if (bIsTacticalGame) {
        NewContext = XComGameStateContext_ChangeContainer(NewGameState.GetContext());
	    NewContext.BuildVisualizationFn = BuildVisualization_TacLayer;
    }

    `GAMERULES.SubmitGameState(NewGameState);

    if (bShowInCommLink && PendingNarrativeItems.Length < MaxNarrativeQueueLength) {
        NarrativeItem.GameState = XSayGameState;
        NarrativeItem.bUnitWasDead = Unit.IsDead();

        EnqueueCommLink(NarrativeItem);
    }
}

protected function BuildVisualization_TacLayer(XComGameState VisualizeGameState) {
    local bool bUnitIsVisibleToSquad;
    local string SanitizedMessageBody;
    local string ViewerName;
    local EWidgetColor MessageColor;
    local TwitchViewer Viewer;
	local VisualizationActionMetadata ActionMetadata;
    local X2Action_AddToChatLog ChatLogAction;
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

    `TISTATEMGR.TwitchChatConn.GetViewer(XSayGameState.Sender, Viewer);
    ViewerName = `TIVIEWERNAME(Viewer);
    Unit = class'X2TwitchUtils'.static.FindUnitOwnedByViewer(Viewer.Login);
    bUnitIsVisibleToSquad = class'X2TacticalVisibilityHelpers'.static.CanXComSquadSeeTarget(Unit.ObjectID);

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

	ActionMetadata.StateObject_OldState = Unit;
	ActionMetadata.StateObject_NewState = Unit;
	ActionMetadata.VisualizeActor = History.GetVisualizer(Unit.ObjectID);

    // Don't do the flyover if we can't see the unit, regardless of settings
    if (bShowFlyover && bUnitIsVisibleToSquad) {
        SanitizedMessageBody = class'TextUtilities_Twitch'.static.SanitizeText(TruncateMessage(XSayGameState.MessageBody, MaxFlyoverLength));

        // TODO: for ADVENT and Lost a generic talking sound cue would be cool
	    SoundAndFlyOver = X2Action_PlaySoundAndFlyOver(class'X2Action_PlaySoundAndFlyOver'.static.AddToVisualizationTree(ActionMetadata, VisualizeGameState.GetContext(), false, ActionMetadata.LastActionAdded));
	    SoundAndFlyOver.SetSoundAndFlyOverParameters(none, SanitizedMessageBody, '', MessageColor, /* _FlyOverIcon */,
                                                     CalcLookAtDuration(SanitizedMessageBody), /* _BlockUntilFinished */, /* _VisibleTeam */, class'UIWorldMessageMgr'.const.FXS_MSG_BEHAVIOR_FLOAT);
    }
    else {
        // If we aren't doing a flyover, we need to prevent the tactical controller from automatically panning back to the selected unit.
        // The only way to do that is to make it think the player selected a different unit while visualizing.
        LocalController = XComTacticalController(class'WorldInfo'.static.GetWorldInfo().GetALocalPlayerController());
        LocalController.bManuallySwitchedUnitsWhileVisualizerBusy = true;
    }

    ChatLogAction = X2Action_AddToChatLog(class'X2Action_AddToChatLog'.static.AddToVisualizationTree(ActionMetadata, VisualizeGameState.GetContext(), , ActionMetadata.LastActionAdded));
    ChatLogAction.Sender = ViewerName;
    ChatLogAction.Message = XSayGameState.MessageBody; // no need to sanitize, chat log will do it
    ChatLogAction.MsgId = XSayGameState.TwitchMessageId;

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
        `TILOGCLS("Didn't find an XSayGameState for MsgId " $ MsgId);
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

private function EnqueueCommLink(TNarrativeQueueItem NarrativeItem) {
    NarrativeItem.NarrativeMoment = PickNarrativeMoment(NarrativeItem.GameState.MessageBody);
    PendingNarrativeItems.AddItem(NarrativeItem);

    // Add our message, but don't remove it from queue; that's the job of OverrideCommLinkFields
    `PRESBASE.UINarrative(NarrativeItem.NarrativeMoment, /* kFocusActor */ , OnNarrativeCompleteCallback);

    `TISTATEMGR.SetTimer(0.1, /* inbLoop */ true, nameof(OverrideCommLinkFields), self);
}

private function string GetMessageBody(TNarrativeQueueItem NarrativeItem) {
    local string Body;

    Body = class'TextUtilities_Twitch'.static.SanitizeText(NarrativeItem.GameState.MessageBody);

    if (NarrativeItem.bUnitWasDead && `TI_CFG(bFormatDeadMessages)) {
        Body = class'UIUtilities_Twitch'.static.FormatDeadMessage(Body);
    }

    return Body;
}

private function string GetUnitPortrait(XComGameState_Unit Unit) {
    local Name CharGroupName;
    local XComGameState_Unit SourceUnit;

    if (Unit.IsSoldier()) {
        return GetSoldierHeadshot(Unit.GetReference().ObjectID);
    }

    CharGroupName = Unit.GetMyTemplate().CharacterGroupName;

    if (CharGroupName == 'PsiZombie' || CharGroupName == 'SpectralZombie') {
        SourceUnit = class'X2TwitchUtils'.static.FindSourceUnitFromSpawnEffect(Unit);

        if (SourceUnit != none) {
            CharGroupName = SourceUnit.GetMyTemplate().CharacterGroupName;
        }
    }

    // Most unit types are a simple 1-to-1 mapping
    switch (CharGroupName) {
        case 'AdventCaptain':
            return "UILibrary_XPACK_StrategyImages.challenge_AdvCaptain";
        case 'AdventMEC':
            return "UILibrary_XPACK_StrategyImages.challenge_AdvMec";
        case 'AdventPriest':
            return "UILibrary_XPACK_StrategyImages.challenge_AdvPriest";
        case 'AdventPsiWitch': // Avatar
            return "TwitchIntegration_UI.Speaker_Avatar";
        case 'AdventPurifier':
            return "UILibrary_XPACK_StrategyImages.challenge_AdvPurifier";
        case 'AdventShieldbearer':
            return "UILibrary_XPACK_StrategyImages.challenge_AdvShield";
        case 'AdventStunLancer':
        case 'SpectralStunLancer':
            return "UILibrary_XPACK_StrategyImages.challenge_AdvStunLancer";
        case 'AdventTrooper':
            return "UILibrary_XPACK_StrategyImages.challenge_AdvTrooper";
        case 'AdventTurret':
            return "TwitchIntegration_UI.Speaker_AdventTurret";
        case 'Andromedon':
            return "UILibrary_XPACK_StrategyImages.challenge_Andromedon";
        case 'AndromedonRobot':
            return "TwitchIntegration_UI.Speaker_AndromedonRobot";
        case 'Archon':
            return "UILibrary_XPACK_StrategyImages.challenge_Archon";
        case 'ArchonKing':
            return "CIN_Icons.ICON_Archon";
        case 'Berserker':
        case 'BerserkerQueen':
            return "UILibrary_XPACK_StrategyImages.challenge_Berserker";
        case 'ChosenAssassin':
            return "img:///UILibrary_XPACK_Common.Head_Chosen_Assassin";
        case 'ChosenSniper':
            return "img:///UILibrary_XPACK_Common.Head_Chosen_Hunter";
        case 'ChosenWarlock':
            return "img:///UILibrary_XPACK_Common.Head_Chosen_Warlock";
        case 'CivilianMilitia':
            break;
            //return ""; // TODO
        case 'Cyberus': // Codex
            return "UILibrary_XPACK_StrategyImages.challenge_Codex";
        case 'Chryssalid':
            return "UILibrary_XPACK_StrategyImages.challenge_Cryssalid";
        case 'Faceless':
            return "UILibrary_XPACK_StrategyImages.challenge_Faceless";
        case 'Gatekeeper':
            return "UILibrary_XPACK_StrategyImages.challenge_Gatekeeper";
        case 'TheLost':
            return "TwitchIntegration_UI.Speaker_TheLost";
        case 'Muton':
            return "UILibrary_XPACK_StrategyImages.challenge_Muton";
        case 'Sectoid':
            return "UILibrary_XPACK_StrategyImages.challenge_Sectoid";
        case 'Sectopod':
            return "UILibrary_XPACK_StrategyImages.challenge_Sectopod";
        case 'Shadowbind': // Shadow of a soldier created by a Spectre; TODO ideally would use soldier's headshot but Spectre's okay for now
        case 'Spectre':
            return "UILibrary_XPACK_StrategyImages.challenge_Spectre";
        case 'Viper':
        case 'ViperNeonate':
            return "UILibrary_XPACK_StrategyImages.challenge_Viper";
        case 'ViperKing':
            return "TwitchIntegration_UI.Speaker_ViperKing";
    }

    // Non-militia civilians don't have a CharacterGroupName
    if (Unit.IsCivilian()) {
        //return ""; // TODO
    }

    return "TwitchIntegration_UI.AlienCowboy_A";
}

private function AkBaseSoundObject GetCivilianSound(XComGameState_Unit Unit) {
    local bool bUnitIsFemale;
    local int LanguageIndex;
    local array<name> PossibleLanguages;
    local array<name> PossibleSounds;
    local name Language, CueName;

    bUnitIsFemale = Unit.kAppearance.iGender == 2;

    // Sound cues exist for English, French, German, Italian, Polish, Russian and Spanish
    `TILOGCLS("GetCivilianSound: bUnitIsFemale = " $ bUnitIsFemale $ "; Country = " $ Unit.GetCountry());

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

    //`TILOGCLS("Unit " $ Unit.GetFullName() $ " will speak language " $ Language $ " at index " $ LanguageIndex);

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
            `TILOGCLS("Language " $ Language $ " should not be possible!");
            return none;
    }

    if (PossibleSounds.Length == 0) {
        `TILOGCLS("No sounds are configured for a " $ (bUnitIsFemale ? "female" : "male") $ " civilian with language " $ Language);
        return None;
    }

    CueName = PossibleSounds[`SYNC_RAND(PossibleSounds.Length)];
    //`TILOGCLS("Using SoundCue " $ CueName $ " for civilian out of a possible " $ PossibleSounds.Length);

    return SoundCue(DynamicLoadObject(string(CueName), class'SoundCue'));
}

private function AkBaseSoundObject GetUnitSound(TNarrativeQueueItem NarrativeItem, XComGameState_Unit Unit) {
    local bool bUnitIsFemale;
    local Name CharGroupName;

    if (Unit.IsSoldier()) {
        // TODO: see XCOMGameState_Unit.kAppearance.nmVoice and XComHumanPawn.SetVoice
        return none;
    }

    CharGroupName = Unit.GetMyTemplate().CharacterGroupName;
    bUnitIsFemale = Unit.kAppearance.iGender == 2;

    // Most unit types are a simple 1-to-1 mapping
    switch (CharGroupName) {
        case 'AdventCaptain':
        case 'AdventPriest':
        case 'AdventPurifier':
        case 'AdventShieldbearer':
        case 'AdventStunLancer':
        case 'AdventTrooper':
        case 'SpectralStunLancer':
            // We're going to hear ADVENT cues a *lot*, so use every one we can find
            switch (`SYNC_RAND(8)) {
                case 0:
                    return bUnitIsFemale ? SoundCue'SoundAdventVoxFemale.AdventFemaleTargetSightedCue' : SoundCue'SoundAdventVoxMale.AdventMaleTargetSightedCue';
                case 1:
                    return bUnitIsFemale ? SoundCue'SoundAdventFX.ADVENTF01_Moving_Cue' : SoundCue'SoundAdventVoxMale.AdventMaleMovingCue';
                case 2:
                    return bUnitIsFemale ? SoundCue'SoundAdventVoxFemale.AdventFemaleEngagingHostilesCue' : SoundCue'SoundAdventVoxMale.AdventMaleEngagingHostilesCue';
                case 3:
                    return bUnitIsFemale ? SoundCue'SoundAdventVoxFemale.AdventFemaleMovingCue' : SoundCue'SoundAdventVoxMale.AdventMaleMovingCue';
                case 4:
                    return bUnitIsFemale ? SoundCue'SoundAdventVoxFemale.AdventFemaleHaltStopCue' : SoundCue'SoundAdventVoxMale.AdventMaleHaltStopCue';
                case 5:
                    return bUnitIsFemale ? SoundCue'SoundAdventVoxFemale.AdventFemaleRequestReinforcementsCue' : SoundCue'SoundAdventVoxMale.AdventMaleRequestReinforcementsCue';
                case 6:
                    return SoundCue'CIN_XP_PreIntro_AUDIO.Captain.X2_XP_CAPN_CIN_PreIntro_2_Cue';
                default:
                    return SoundCue'CIN_XP_PreIntro_AUDIO.Captain.X2_XP_CAPN_CIN_PreIntro_3_Cue';
            }
        case 'AdventMEC':
            switch (`SYNC_RAND(2)) {
                case 0:
                    return AkEvent'SoundAdventFX.AdvMEC_Speak';
                default:
                    return AkEvent'SoundAdventFX.AdvMEC_Speak_POD';
            }
        case 'AdventPsiWitch': // Avatar
            return AkEvent'SoundX2AvatarFX.Avatar_POD_Reveal_ChargePowers';
        case 'AdventTurret':
            switch (`SYNC_RAND(3)) {
                case 0:
                    return AkEvent'SoundMagneticWeapons.Turret_Crouch2Stand_Advent';
                case 1:
                    return AkEvent'SoundMagneticWeapons.Turret_Crouch2Stand_Xcom';
                default:
                    return AkEvent'SoundMagneticWeapons.Turret_Stand2Crouch_Hacked';
            }
        case 'Andromedon':
        case 'AndromedonRobot':
            switch (`SYNC_RAND(4)) {
                case 0:
                    return AkEvent'SoundX2AndromedonFX.Andromedon_Power_On_Sweetener';
                case 1:
                    return AkEvent'SoundX2AndromedonFX.Andromedon_Speak';
                case 2:
                    return AkEvent'SoundX2AndromedonFX.Andromedon_Hacked_Short';
                default:
                    return AkEvent'SoundX2AndromedonFX.Andromedon_TakeDamage_VOX';
            }
        case 'Archon':
        case 'ArchonKing':
            switch (`SYNC_RAND(5)) {
                case 0:
                    return AkEvent'SoundX2ArchonFX.Archon_Death_Scream';
                case 1:
                    return AkEvent'SoundX2ArchonFX.Archon_Hurt_Scream';
                case 2:
                    return AkEvent'SoundX2ArchonFX.Archon_Misc_Vocals';
                case 3:
                    return AkEvent'SoundX2ArchonFX.Archon_Whoosh';
                default:
                    return AkEvent'SoundX2ArchonFX.Archon_Take_Damage';
            }
        case 'Berserker':
            switch (`SYNC_RAND(5)) {
                case 0:
                    return AkEvent'SoundX2BerserkerFX.Berserker_Scream';
                case 1:
                    return AkEvent'SoundX2BerserkerFX.Berserker_Snif';
                case 2:
                    return AkEvent'SoundX2BerserkerFX.BerserkerBellowShort';
                case 3:
                    return AkEvent'SoundX2BerserkerFX.BerserkerDeathScream';
                default:
                    return AkEvent'SoundX2BerserkerFX.BerserkerTakesDamage';
            }
        case 'BerserkerQueen':
            switch (`SYNC_RAND(4)) {
                case 0:
                    return AkEvent'DLC_60_SoundBerserkerQueen.Berserker_Queen_FaithBreaker';
                case 1:
                    return AkEvent'DLC_60_SoundBerserkerQueen.BerserkerQueen_Idle_Grunt';
                case 2:
                    return AkEvent'DLC_60_SoundBerserkerQueen.BerserkerQueen_Quake_Chargeup';
                default:
                    return AkEvent'DLC_60_SoundBerserkerQueen.BerserkerQueen_Escape';
            }
        case 'ChosenAssassin':
        case 'ChosenSniper':
            return none;
        case 'ChosenWarlock':
            switch (`SYNC_RAND(4)) {
                case 0:
                    return LoadTwitchSoundCue('Warlock_GreatestChampion_01_Cue');
                case 1:
                    return LoadTwitchSoundCue('Warlock_GreatestChampion_02_Cue');
                case 2:
                    return LoadTwitchSoundCue('Warlock_GreatestChampion_03_Cue');
                default:
                    return LoadTwitchSoundCue('Warlock_GreatestChampion_04_Cue');
            }
        case 'Chryssalid':
            switch (`SYNC_RAND(7)) {
                case 0:
                    return AkEvent'SoundX2ChryssalidFX.ChryssalidCallOthers';
                case 1:
                    return AkEvent'SoundX2ChryssalidFX.ChryssalidDeath';
                case 2:
                    return AkEvent'SoundX2ChryssalidFX.ChryssalidFlinchVox';
                case 3:
                    return AkEvent'SoundX2ChryssalidFX.ChryssalidHatchVox';
                case 4:
                    return AkEvent'SoundX2ChryssalidFX.ChryssalidHurt';
                case 5:
                    return AkEvent'SoundX2ChryssalidFX.ChryssalidMovementSweetener';
                default:
                    return AkEvent'SoundX2ChryssalidFX.ChryssalidPossessed';
            }
        case 'CivilianMilitia':
            return none; // No SFX found yet
        case 'Cyberus': // Codex
            switch (`SYNC_RAND(2)) {
                case 0:
                    return AkEvent'SoundX2CyberusFX.Cyberus_Ability_Teleport_In';
                default:
                    return AkEvent'SoundX2CyberusFX.Cyberus_Pod_Glitch_Long';
            }
        case 'Faceless':
            switch (`SYNC_RAND(5)) {
                case 0:
                    return AkEvent'SoundX2FacelessFX.FacelessCallOthers';
                case 1:
                    return AkEvent'SoundX2FacelessFX.FacelessGenericVox';
                case 2:
                    return AkEvent'SoundX2FacelessFX.FacelessGenericVoxShort';
                case 3:
                    return AkEvent'SoundX2FacelessFX.FacelessTakesDamage';
                default:
                    return AkEvent'SoundX2FacelessFX.FacelessDeath';
            }
        case 'Gatekeeper':
            switch (`SYNC_RAND(3)) {
                case 0:
                    return AkEvent'SoundX2GatekeeperFX.GatekeeperMoveBurst';
                case 1:
                    return AkEvent'SoundX2GatekeeperFX.GatekeeperProbe';
                default:
                    return AkEvent'SoundX2GatekeeperFX.GatekeeperMoveBurst';
            }
        case 'TheLost':
            switch (`SYNC_RAND(8)) {
                case 0:
                    return AkEvent'SoundX2ZombieFX.Lost_Howl';
                case 1:
                    return AkEvent'SoundX2ZombieFX.Lost_Howl_2D';
                case 2:
                    return AkEvent'SoundX2ZombieFX.Lost_Attack_Vox_PodReveal';
                case 3:
                    return AkEvent'SoundX2ZombieFX.Lost_DeathScream';
                case 4:
                    return AkEvent'SoundX2ZombieFX.Lost_Breathing_PodReveal';
                case 5:
                    return AkEvent'SoundX2ZombieFX.Lost_Reinforcements_Call';
                case 6:
                    return AkEvent'XPACK_SoundCharacterFX.TheLost_Attack_VOX';
                default:
                    return AkEvent'SoundX2ZombieFX.LostDasher_DashVox';
            }
        case 'Muton':
            switch (`SYNC_RAND(4)) {
                case 0:
                    return AkEvent'SoundX2MutonFX.Muton_Scream';
                case 1:
                    return AkEvent'SoundX2MutonFX.MutonDeathScream';
                case 2:
                    return SoundCue'SoundX2MutonFX.X2MutonHiddenMovementVox_Cue';
                default:
                    return AkEvent'SoundX2MutonFX.MutonTakesDamage';
            }
        case 'Sectoid':
            switch (`SYNC_RAND(3)) {
                case 0:
                    return SoundCue'SoundNewSectoidFX.SectoidVocalizationCue';
                case 1:
                    return SoundCue'SoundNewSectoidFX.SectoidTakesDmamgeCue'; // sic
                default:
                    return SoundCue'SoundNewSectoidFX.SectoidDeathScreamCue';
            }
        case 'Sectopod':
            switch (`SYNC_RAND(4)) {
                case 0:
                    return AkEvent'SoundX2SectopodFX.Sectopod_Speak';
                case 1:
                    return AkEvent'SoundX2SectopodFX.Sectopod_Stand2Crouch';
                case 2:
                    return AkEvent'SoundUnreal3DSounds.Unreal3DSounds_SectopodSteamBurst';
                default:
                    return AkEvent'SoundX2SectopodFX.Sectopod_Crouch2Stand';
            }
        case 'Shadowbind':
        case 'Spectre':
            switch (`SYNC_RAND(3)) {
                case 0:
                    return AkEvent'XPACK_SoundSpectreFX.Spectre_Dissolve_End';
                case 1:
                    return AkEvent'XPACK_SoundSpectreFX.Spectre_Horror_Recovery';
                case 2:
                    return AkEvent'XPACK_SoundSpectreFX.Spectre_Vanish_Start';
                default:
                    return AkEvent'XPACK_SoundSpectreFX.Spectre_Vanish_End';
            }
        case 'Viper':
        case 'ViperNeonate':
            switch (`SYNC_RAND(10)) {
                case 0:
                    return AkEvent'SoundX2ViperFX.Viper_Bind';
                case 1:
                    return AkEvent'SoundX2ViperFX.Viper_Death';
                case 2:
                    return AkEvent'SoundX2ViperFX.Viper_Vox_Pod_Reveals';
                case 3:
                    return AkEvent'SoundX2ViperFX.ViperMadHiss';
                case 4:
                    return AkEvent'SoundX2ViperFX.ViperVox_EngagingHostiles';
                case 5:
                    return AkEvent'SoundX2ViperFX.ViperVox_HaltStop';
                case 6:
                    return AkEvent'SoundX2ViperFX.ViperVox_Identify';
                case 7:
                    return AkEvent'SoundX2ViperFX.ViperVox_Moving';
                case 8:
                    return AkEvent'SoundX2ViperFX.ViperVox_RequestingReinforcements';
                default:
                    return AkEvent'SoundX2ViperFX.ViperVox_TargetSighted';
            }
        case 'ViperKing':
            switch (`SYNC_RAND(3)) {
                case 0:
                    return AkEvent'DLC_60_SoundViperKing.ViperKing_Hurt';
                case 1:
                    return AkEvent'DLC_60_SoundViperKing.ViperKing_MovementHiss';
                case 2:
                    return AkEvent'DLC_60_SoundViperKing.ViperKing_Reveal_Scream1';
                case 3:
                    return AkEvent'DLC_60_SoundViperKing.ViperKing_Reveal_Scream2';
                case 4:
                    return AkEvent'DLC_60_SoundViperKing.ViperKing_Scream';
            }
    }

    // Non-militia civilians don't have a CharacterGroupName
    if (XGUnit(Unit.GetVisualizer()).IsCivilianChar()) {
        return GetCivilianSound(Unit);
    }

    return none;
}

private function SoundCue LoadTwitchSoundCue(Name CueName) {
    return SoundCue(DynamicLoadObject("TwitchIntegration_UI." $ string(CueName), class'SoundCue'));
}

private function OnNarrativeCompleteCallback() {
	local UINarrativeMgr kNarrativeMgr;

    `TILOGCLS("Narrative is complete");

    // Normally when a conversation completes, if subtitles are enabled, the narrative manager waits to
    // end the conversation so the subtitles can last a little longer. This doesn't work well at all with
    // the way we're queuing conversations, so we cut it off. Otherwise the timer will fire and end our
    // next conversation (if there's one queued).
	kNarrativeMgr = `PRES.m_kNarrativeUIMgr;

    if (kNarrativeMgr.IsTimerActive('EndCurrentConversation')) {
        `TILOGCLS("EndCurrentConversation timer is active");
        //`TILOGCLS("Clearing EndCurrentConversation timer and ending conversation");
        //kNarrativeMgr.ClearTimer('EndCurrentConversation');
        //kNarrativeMgr.EndCurrentConversation();
    }
}

private function OverrideCommLinkFields() {
    local string UnitPortrait;
    local AkBaseSoundObject Sound;
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

    Unit = XComGameState_Unit(`XCOMHISTORY.GetGameStateForObjectID(PendingNarrativeItems[0].GameState.SendingUnitObjectID));

    // Swap in our XSay data. We aren't using CurrentOutput ourselves, but if the comm link UI refreshes for some reason,
    // we want to be sure our data is there. (Opening and closing the menu is one way this can happen.)
    kNarrativeMgr.CurrentOutput.strTitle = PendingNarrativeItems[0].GameState.Sender;
    kNarrativeMgr.CurrentOutput.strText = GetMessageBody(PendingNarrativeItems[0]);
    kNarrativeMgr.CurrentOutput.strImage = "img:///TwitchIntegration_UI.Icon_Twitch_3D";

    // Call the AS functions directly, because if we call AS_SetPortrait too much the UI gets weird and moves to the wrong part of the screen
    CommLink.AS_SetTitle(kNarrativeMgr.CurrentOutput.strTitle);
    CommLink.AS_SetText(kNarrativeMgr.CurrentOutput.strText);
    CommLink.AS_ShowSubtitles(); // since we have no audio, we need the text shown regardless of global subtitle settings

    // TODO: if on tac layer, we can still try to load a headshot if one exists
    if (Unit.IsSoldier() && `TI_IS_STRAT_GAME) {
		`HQPRES.GetPhotoboothAutoGen().AddHeadShotRequest(Unit.GetReference(), 512, 512, OnHeadshotReady, , , /* bHighPriority */ true);
		`HQPRES.GetPhotoboothAutoGen().RequestPhotos();
    }
    else {
        UnitPortrait = GetUnitPortrait(Unit);

        if (UnitPortrait != "") {
            kNarrativeMgr.CurrentOutput.strImage = "img:///" $ UnitPortrait;
            CommLink.AS_SetPortrait(kNarrativeMgr.CurrentOutput.strImage);
        }
    }

    // Now that we know our dialogue's on the UI, play the associated sound
    Sound = GetUnitSound(PendingNarrativeItems[0], Unit);

    if (Sound != none) {
        class'WorldInfo'.static.GetWorldInfo().PlaySoundBase(Sound, true);
    }

    PendingNarrativeItems.Remove(0, 1);

    if (PendingNarrativeItems.Length == 0) {
        // Don't call this again until another XSay state has been sent to the narrative manager
        `TISTATEMGR.ClearTimer(nameof(OverrideCommLinkFields), self);
    }
}

function XComNarrativeMoment PickNarrativeMoment(string Message) {
    local XComNarrativeMoment NarrativeMoment;

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

    return NarrativeMoment;
}

function string GetSoldierHeadshot(int UnitObjectID) {
    local Texture2D HeadshotTex;
	local XComGameState_CampaignSettings SettingsState;

	SettingsState = XComGameState_CampaignSettings(`XCOMHISTORY.GetSingleGameStateObjectForClass(class'XComGameState_CampaignSettings'));
    HeadshotTex = `XENGINE.m_kPhotoManager.GetHeadshotTexture(SettingsState.GameIndex, UnitObjectID, 512, 512);

    if (HeadshotTex != none) {
        return class'UIUtilities_Image'.static.ValidateImagePath(PathName(HeadshotTex));
    }

    return "";
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