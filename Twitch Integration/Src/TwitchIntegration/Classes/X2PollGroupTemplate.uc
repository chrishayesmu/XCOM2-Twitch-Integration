/// <summary>
/// A poll group is a way of associating poll choices together to indicate that they should all be
/// part of a single Twitch poll. The poll group also controls the high level UX of the in-game poll
/// UI, including a poll's title, flavor text, and color scheme. Actual outcomes from the results of
/// a poll are not handled in the poll group; they are part of the X2PollChoiceTemplate.
/// </summary>
class X2PollGroupTemplate extends X2DataTemplate
    config(TwitchPolls);

struct PollEventOption {
    var name TemplateName;
    var int Weight;
    var X2PollChoiceTemplate Template; // to be populated at runtime

    structdefaultproperties
    {
        Weight=1
    }
};

var localized string PollTitle;    // Whenever this poll group template is used, this title will be set for the poll.
                                   // Must be 60 characters or less.

var localized string PollSubtitle; // Subtitle visible under the poll in-game. Not sent to the Twitch poll.

var localized string ResultsTitle; // Title displayed on the results screen when this poll group concludes.

var config int DurationInTurns;    // How many turns the poll should last. If not set, DurationInSeconds is used instead.

var config int DurationInSeconds;  // How many seconds the poll should last. If DurationInTurns is set, it will be used instead during
                                   // battles; on the strategy layer, DurationInSeconds is always used. If neither is set, a global default
                                   // number of seconds is used. Must be between 15 and 1800.

var config EUIState ColorState;    // The color state that determines the color of the overall poll panel.

var config string TextColor;       // The 6-digit hex color to use for text in the poll, with no leading # character.

var config array<PollEventOption> Choices; // A weighted pool of choices which can be pulled from when this poll group is selected.

var config int MinChoices;         // The minimum number of choices to include in the poll. Must be between 2 and 5.

var config int MaxChoices;         // The maximum number of choices to include in the poll. Must be between 2 and 5.

var config bool UseInTactical;     // If true, this poll can occur on the tactical layer.

var config bool UseInStrategy;     // If true, this poll can occur on the strategy layer.

var config int MinForceLevel;      // Minimum force level for this group to be selected.

var config int MaxForceLevel;      // Maximum force level for this group to be selected.

var config int Weight;             // Weight of this poll group relative to others.

/// <summary>
/// Whether this poll group is eligible to be selected in the context of the current campaign. In addition to the
/// group itself being eligible, this also checks if enough of its choices are valid to run a poll.
/// </summary>
function bool IsSelectable(bool IsStrategyLayer, bool IsTacticalLayer, int ForceLevel) {
    local int I, NumValidChoices;

    // Polls aren't supported outside of these two layers
    if (!IsStrategyLayer && !IsTacticalLayer) {
        return false;
    }

    if (IsStrategyLayer && !UseInStrategy) {
        return false;
    }

    if (IsTacticalLayer && !UseInTactical) {
        return false;
    }

    if (MinForcelevel >= 0 && ForceLevel < MinForcelevel) {
        return false;
    }

    if (MaxForceLevel >= 0 && ForceLevel > MaxForceLevel) {
        return false;
    }

    if (Weight <= 0) {
        return false;
    }

    CacheChoiceTemplates();

    // Make sure there's enough choices to actually fill a poll right now
    for (I = 0; I < Choices.Length && NumValidChoices < MinChoices; I++) {
        if (Choices[I].Template == none) {
            continue;
        }

        if (Choices[I].Template.IsSelectable(IsStrategyLayer, IsTacticalLayer, ForceLevel)) {
            NumValidChoices++;
        }
    }

    if (NumValidChoices < MinChoices) {
        return false;
    }

    return true;
}

/// <summary>
/// Whether the configuration of this poll group is valid.
/// </summary>
function bool IsValid() {
    local string ErrorMessage;

    if (PollTitle == "" || Len(PollTitle) > 60) {
        ErrorMessage = "PollTitle must be between 1 and 60 characters long";
    }
    else if (Choices.Length < 2) {
        ErrorMessage = "Must contain at least 2 Choices";
    }
    else if (!UseInTactical && !UseInStrategy) {
        ErrorMessage = "Poll must be enabled in tactical layer, strategy layer, or both";
    }
    else if (MinChoices < 2 || MinChoices > 5 || MaxChoices < 2 || MaxChoices > 5) {
        ErrorMessage = "MinChoices and MaxChoices must be between 2 and 5";
    }
    else if (DurationInSeconds > 0 && (DurationInSeconds < 15 || DurationInSeconds > 1800)) {
        ErrorMessage = "DurationInSeconds must be between 15 and 1800 if it is set";
    }
    else if (MinForcelevel >= 0 && MaxForceLevel >= 0 && MinForcelevel > MaxForceLevel) {
        ErrorMessage = "MinForceLevel cannot be greater than MaxForceLevel";
    }

    if (ErrorMessage != "") {
        `TILOG("WARNING: X2PollGroupTemplate " $ DataName $ " is invalid: " $ ErrorMessage);
        return false;
    }

    return true;
}

function array<X2PollChoiceTemplate> RollForChoices(int NumChoices) {
    local bool IsStrategyLayer, IsTacticalLayer;
    local array<X2PollChoiceTemplate> SelectedChoices;
    local array<PollEventOption> PossibleChoices;
    local X2PollChoiceTemplate Template;
    local int I, ForceLevel;

    CacheChoiceTemplates();

    IsStrategyLayer = `TI_IS_STRAT_GAME;
    IsTacticalLayer = `TI_IS_TAC_GAME;
    ForceLevel = class'X2TwitchUtils'.static.GetForceLevel();

    `TILOG(DataName $ ": Rolling for " $ NumChoices $ " choices. " $ `SHOWVAR(IsStrategyLayer) @ `SHOWVAR(IsTacticalLayer) @ `SHOWVAR(ForceLevel));

    PossibleChoices = Choices;

    for (I = PossibleChoices.Length - 1; I >= 0; I--) {
        if (!PossibleChoices[I].Template.IsSelectable(IsStrategyLayer, IsTacticalLayer, ForceLevel))
        {
            PossibleChoices.Remove(I, 1);
        }
    }

    while (SelectedChoices.Length < NumChoices) {
        if (PossibleChoices.Length == 0) {
            `TILOG("WARNING: while selecting choices for the poll " $ DataName $ ", ran out of choices to choose from after picking " $ SelectedChoices.Length $ " of " $ NumChoices);
            break;
        }

        I = SelectWeightedChoice(PossibleChoices);
        Template = PossibleChoices[I].Template;

        SelectedChoices.AddItem(Template);
        PossibleChoices.Remove(I, 1);

        // Check if the new event is mutually exclusive with any others, and remove them if so
        for (I = PossibleChoices.Length - 1; I >= 0; I--) {
            if (Template.ExclusiveWith.Find(PossibleChoices[I].TemplateName) != INDEX_NONE || PossibleChoices[I].Template.ExclusiveWith.Find(Template.DataName) != INDEX_NONE)
            {
                PossibleChoices.Remove(I, 1);
            }
        }
    }

    if (SelectedChoices.Length < 2) {
        `TILOG("Couldn't come up with enough valid poll choices to run a poll");
        SelectedChoices.Length = 0;
    }

    return SelectedChoices;
}

function int RollForNumberOfChoices() {
    return MinChoices + Rand(MaxChoices - MinChoices + 1);
}

private function CacheChoiceTemplates() {
    local X2PollChoiceTemplateManager TemplateMgr;
    local int I;

    TemplateMgr = class'X2PollChoiceTemplateManager'.static.GetPollChoiceTemplateManager();

    for (I = 0; I < Choices.Length; I++) {
        if (Choices[I].Template != none) {
            continue;
        }

        Choices[I].Template = TemplateMgr.GetPollChoiceTemplate(Choices[I].TemplateName);
    }
}

private static function int SelectWeightedChoice(array<PollEventOption> FromChoices) {
    local int TotalWeight, I, RolledWeight;

    for (I = 0; I < FromChoices.Length; I++) {
        TotalWeight += FromChoices[I].Weight;
    }

    RolledWeight = Rand(TotalWeight);
    TotalWeight = 0;

    for (I = 0; I < FromChoices.Length; I++) {
        TotalWeight += FromChoices[I].Weight;

        if (RolledWeight <= TotalWeight) {
            return I;
        }
    }

    return FromChoices.Length - 1;
}