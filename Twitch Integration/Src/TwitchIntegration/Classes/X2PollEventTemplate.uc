// This class does not use any event listener logic, but being part of a preset template type
// gives us access to the associated template manager to retrieve instances by name.
class X2PollEventTemplate extends X2EventListenerTemplate config(TwitchEvents);

enum ePollType {
	ePollType_Harbinger,
	ePollType_Providence,
	ePollType_Reinforcement,
	ePollType_Sabotage,
	ePollType_Serendipity
};

var localized string FriendlyName; // Name to show the player in the poll panel
var localized string Explanation; // Short description in the poll results telling what will happen

var config ePollType UseInPollType; // Which type of poll this can appear in
var config int Weight; // The weighted probability of this event appearing in a poll, compared to other options of the same poll type
var config array<name> ActionNames; // The actions to take when this event wins in a poll (always occurring at the start of the player's turn)
var config array<name> ExclusiveWith; // This poll event will not show up in the same poll as any of these events

// -------------------------------------------------
function bool IsValid() {
	local X2TwitchEventActionTemplate Action;
    local name ActionName;

    // An event is valid for a poll if all of its actions are valid with no invoking unit
    foreach ActionNames(ActionName) {
        Action = class'X2TwitchUtils'.static.GetTwitchEventActionTemplate(ActionName);

        if (!Action.IsValid(/* InvokingUnit */ none)) {
            `TILOG("Action " $ Action.Name $ " was not valid");
            return false;
        }
    }

    return true;
}

function Resolve(XComGameState_TwitchEventPoll PollGameState) {
	local X2TwitchEventActionTemplate Action;
    local name ActionName;

    foreach ActionNames(ActionName) {
        `TILOG("Resolving by calling action " $ ActionName);
        Action = class'X2TwitchUtils'.static.GetTwitchEventActionTemplate(ActionName);
        `assert(Action != none);
        Action.Apply(/* InvokingUnit */, PollGameState);
    }
}