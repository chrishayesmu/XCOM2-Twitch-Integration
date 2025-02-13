class X2PollChoiceTemplate extends X2DataTemplate config(TwitchPolls);

var localized string FriendlyName; // Name to show the player in the poll panel
var localized string Explanation;  // Short description in the poll results telling what will happen

var config array<name> ActionNames; // The actions to take when this choice wins in a poll
var config array<name> ExclusiveWith; // This choice will not show up in the same poll as any of these choices

// -------------------------------------------------
function bool IsValid(bool IsStrategyLayer, bool IsTacticalLayer) {
	local X2TwitchEventActionTemplate Action;
    local name ActionName;

    if (!IsStrategyLayer && !IsTacticalLayer) {
        `TILOG("X2PollChoiceTemplate " $ DataName $ ": Never valid outside of strategy and tactical layers");
        return false;
    }

    if (ActionNames.Length == 0) {
        `TILOG("X2PollChoiceTemplate " $ DataName $ ": Template has no actions configured");
        return false;
    }

    // An event is valid for a poll if all of its actions are valid with no invoking unit
    foreach ActionNames(ActionName) {
        Action = class'X2TwitchUtils'.static.GetTwitchEventActionTemplate(ActionName);

        if (Action == none) {
            `TILOG("X2PollChoiceTemplate " $ DataName $ ": Template is not valid, because action " $ ActionName $ " could not be loaded");
            return false;
        }

        if (!Action.IsValid(/* InvokingUnit */ none)) {
            `TILOG("X2PollChoiceTemplate " $ DataName $ ": Template is not valid, because action " $ Action.DataName $ " was not valid");
            return false;
        }
    }

    return true;
}

function Resolve() {
	local X2TwitchEventActionTemplate Action;
    local name ActionName;

    foreach ActionNames(ActionName) {
        `TILOG("Resolving by calling action " $ ActionName);
        Action = class'X2TwitchUtils'.static.GetTwitchEventActionTemplate(ActionName);

        Action.Apply(/* InvokingUnit */ none);
    }
}