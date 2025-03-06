class TwitchChatCommand_RollTheDice extends TwitchChatCommand;

// There must be at least this many valid options in order to roll the dice
const MIN_OPTIONS_TO_ROLL = 5;

struct RtdOption {
    var name ActionName;
    var string FriendlyName;
    var int Weight;
    var X2TwitchEventActionTemplate ActionTemplate; // cached at runtime

    structdefaultproperties
    {
        Weight=1
    }
};

var config bool BalanceOptions;
var config array<RtdOption> PositiveOptions;
var config array<RtdOption> NegativeOptions;

function Invoke(string CommandAlias, string Body, string MessageId, TwitchChatter Viewer) {
    local XComGameState NewGameState;
    local XComGameState_TwitchRollTheDice RtdGameState;
    local XComGameState_Unit UnitState;
	local XComGameStateContext_ChangeContainer NewContext;
    local array<RtdOption> ValidPositiveOptions, ValidNegativeOptions, AllOptions;
    local array<string> OptionFriendlyNames;
    local int I, TotalPositiveWeight, TotalNegativeWeight, TargetWeight;

    CacheTemplates();

    UnitState = class'X2TwitchUtils'.static.GetViewerUnitOnMission(Viewer.Login);

    ValidPositiveOptions = FilterOptions(default.PositiveOptions, UnitState, TotalPositiveWeight);
    ValidNegativeOptions = FilterOptions(default.NegativeOptions, UnitState, TotalNegativeWeight);

    `TILOG("There are " $ ValidPositiveOptions.Length $ " positive and " $ ValidNegativeOptions.Length $ " negative options in the pool (before potential balancing)");
    `TILOG("Total positive weight is " $ TotalPositiveWeight $ " and total negative weight is " $ TotalNegativeWeight);

    if (BalanceOptions) {
        TargetWeight = Min(TotalPositiveWeight, TotalNegativeWeight);

        if (TargetWeight == 0) {
            `TILOG("Unable to balance RTD options because total target weight is 0. Total positive weight: " $ TotalPositiveWeight $ "; total negative weight: " $ TotalNegativeWeight);
            return;
        }

        `TILOG("Attempting to balance options to a target weight of " $ TargetWeight);

        while (TotalPositiveWeight > TargetWeight) {
            I = Rand(ValidPositiveOptions.Length);
            TotalPositiveWeight -= ValidPositiveOptions[I].Weight;
            ValidPositiveOptions.Remove(i, 1);
        }

        while (TotalNegativeWeight > TargetWeight) {
            I = Rand(ValidNegativeOptions.Length);
            TotalNegativeWeight -= ValidNegativeOptions[I].Weight;
            ValidNegativeOptions.Remove(i, 1);
        }

        `TILOG("Post-balancing: there are " $ ValidPositiveOptions.Length $ " positive and " $ ValidNegativeOptions.Length $ " negative options in the pool");
        `TILOG("Post-balancing: total positive weight is " $ TotalPositiveWeight $ " and total negative weight is " $ TotalNegativeWeight);
    }

    if (ValidPositiveOptions.Length + ValidNegativeOptions.Length < MIN_OPTIONS_TO_ROLL) {
        `TILOG("Not enough options available to roll the dice; need at least " $ MIN_OPTIONS_TO_ROLL $ " in the pool");
        return;
    }

    for (I = 0; I < ValidPositiveOptions.Length; I++) {
        AllOptions.AddItem(ValidPositiveOptions[I]);
        OptionFriendlyNames.AddItem(ValidPositiveOptions[I].FriendlyName);
    }

    for (I = 0; I < ValidNegativeOptions.Length; I++) {
        AllOptions.AddItem(ValidNegativeOptions[I]);
        OptionFriendlyNames.AddItem(ValidNegativeOptions[I].FriendlyName);
    }

	NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Roll The Dice from " $ Viewer.Login);

	RtdGameState = XComGameState_TwitchRollTheDice(CreateChatCommandGameState(class'XComGameState_TwitchRollTheDice', NewGameState, Body, MessageId, Viewer));
    RtdGameState.PossibleActions = OptionFriendlyNames;
    RtdGameState.SelectedActionIndex = SelectWeightedChoice(AllOptions);
    RtdGameState.SelectedActionTemplateName = AllOptions[RtdGameState.SelectedActionIndex].ActionName;

    NewContext = XComGameStateContext_ChangeContainer(NewGameState.GetContext());
    NewContext.BuildVisualizationFn = BuildVisualization;

    `TILOG("Submitting game state with winning action " $ RtdGameState.SelectedActionTemplateName);

    `GAMERULES.SubmitGameState(NewGameState);
}

protected function BuildVisualization(XComGameState VisualizeGameState) {
    local VisualizationActionMetadata ActionMetadata;
	local XComGameState_TwitchRollTheDice RtdState;

	foreach VisualizeGameState.IterateByClassType(class'XComGameState_TwitchRollTheDice', RtdState) {
		break;
	}

    ActionMetadata.StateObject_OldState = none;
	ActionMetadata.StateObject_NewState = RtdState;

    class'X2Action_ShowRollTheDiceScreen'.static.AddToVisualizationTree(ActionMetadata, VisualizeGameState.GetContext());
}

protected function CacheTemplates() {
    local X2TwitchEventActionTemplateManager TemplateMgr;
    local int I;

    TemplateMgr = class'X2TwitchEventActionTemplateManager'.static.GetTwitchEventActionTemplateManager();

    for (I = 0; I < default.PositiveOptions.Length; I++) {
        if (default.PositiveOptions[I].ActionTemplate == none) {
            default.PositiveOptions[I].ActionTemplate = TemplateMgr.FindTwitchEventActionTemplate(default.PositiveOptions[I].ActionName);
        }
    }

    for (I = 0; I < default.NegativeOptions.Length; I++) {
        if (default.NegativeOptions[I].ActionTemplate == none) {
            default.NegativeOptions[I].ActionTemplate = TemplateMgr.FindTwitchEventActionTemplate(default.NegativeOptions[I].ActionName);
        }
    }
}

protected function array<RtdOption> FilterOptions(array<RtdOption> Options, XComGameState_Unit UnitState, out int TotalWeight) {
    local int I;
    local array<RtdOption> ValidOptions;

    TotalWeight = 0;

    for (I = 0; I < Options.Length; I++) {
        if (Options[I].ActionTemplate == none) {
            continue;
        }

        if (Options[I].ActionTemplate.IsValid(UnitState)) {
            ValidOptions.AddItem(Options[I]);
            TotalWeight += Options[I].Weight;
        }
    }

    return ValidOptions;
}

protected static function int SelectWeightedChoice(array<RtdOption> FromChoices) {
    local int TotalWeight, I, RolledWeight;

    for (I = 0; I < FromChoices.Length; I++) {
        TotalWeight += FromChoices[I].Weight;
    }

    RolledWeight = Rand(TotalWeight);
    `TILOG("RolledWeight: " $ RolledWeight $ " out of " $ TotalWeight);

    TotalWeight = 0;

    for (I = 0; I < FromChoices.Length; I++) {
        TotalWeight += FromChoices[I].Weight;

        if (RolledWeight <= TotalWeight) {
            return I;
        }
    }

    return FromChoices.Length - 1;
}