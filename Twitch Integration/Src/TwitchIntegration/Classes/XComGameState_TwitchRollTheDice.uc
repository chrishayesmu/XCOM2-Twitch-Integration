class XComGameState_TwitchRollTheDice extends XComGameState_BaseObject;

var array<string> PossibleActions; // Friendly names of all of the actions which were valid for this roll, to show on the UI
var string ViewerLogin; // The login of the viewer who initiated the RTD
var int SelectedActionIndex; // The index of the action which was selected
var name SelectedActionTemplateName; // Template name of the action to execute

defaultproperties
{
    bTacticalTransient = true
}