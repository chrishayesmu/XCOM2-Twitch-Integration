class X2TwitchUtils extends Object;

static function AddMessageToChatLog(string Sender, string Body, optional XComGameState_Unit FromUnit) {
    local UIChatLog ChatLog;

    foreach `XCOMGAME.AllActors(class'UIChatLog', ChatLog) {
        break;
    }

    // Chat log might be shut off in config
    if (ChatLog == none) {
        return;
    }

    ChatLog.AddMessage(Sender, Body, FromUnit);
}

static function TwitchStateManager GetStateManager() {
	local TwitchStateManager mgr;

	foreach `XCOMGAME.AllActors(class'TwitchStateManager', mgr) {
		break;
	}

	return mgr;
}

static function X2TwitchEventActionTemplate GetTwitchEventActionTemplate(Name TemplateName) {
    local X2EventListenerTemplateManager TemplateMgr;

    TemplateMgr = class'X2EventListenerTemplateManager'.static.GetEventListenerTemplateManager();
    return X2TwitchEventActionTemplate(TemplateMgr.FindEventListenerTemplate(TemplateName));
}

static function XComGameState_Unit FindUnitOwnedByViewer(string ViewerName) {
    local XComGameState_TwitchObjectOwnership OwnershipState;

    OwnershipState = class'XComGameState_TwitchObjectOwnership'.static.FindForUser(ViewerName);

    if (OwnershipState == none) {
        return none;
    }

    return XComGameState_Unit(`XCOMHISTORY.GetGameStateForObjectID(OwnershipState.OwnedObjectRef.ObjectID));
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
            NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("TwitchIntegration Give Ability '" $ AbilityName $ "'");
            CreatedGameState = true;
        }

		Unit = XComGameState_Unit(NewGameState.ModifyStateObject(class'XComGameState_Unit', Unit.ObjectID));

		// See if the unit already has this ability
		UnitAlreadyHasAbility = (Unit.FindAbility(AbilityName).ObjectID > 0);

		if (!UnitAlreadyHasAbility) {
            `LOG("Giving unit '" $ Unit.GetFullName() $ "' ability " $ AbilityName, , 'TwitchIntegration');
			AbilityRef = TacticalRules.InitAbilityForUnit(AbilityTemplate, Unit, NewGameState);

            if (AbilityRef.ObjectID != 0) {
                AbilityState = XComGameState_Ability(NewGameState.ModifyStateObject(class'XComGameState_Ability', AbilityRef.ObjectID));
                AbilityState.TurnsUntilAbilityExpires = TurnsUntilAbilityExpires > 0 ? TurnsUntilAbilityExpires : 10000;
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

/// <summary>
/// Creates and submits a game state with nothing in it. Primary for use with event triggers, which are not processed
/// until the next game state; base game logic always fires triggers along with a meaningful game state change, but that
/// isn't always possible for us with inherently transient objects like TCP connections.
/// </summary>
static function SubmitEmptyGameState() {
    local XComGameState NewGameState;

    NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Empty");

	`GAMERULES.SubmitGameState(NewGameState);
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