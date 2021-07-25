//---------------------------------------------------------------------------------------
//  FILE:   XComDownloadableContentInfo_TwitchIntegration.uc
//
//	Use the X2DownloadableContentInfo class to specify unique mod behavior when the
//  player creates a new campaign or loads a saved game.
//
//---------------------------------------------------------------------------------------
//  Copyright (c) 2016 Firaxis Games, Inc. All rights reserved.
//---------------------------------------------------------------------------------------

class X2DownloadableContentInfo_TwitchIntegration extends X2DownloadableContentInfo
	dependson(XComGameState_TwitchEventPoll);

/// <summary>
/// This method is run if the player loads a saved game that was created prior to this DLC / Mod being installed, and allows the
/// DLC / Mod to perform custom processing in response. This will only be called once the first time a player loads a save that was
/// create without the content installed. Subsequent saves will record that the content was installed.
/// </summary>
static event OnLoadedSavedGame()
{
}

/// <summary>
/// Called when the player starts a new campaign while this DLC / Mod is installed
/// </summary>
static event InstallNewCampaign(XComGameState StartState)
{
}

/// <summary>
/// Called just before the player launches into a tactical a mission while this DLC / Mod is installed.
/// </summary>
static event OnPreMission(XComGameState NewGameState, XComGameState_MissionSite MissionState)
{
}

exec function TwitchCastVote(string Voter, int Option) {
	class'X2TwitchUtils'.static.GetStateManager().CastVote(Voter, Option - 1);
}

exec function TwitchEndPoll() {
	class'X2TwitchUtils'.static.GetStateManager().ResolveCurrentPoll();
}

exec function TwitchQuickPoll(ePollType PollType) {
    TwitchStartPoll(PollType, 2);
    TwitchCastVote("user1", 1);
    TwitchCastVote("user2", 2);
    TwitchCastVote("user3", 2);
    TwitchEndPoll();
}

exec function TwitchStartPoll(ePollType PollType, int DurationInTurns) {
	class'X2TwitchUtils'.static.GetStateManager().StartPoll(PollType, DurationInTurns);
}