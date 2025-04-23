class X2TwitchUtils extends Object;

var localized string strNameConflictTitle;
var localized string strNameConflictText;
var localized string strNameConflictAcceptButton;
var localized string strNameConflictCancelButton;

static function AddMessageToChatLog(string Sender, string Body, array<EmoteData> Emotes, optional XComGameState_Unit FromUnit, optional string MsgId) {
    local UIChatLog ChatLog;

    foreach `XCOMGAME.AllActors(class'UIChatLog', ChatLog) {
        break;
    }

    // Chat log might be shut off in config
    if (ChatLog == none) {
        return;
    }

    ChatLog.AddMessage(Sender, Body, Emotes, FromUnit, MsgId);
}

/// <summary>
/// Calculates the "natural" turn number, or in other words, the number of complete iterations of the player turn order.
/// For example, if the XCOM team has had 2 turns, and the alien team has only had 1, then only 1 turn is complete. This
/// is counted based on the number of turn start events for each team, rather than turn end.
/// </summary>
/// <remarks>The value returned from this function is 0-based, i.e. the first turn is turn 0.</remarks>
static function int CalculateCurrentNaturalTurnNumber()
{
    local int Index, NumPlayers, NumTurnStarts;
    local XComGameStateHistory History;
    local XComGameStateContext_TacticalGameRule Context;
    local XComGameState_Player PlayerState;
    local XComGameState_BattleData BattleData;

    // We can't assume XCOM is the first team to act because mods can change that,
    // so just look at the total number of players and turns
    History = `XCOMHISTORY;
    BattleData = XComGameState_BattleData(History.GetSingleGameStateObjectForClass(class'XComGameState_BattleData'));

    for (Index = 0; Index < BattleData.PlayerTurnOrder.Length; Index++)
    {
        PlayerState = XComGameState_Player(History.GetGameStateForObjectID(BattleData.PlayerTurnOrder[Index].ObjectID));

        if (PlayerState != None)
        {
            NumPlayers++;
        }
    }

    foreach History.IterateContextsByClassType(class'XComGameStateContext_TacticalGameRule', Context)
    {
        if (Context.GameRuleType == eGameRule_PlayerTurnBegin)
        {
            NumTurnStarts++;
        }
    }

    return NumTurnStarts / NumPlayers;
}

static function X2TwitchEventActionTemplate GetTwitchEventActionTemplate(Name TemplateName) {
    local X2TwitchEventActionTemplateManager TemplateMgr;

    TemplateMgr = class'X2TwitchEventActionTemplateManager'.static.GetTwitchEventActionTemplateManager();
    return TemplateMgr.FindTwitchEventActionTemplate(TemplateName);
}

static function XComGameState_Unit FindSourceUnitFromSpawnEffect(XComGameState_Unit SpawnedUnit, optional XComGameState GameState) {
    local int TargetObjID;
    local UnitValue UnitVal;
    local XComGameState_Unit Unit;

    TargetObjID = SpawnedUnit.GetReference().ObjectID;

    if (GameState != none) {
        foreach GameState.IterateByClassType(class'XComGameState_Unit', Unit) {
            Unit.GetUnitValue(class'X2Effect_SpawnUnit'.default.SpawnedUnitValueName, UnitVal);

            if (UnitVal.fValue > 0 && int(UnitVal.fValue) == TargetObjID) {
                return Unit;
            }
        }
    }
    else {
        foreach `XCOMHISTORY.IterateByClassType(class'XComGameState_Unit', Unit) {
            Unit.GetUnitValue(class'X2Effect_SpawnUnit'.default.SpawnedUnitValueName, UnitVal);

            if (UnitVal.fValue > 0 && int(UnitVal.fValue) == TargetObjID) {
                return Unit;
            }
        }
    }


    return none;
}

static function XComGameState_Unit FindUnitOwnedByViewer(string ViewerLogin) {
    local XComGameState_TwitchObjectOwnership OwnershipState;

    OwnershipState = class'XComGameState_TwitchObjectOwnership'.static.FindForUser(ViewerLogin);

    if (OwnershipState == none) {
        return none;
    }

    return XComGameState_Unit(`XCOMHISTORY.GetGameStateForObjectID(OwnershipState.OwnedObjectRef.ObjectID));
}

static function XComGameState_TwitchChatCommandTracking GetChatCommandTracking() {
	return XComGameState_TwitchChatCommandTracking(`XCOMHISTORY.GetSingleGameStateObjectForClass(class'XComGameState_TwitchChatCommandTracking', /* AllowNULL */ true));
}

static function int GetForceLevel() {
	local XComGameState_HeadquartersAlien AlienHQ;

    AlienHQ = XComGameState_HeadquartersAlien(`XCOMHISTORY.GetSingleGameStateObjectForClass(class'XComGameState_HeadquartersAlien'));

    if (AlienHQ == none) {
        `TILOG("WARNING: couldn't find an AlienHQ object in X2PollGroupTemplateManager!");
        return -100;
    }

    return AlienHQ.GetForceLevel();
}

static function XComGameState_Unit GetViewerUnitOnMission(string TwitchLogin) {
	local XComGameState_Unit Unit;
    local XGUnit UnitActor;

    if (`TI_IS_STRAT_GAME) {
        return none;
    }

    Unit = FindUnitOwnedByViewer(TwitchLogin);

    if (Unit == none) {
        return none;
    }

    // Make sure they're on the current mission
    foreach `XCOMGAME.AllActors(class'XGUnit', UnitActor) {
        if (UnitActor.ObjectID == Unit.GetReference().ObjectID) {
            return Unit;
        }
    }

    return none;
}

static function GiveAbilityToUnit(Name AbilityName, out XComGameState_Unit Unit, optional XComGameState NewGameState, optional int TurnsUntilAbilityExpires = 10000) {
	local XComGameStateHistory History;
	local X2TacticalGameRuleset TacticalRules;
    local StateObjectReference AbilityRef;
    local XComGameState_Ability AbilityState;
	local X2AbilityTemplate AbilityTemplate;
	local X2AbilityTemplateManager AbilityTemplateManager;
    local bool CreatedGameState;
	local bool UnitAlreadyHasAbility;

	AbilityTemplateManager = class'X2AbilityTemplateManager'.static.GetAbilityTemplateManager();
	AbilityTemplate = AbilityTemplateManager.FindAbilityTemplate(AbilityName);

	if (AbilityTemplate != None)
	{
		History = `XCOMHISTORY;
        TacticalRules = `TACTICALRULES;

        if (NewGameState == none) {
            NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Twitch Give Ability '" $ AbilityName $ "'");
            CreatedGameState = true;
        }

		Unit = XComGameState_Unit(NewGameState.ModifyStateObject(class'XComGameState_Unit', Unit.ObjectID));

		// See if the unit already has this ability
		UnitAlreadyHasAbility = (Unit.FindAbility(AbilityName).ObjectID > 0);

		if (!UnitAlreadyHasAbility) {
            `TILOG("Giving unit '" $ Unit.GetFullName() $ "' ability " $ AbilityName $ " for " $ TurnsUntilAbilityExpires $ " turns");
			AbilityRef = TacticalRules.InitAbilityForUnit(AbilityTemplate, Unit, NewGameState);

            if (AbilityRef.ObjectID != 0) {
                AbilityState = XComGameState_Ability(NewGameState.ModifyStateObject(class'XComGameState_Ability', AbilityRef.ObjectID));
                AbilityState.TurnsUntilAbilityExpires = TurnsUntilAbilityExpires;
            }

            if (CreatedGameState) {
			    TacticalRules.SubmitGameState(NewGameState);
            }
		}
		else if (CreatedGameState) {
			History.CleanupPendingGameState(NewGameState);
		}
	}
}

static function SyncUnitFlag(XComGameState_Unit Unit, optional XComGameState_TwitchObjectOwnership Ownership = none) {
    `TISTATEMGR.TwitchFlagMgr.AddOrUpdateFlag(Unit, Ownership);
}

// --------------------------
// Functions related to polls
static function XComGameState_TwitchEventPoll GetActivePoll() {
    local XComGameState_TwitchEventPoll PollGameState;

    PollGameState = GetMostRecentPoll();

    if (PollGameState != none && PollGameState.IsActive) {
        return PollGameState;
    }

    return none;
}

static function XComGameState_TwitchEventPoll GetMostRecentPoll() {
    local XComGameState_TwitchEventPoll PollGameState;

    PollGameState = XComGameState_TwitchEventPoll(`XCOMHISTORY.GetSingleGameStateObjectForClass(class'XComGameState_TwitchEventPoll', /* allowNULL */ true));

    return PollGameState;
}

static function PollChoice GetWinningPollChoice(TwitchPollModel PollModel, optional out int WinningIndex) {
    local int Index;
	local PollChoice CurrentOption;
	local PollChoice WinningOption;

    WinningIndex = 0;
	WinningOption = PollModel.Choices[0];

    for (Index = 0; Index < PollModel.Choices.Length; Index++) {
        CurrentOption = PollModel.Choices[Index];
		if (CurrentOption.NumVotes > WinningOption.NumVotes) {
            WinningIndex = Index;
			WinningOption = CurrentOption;
		}
	}

    return WinningOption;
}

static function X2PollChoiceTemplate GetPollChoiceTemplate(Name TemplateName) {
    local X2PollChoiceTemplateManager TemplateMgr;

    TemplateMgr = class'X2PollChoiceTemplateManager'.static.GetPollChoiceTemplateManager();
    return TemplateMgr.GetPollChoiceTemplate(TemplateName);
}

/// <summary>
/// Raises a dialog on the screen stating that the given viewer login is already in use by another unit.
/// </summary>
static function RaiseViewerLoginAlreadyInUseDialog(string ViewerLogin, string OriginalUnitName, StateObjectReference OriginalOwnershipStateRef, StateObjectReference TargetUnitStateObjectRef) {
    local UICallbackData_StateObjectReference CallbackData;
    local TDialogueBoxData DialogData;
    local string DialogText;

    CallbackData = new class'UICallbackData_StateObjectReference';
    CallbackData.ObjectRef = OriginalOwnershipStateRef;
    CallbackData.ObjectRef2 = TargetUnitStateObjectRef;

    DialogText = Repl(default.strNameConflictText, "<ViewerName/>", ViewerLogin);
    DialogText = Repl(DialogText, "<OriginalUnitName/>", OriginalUnitName);

    DialogData.eType = eDialog_Normal;
    DialogData.strTitle = default.strNameConflictTitle;
    DialogData.strText = DialogText;
    DialogData.strAccept = default.strNameConflictAcceptButton;
    DialogData.strCancel = default.strNameConflictCancelButton;

    DialogData.xUserData = CallbackData;
    DialogData.fnCallbackEx = OnCloseViewerLoginAlreadyInUseDialog;

    `PRESBASE.UIRaiseDialog(DialogData);
}

static function string SecondsToTimeString(int TotalSeconds) {
    local string Text;
    local int HoursPart, MinutesPart, SecondsPart;

    HoursPart = TotalSeconds / 3600;
    MinutesPart = TotalSeconds / 60;
    SecondsPart = TotalSeconds % 60;

    if (HoursPart > 0) {
        Text = HoursPart >= 10 ? string(HoursPart) : "0" $ string(HoursPart);
        Text $= ":";
    }

    Text $= MinutesPart >= 10 ? string(MinutesPart) : "0" $ string(MinutesPart);
    Text $= ":";

    Text $= SecondsPart >= 10 ? string(SecondsPart) : "0" $ string(SecondsPart);

    return Text;
}

static function bool TryPayStrategyCost(StrategyCost Cost) {
    local array<StrategyCostScalar> EmptyScalars;
    local XComGameState_HeadquartersXCom XComHQ;
	local XComGameState NewGameState;

    EmptyScalars.Length = 0; // silences a warning

    XComHQ = XComGameState_HeadquartersXCom(`XCOMHISTORY.GetSingleGameStateObjectForClass(class'XComGameState_HeadquartersXCom'));

    if (!XComHQ.CanAffordAllStrategyCosts(Cost, EmptyScalars)) {
        return false;
    }

    NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Twitch: Paying Strategy Cost");
    XComHQ = XComGameState_HeadquartersXCom(NewGameState.ModifyStateObject(class'XComGameState_HeadquartersXCom', XComHQ.ObjectID));

    XComHQ.PayStrategyCost(NewGameState, Cost, EmptyScalars);

    `GAMERULES.SubmitGameState(NewGameState);

    return true;
}

private static function OnCloseViewerLoginAlreadyInUseDialog(Name eAction, UICallbackData xUserData) {
    local string ViewerLogin;
    local UICallbackData_StateObjectReference CallbackData;
    local XComGameState_TwitchObjectOwnership OldOwnershipState;

    if (eAction != 'eUIAction_Accept') {
        return;
    }

    `TILOG("Replacing an existing unit ownership per the player's input");

    CallbackData = UICallbackData_StateObjectReference(xUserData);

    // Use the old ownership state to figure out the owner of the new unit, then get rid of it
    OldOwnershipState = XComGameState_TwitchObjectOwnership(`XCOMHISTORY.GetGameStateForObjectID(CallbackData.ObjectRef.ObjectID));
    ViewerLogin = OldOwnershipState.TwitchLogin;

    class'XComGameState_TwitchObjectOwnership'.static.DeleteOwnership(OldOwnershipState);

    // Now apply it to the newly-owned unit
    class'X2EventListener_TwitchNames'.static.AssignOwnership(ViewerLogin, CallbackData.ObjectRef2.ObjectID, , /* OverridePreviousOwnership */ true);
}