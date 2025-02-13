class X2TwitchUtils extends Object;

static function AddMessageToChatLog(string Sender, string Body, optional XComGameState_Unit FromUnit, optional string MsgId) {
    local UIChatLog ChatLog;

    foreach `XCOMGAME.AllActors(class'UIChatLog', ChatLog) {
        break;
    }

    // Chat log might be shut off in config
    if (ChatLog == none) {
        return;
    }

    ChatLog.AddMessage(Sender, Body, FromUnit, MsgId);
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

static function GiveAbilityToUnit(Name AbilityName, XComGameState_Unit Unit, optional XComGameState NewGameState, optional int TurnsUntilAbilityExpires) {
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
            `TILOG("Giving unit '" $ Unit.GetFullName() $ "' ability " $ AbilityName);
			AbilityRef = TacticalRules.InitAbilityForUnit(AbilityTemplate, Unit, NewGameState);

            if (AbilityRef.ObjectID != 0) {
                AbilityState = XComGameState_Ability(NewGameState.ModifyStateObject(class'XComGameState_Ability', AbilityRef.ObjectID));
                AbilityState.TurnsUntilAbilityExpires = TurnsUntilAbilityExpires > 0 ? TurnsUntilAbilityExpires : 100000;
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

static function ETeam WhoseTurnIsIt()
{
    local XComGameStateHistory History;
    local XComGameStateContext_TacticalGameRule Context;
    local XComGameState_Player PlayerState;

    History = `XCOMHISTORY;

    // Iterate history looking for a turn begin
    foreach History.IterateContextsByClassType(class'XComGameStateContext_TacticalGameRule', Context, /* DesiredReturnType */, /* IterateIntoThePast */ true)
    {
        if (Context.GameRuleType == eGameRule_PlayerTurnBegin)
        {
            PlayerState = XComGameState_Player(History.GetGameStateForObjectID(Context.PlayerRef.ObjectID));
            return PlayerState.TeamFlag;
        }
    }

    // For completeness
    return eTeam_None;
}