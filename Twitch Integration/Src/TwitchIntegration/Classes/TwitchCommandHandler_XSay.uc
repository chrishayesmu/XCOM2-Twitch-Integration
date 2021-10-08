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
    var bool bHasBeenSentToNarrativeMgr;
    var bool bUnitWasDead;
};

const MaxFlyoverLength = 45;
const MaxToastLength = 40;
const MaxNarrativeQueueLength = 5;

var private array<TNarrativeQueueItem> PendingNarrativeItems;
var private XComNarrativeMoment NarrativeMoment;

function Initialize(TwitchStateManager StateMgr) {
    local Object ThisObj;

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
        NarrativeItem.bHasBeenSentToNarrativeMgr = false;
        NarrativeItem.bUnitWasDead = Unit.IsDead();

        // TODO: on tac layer move this to visualization so it lines up with the other vis
        // TODO don't set timer if it's already on
        PendingNarrativeItems.AddItem(NarrativeItem);
        StateMgr.SetTimer(0.1, /* inbLoop */ true, nameof(EnqueueNextCommLink), self);
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

private function EnqueueNextCommLink() {
	local UINarrativeMgr kNarrativeMgr;

    if (PendingNarrativeItems.Length == 0) {
        `TILOGCLS("EnqueueNextCommLink: No XSays are pending display; clearing timers");
        `TISTATEMGR.ClearTimer(nameof(EnqueueNextCommLink), self);

        return;
    }

    if (PendingNarrativeItems[0].GameState.bMessageDeleted) {
        `TILOGCLS("Next narrative item has been deleted from Twitch; dequeuing it");
        PendingNarrativeItems.Remove(0, 1);

        return;
    }

    if (PendingNarrativeItems[0].bHasBeenSentToNarrativeMgr) {
        return;
    }

	kNarrativeMgr = `PRES.m_kNarrativeUIMgr;

    if (kNarrativeMgr.AnyActiveConversations()) {
        `TILOGCLS("Active conversations found, not queuing XSay yet");
        return;
    }

    // We're clear to add our message now, but don't remove it from queue; that's the job of OverrideCommLinkFields
    if (NarrativeMoment == none) {
        NarrativeMoment = XComNarrativeMoment(DynamicLoadObject("TwitchIntegration_UI.XSayBlank", class'XComNarrativeMoment'));
    }

    PendingNarrativeItems[0].bHasBeenSentToNarrativeMgr = true;

    `TILOGCLS("EnqueueNextCommLink: sending NarrativeMoment");
    `PRESBASE.UINarrative(NarrativeMoment, /* kFocusActor */ , OnNarrativeCompleteCallback);

    `TISTATEMGR.SetTimer(0.1, /* inbLoop */ true, nameof(OverrideCommLinkFields), self);
    `TISTATEMGR.ClearTimer(nameof(EnqueueNextCommLink), self);
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
        `TILOGCLS("Soldier passed to GetUnitPortrait. This should be handled earlier!");
        return "";
    }

    CharGroupName = Unit.GetMyTemplate().CharacterGroupName;

    if (CharGroupName == 'PsiZombie' || CharGroupName == 'SpectralZombie') {
        `TILOGCLS("Looking for source unit for char group " $ CharGroupName);
        SourceUnit = class'X2TwitchUtils'.static.FindSourceUnitFromSpawnEffect(Unit);

        if (SourceUnit != none) {
            CharGroupName = SourceUnit.GetMyTemplate().CharacterGroupName;
            `TILOGCLS("Found source unit with group " $ CharGroupName);
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
        case 'Shadowbind': // Shadow of a soldier created by a Spectre; ideally would use soldier's headshot but Spectre's okay for now
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

private function AkBaseSoundObject GetUnitSound(TNarrativeQueueItem NarrativeItem, XComGameState_Unit Unit) {
    local bool bUnitIsFemale;
    local Name CharGroupName;

    if (NarrativeItem.GameState.MessageBody ~= "bogos binted" || NarrativeItem.GameState.MessageBody ~= "bogos binted?") {
        return LoadTwitchSoundCue('Bogos_Binted_Cue');
    }
    else if (NarrativeItem.GameState.MessageBody ~= "crum") {
        return LoadTwitchSoundCue('Crum_Cue');
    }
    else if (NarrativeItem.GameState.MessageBody ~= "crumming") {
        return LoadTwitchSoundCue('Crumming_Cue');
    }
    else if (NarrativeItem.GameState.MessageBody ~= "oh my god i'm fucking crumming") {
        return LoadTwitchSoundCue('OhMyGodImFuckingCrumming_Cue');
    }

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
    if (Unit.IsCivilian()) {
        // TODO: these screams are going to get old really fast
        switch (`SYNC_RAND(3)) {
            case 0:
                return bUnitIsFemale ? SoundCue'SoundX2CharacterFX.CivilianScaredScreamFemale_Cue' : SoundCue'SoundX2CharacterFX.CivilianScaredScreamMale_Cue';
            case 1:
                return bUnitIsFemale ? SoundCue'SoundCivilianFemaleScreams.CivilianFemaleScreamsCue' : SoundCue'SoundCivilianMaleScreams.CivilianMaleScreamsCue';
            default:
                return bUnitIsFemale ? SoundCue'SoundCivilianFemaleScreams.CivFemaleScreamsOffscreenCue' : SoundCue'SoundCivilianMaleScreams.CivMaleScreamsOffscreenCue';
        }
    }

    return none;
}

private function SoundCue LoadTwitchSoundCue(Name CueName) {
    return SoundCue(DynamicLoadObject("TwitchIntegration_UI." $ string(CueName), class'SoundCue'));
}

private function OnNarrativeCompleteCallback() {
	local UINarrativeMgr kNarrativeMgr;

    `TILOGCLS("Narrative is complete. Dequeuing item and resetting timer");

    // Normally when a conversation completes, if subtitles are enabled, the narrative manager waits to
    // end the conversation so the subtitles can last a little longer. This doesn't work well at all with
    // the way we're queuing conversations, so we cut it off. Otherwise the timer will fire and end our
    // next conversation (if there's one queued).
	kNarrativeMgr = `PRES.m_kNarrativeUIMgr;

    if (kNarrativeMgr.IsTimerActive('EndCurrentConversation')) {
        `TILOGCLS("Clearing EndCurrentConversation timer and ending conversation");
        kNarrativeMgr.ClearTimer('EndCurrentConversation');
        kNarrativeMgr.EndCurrentConversation();
    }

    PendingNarrativeItems.Remove(0, 1);

    if (PendingNarrativeItems.Length > 0) {
        `TISTATEMGR.SetTimer(0.1, /* inbLoop */ true, nameof(EnqueueNextCommLink), self);
    }
}

private function OverrideCommLinkFields() {
    local string UnitPortrait;
    local AkBaseSoundObject Sound;
    local UINarrativeCommLink CommLink;
	local UINarrativeMgr kNarrativeMgr;
    local XComGameState_Unit Unit;

    `TILOGCLS("In OverrideCommLinkFields");

    if (PendingNarrativeItems.Length == 0) {
        `TILOGCLS("No XSays are pending display; clearing timer");
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
        `TILOGCLS("Requesting soldier headshot");
		`HQPRES.GetPhotoboothAutoGen().AddHeadShotRequest(Unit.GetReference(), 512, 512, OnHeadshotReady, , , /* bHighPriority */ true);
		`HQPRES.GetPhotoboothAutoGen().RequestPhotos();
    }
    else {
        UnitPortrait = GetUnitPortrait(Unit);
        `TILOGCLS("Using unit portrait: " $ UnitPortrait);

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

    // Don't call this again until another XSay state has been sent to the narrative manager
    `TISTATEMGR.ClearTimer(nameof(OverrideCommLinkFields), self);
}

simulated function OnHeadshotReady(StateObjectReference UnitRef) {
    local Texture2D HeadshotTex;
    local UINarrativeCommLink CommLink;
	local UINarrativeMgr kNarrativeMgr;
	local XComGameState_CampaignSettings SettingsState;

    CommLink = `PRESBASE.GetUIComm();
	kNarrativeMgr = CommLink.Movie.Pres.m_kNarrativeUIMgr;

	SettingsState = XComGameState_CampaignSettings(`XCOMHISTORY.GetSingleGameStateObjectForClass(class'XComGameState_CampaignSettings'));
    HeadshotTex = `XENGINE.m_kPhotoManager.GetHeadshotTexture(SettingsState.GameIndex, UnitRef.ObjectID, 512, 512);

    kNarrativeMgr.CurrentOutput.strImage = class'UIUtilities_Image'.static.ValidateImagePath(PathName(HeadshotTex));

    `TILOGCLS("Headshot ready, updating display; kNarrativeMgr.CurrentOutput.fDuration = " $ kNarrativeMgr.CurrentOutput.fDuration);
    CommLink.AS_SetPortrait(kNarrativeMgr.CurrentOutput.strImage);
}