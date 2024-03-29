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

    // I don't know why the hell UE wouldn't let me do this as a ternary
    if (PollGameState != none && PollGameState.RemainingTurns > 0) {
        return PollGameState;
    }

    return none;
}

static function XComGameState_TwitchEventPoll GetMostRecentPoll() {
    local XComGameState_TwitchEventPoll PollGameState;

    PollGameState = XComGameState_TwitchEventPoll(`XCOMHISTORY.GetSingleGameStateObjectForClass(class'XComGameState_TwitchEventPoll', /* allowNULL */ true));

    return PollGameState;
}

static function EUIState GetPollColorState(ePollType PollType) {
	switch (PollType) {
		case ePollType_Providence:
			return eUIState_Good;
		case ePollType_Harbinger:
		case ePollType_Sabotage:
			return eUIState_Bad;
	}
}

static function string GetPollColor(ePollType PollType) {
	switch (PollType) {
		case ePollType_Providence:
			return class'UIUtilities_Colors'.const.GOOD_HTML_COLOR;
		case ePollType_Harbinger:
		case ePollType_Sabotage:
			return class'UIUtilities_Colors'.const.BAD_HTML_COLOR;
	}
}

static function PollChoice GetWinningPollChoice(XComGameState_TwitchEventPoll PollGameState, optional out int WinningIndex) {
    local int Index;
	local PollChoice CurrentOption;
	local PollChoice WinningOption;

    WinningIndex = 0;
	WinningOption = PollGameState.Choices[0];

    for (Index = 0; Index < PollGameState.Choices.Length; Index++) {
        CurrentOption = PollGameState.Choices[Index];
		if (CurrentOption.NumVotes > WinningOption.NumVotes) {
            WinningIndex = Index;
			WinningOption = CurrentOption;
		}
	}

    return WinningOption;
}

static function X2PollEventTemplate GetPollEventTemplate(Name TemplateName) {
    local X2EventListenerTemplateManager TemplateMgr;

    TemplateMgr = class'X2EventListenerTemplateManager'.static.GetEventListenerTemplateManager();
    return X2PollEventTemplate(TemplateMgr.FindEventListenerTemplate(TemplateName));
}