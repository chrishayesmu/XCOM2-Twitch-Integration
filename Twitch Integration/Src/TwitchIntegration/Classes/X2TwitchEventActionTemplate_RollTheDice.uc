class X2TwitchEventActionTemplate_RollTheDice extends X2TwitchEventActionTemplate_TargetsUnits;

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

var config array<RtdOption> PositiveOptions;
var config array<RtdOption> NegativeOptions;

function Apply(optional XComGameState_Unit InvokingUnit) {
    local XComGameState NewGameState;
    local XComGameState_TwitchRollTheDice RtdGameState;
    local XComGameState_Unit Unit;
	local XComGameStateContext_ChangeContainer NewContext;
    local X2TwitchEventActionTemplate ActionTemplate;
    local array<XComGameState_Unit> Targets;
    local array<RtdOption> ValidPositiveOptions, ValidNegativeOptions, AllOptions;
    local array<string> OptionFriendlyNames;
    local int I, TotalPositiveWeight, TotalNegativeWeight;
    local bool DidBalance;

    CacheTemplates();

    Targets = FindTargets(InvokingUnit);

    foreach Targets(Unit) {
        // Make sure the target is still valid; a previous RTD outcome may have invalidated them
        // (e.g. collateral damage from someone else's explosion)
        if (!IsValidTarget(Unit)) {
            `TILOG("Target " $ Unit.GetFullName() $ " is not valid, skipping");
            continue;
        }

        ValidPositiveOptions = FilterOptions(PositiveOptions, Unit, TotalPositiveWeight);
        ValidNegativeOptions = FilterOptions(NegativeOptions, Unit, TotalNegativeWeight);

        `TILOG("There are " $ ValidPositiveOptions.Length $ " positive and " $ ValidNegativeOptions.Length $ " negative options in the pool for unit " $ Unit.GetFullName() $ " (before potential balancing)");
        `TILOG("Total positive weight is " $ TotalPositiveWeight $ " and total negative weight is " $ TotalNegativeWeight);

        if (`TI_CFG(bRtdBalanceOptions)) {
            DidBalance = BalanceOptionArrays(ValidPositiveOptions, ValidNegativeOptions, TotalPositiveWeight, TotalNegativeWeight);

            // If for some reason we can't balance, skip this unit
            if (!DidBalance) {
                `TILOG("Failed to balance options, skipping unit");
                continue;
            }
        }

        if (ValidPositiveOptions.Length + ValidNegativeOptions.Length < MIN_OPTIONS_TO_ROLL) {
            `TILOG("Not enough options available to roll the dice; need at least " $ MIN_OPTIONS_TO_ROLL $ " in the pool");
            continue;
        }

        AllOptions.Length = 0;

        for (I = 0; I < ValidPositiveOptions.Length; I++) {
            AllOptions.AddItem(ValidPositiveOptions[I]);
            OptionFriendlyNames.AddItem(ValidPositiveOptions[I].FriendlyName);
        }

        for (I = 0; I < ValidNegativeOptions.Length; I++) {
            AllOptions.AddItem(ValidNegativeOptions[I]);
            OptionFriendlyNames.AddItem(ValidNegativeOptions[I].FriendlyName);
        }

        NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Twitch Roll the Dice");
        RtdGameState = XComGameState_TwitchRollTheDice(NewGameState.CreateNewStateObject(class'XComGameState_TwitchRollTheDice'));
        RtdGameState.TargetUnitObjectID = Unit.GetReference().ObjectID;
        RtdGameState.PossibleActions = OptionFriendlyNames;
        RtdGameState.SelectedActionIndex = SelectWeightedChoice(AllOptions);
        RtdGameState.SelectedActionTemplateName = AllOptions[RtdGameState.SelectedActionIndex].ActionName;

        if (RtdGameState.SelectedActionIndex < ValidPositiveOptions.Length) {
            RtdGameState.OutcomeType = eRTDO_Positive;
        }
        else {
            RtdGameState.OutcomeType = eRTDO_Negative;
        }

        NewContext = XComGameStateContext_ChangeContainer(NewGameState.GetContext());
        NewContext.BuildVisualizationFn = BuildVisualization;

        `TILOG("Submitting game state with winning action " $ RtdGameState.SelectedActionTemplateName);
        `GAMERULES.SubmitGameState(NewGameState);

        ActionTemplate = class'X2TwitchUtils'.static.GetTwitchEventActionTemplate(RtdGameState.SelectedActionTemplateName);
        ActionTemplate.Apply(Unit);
    }
}

protected function bool BalanceOptionArrays(out array<RtdOption> ValidPositiveOptions, out array<RtdOption> ValidNegativeOptions, int TotalPositiveWeight, int TotalNegativeWeight) {
    local int I, TargetWeight;

    TargetWeight = Min(TotalPositiveWeight, TotalNegativeWeight);

    if (TargetWeight == 0) {
        `TILOG("Unable to balance RTD options because total target weight is 0. Total positive weight: " $ TotalPositiveWeight $ "; total negative weight: " $ TotalNegativeWeight);
        return false;
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

    return true;
}

protected function BuildVisualization(XComGameState VisualizeGameState) {
    local EUIState BannerState;
    local VisualizationActionMetadata ActionMetadata;
    local XComGameState_TwitchObjectOwnership OwnershipState;
	local XComGameState_TwitchRollTheDice RtdState;
    local X2Action_PlayMessageBanner MessageAction;
    local string BannerText;

	foreach VisualizeGameState.IterateByClassType(class'XComGameState_TwitchRollTheDice', RtdState) {
		break;
	}

    ActionMetadata.StateObject_OldState = none;
	ActionMetadata.StateObject_NewState = RtdState;
    ActionMetadata.VisualizeActor = `XCOMHISTORY.GetVisualizer(RtdState.TargetUnitObjectID);

    if (`TI_CFG(bRtdQuickMode)) {
        OwnershipState = class'XComGameState_TwitchObjectOwnership'.static.FindForObject(RtdState.TargetUnitObjectID);
        BannerState = RtdState.OutcomeType == eRTDO_Positive ? eUIState_Good : eUIState_Bad;
        BannerText = Repl(class'XComGameState_TwitchRollTheDice'.default.strBannerText, "<ViewerName/>", OwnershipState.TwitchLogin);

        MessageAction = X2Action_PlayMessageBanner(class'X2Action_PlayMessageBanner'.static.AddToVisualizationTree(ActionMetadata, VisualizeGameState.GetContext()));
        MessageAction.AddMessageBanner(class'XComGameState_TwitchRollTheDice'.default.strBannerTitle, /* IconPath */ "", RtdState.PossibleActions[RtdState.SelectedActionIndex], BannerText, BannerState);
    }
    else {
        class'X2Action_ShowRollTheDiceScreen'.static.AddToVisualizationTree(ActionMetadata, VisualizeGameState.GetContext());
    }
}

protected function CacheTemplates() {
    local X2TwitchEventActionTemplateManager TemplateMgr;
    local int I;

    TemplateMgr = class'X2TwitchEventActionTemplateManager'.static.GetTwitchEventActionTemplateManager();

    for (I = 0; I < PositiveOptions.Length; I++) {
        if (PositiveOptions[I].ActionTemplate == none) {
            PositiveOptions[I].ActionTemplate = TemplateMgr.FindTwitchEventActionTemplate(PositiveOptions[I].ActionName);
        }
    }

    for (I = 0; I < NegativeOptions.Length; I++) {
        if (NegativeOptions[I].ActionTemplate == none) {
            NegativeOptions[I].ActionTemplate = TemplateMgr.FindTwitchEventActionTemplate(NegativeOptions[I].ActionName);
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