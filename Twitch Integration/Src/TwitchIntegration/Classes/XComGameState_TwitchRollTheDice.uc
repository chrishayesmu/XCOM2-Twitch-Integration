class XComGameState_TwitchRollTheDice extends XComGameState_BaseObject;

enum ERollTheDiceOutcomeType {
    eRTDO_Positive,
    eRTDO_Negative
};

var localized string strBannerTitle;
var localized string strBannerText;

var int TargetUnitObjectID; // Object ID of the unit being targeted
var array<string> PossibleActions; // Friendly names of all of the actions which were valid for this roll, to show on the UI
var int SelectedActionIndex; // The index of the action which was selected
var name SelectedActionTemplateName; // Template name of the action to execute
var ERollTheDiceOutcomeType OutcomeType; // Whether this was a good or bad outcome

defaultproperties
{
    bTacticalTransient = true
}