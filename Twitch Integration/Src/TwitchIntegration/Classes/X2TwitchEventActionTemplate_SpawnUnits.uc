class X2TwitchEventActionTemplate_SpawnUnits extends X2TwitchEventActionTemplate;

var config name EncounterID; // The ID of the encounter to spawn, from XComEncounters.ini
var config int SpawnCountdown; // Number of turns between reinforcement notification and enemies spawning
var config int SpawnDistanceFromSquad; // Ideal distance from XCOM's squad (in tiles) that reinforcements will spawn
var config bool SpawnForceScamper; // If true, enemies will scamper instead of having a chance to shoot on spawn

function Apply(optional XComGameState_Unit InvokingUnit) {
	if (EncounterID != '') {
		`TILOG("Spawning encounter with ID " $ EncounterID);

		class'XComGameState_AIReinforcementSpawner'.static.InitiateReinforcements(EncounterID,
                                                                                  SpawnCountdown,
                                                                               /* OverrideTargetLocation */ ,
                                                                               /* TargetLocationOverride */ ,
                                                                                  SpawnDistanceFromSquad,
                                                                               /* NewGameState */,
                                                                               /* InKismetInitiatedReinforcements */ false,
                                                                               /* InSpawnVisualizationType */ 'ATT', // prefers dropship for situations where they can be used
                                                                               /* InDontSpawnInLOSOfXCOM */ ,
                                                                               /* InMustSpawnInLOSOfXCOM */ ,
                                                                               /* InDontSpawnInHazards */ ,
                                                                               /* InForceScamper */,
                                                                               /* bAlwaysOrientAlongLOP */ ,
                                                                               /* bIgnoreUnitCap */ true);
	}
}

function bool IsValid(optional XComGameState_Unit InvokingUnit) {
    return `TI_IS_TAC_GAME; // always fine to spawn more stuff if we're in tac
}