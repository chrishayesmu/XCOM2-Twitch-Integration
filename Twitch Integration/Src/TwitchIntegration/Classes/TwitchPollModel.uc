class TwitchPollModel extends Object;

struct PollChoice {
    var string Id;
    var string Title;
    var int NumVotes;
    var name TemplateName; // X2PollChoiceTemplate
};

var string Id;
var string Title;
var array<PollChoice> Choices;
var string Status;
var int SecondsRemaining; // How many seconds are left in the poll on Twitch's end
var name PollGroupTemplateName;

static function TwitchPollModel FromJson(JsonObject json) {
    local JsonObject ChoicesArrJson, ChoiceJson;
    local TwitchPollModel Model;
    local PollChoice Choice;

    Model = new class'TwitchPollModel';

    Model.Id = json.GetStringValue("id");
    Model.Title = json.GetStringValue("title");
    Model.Status = json.GetStringValue("status");
    Model.SecondsRemaining = json.GetIntValue("seconds_remaining");

    ChoicesArrJson = json.GetObject("choices");

    foreach ChoicesArrJson.ObjectArray(ChoiceJson)
    {
        Choice.Id = ChoiceJson.GetStringValue("id");
        Choice.Title = ChoiceJson.GetStringValue("title");
        Choice.NumVotes = ChoiceJson.GetIntValue("num_votes");

        Model.Choices.AddItem(Choice);
    }

    return Model;
}