class UIUnitFlag_Twitch extends UIPanel;

var int StoredObjectID; // Object we're attached to
var int VisualizedHistoryIndex;

var bool m_bIsOnScreen;
var int m_iScaleOverride;
var float m_LocalYOffset;
var Vector2D m_positionV2;
var int m_scale;

var private UIText m_Text;

simulated function InitFlag(StateObjectReference ObjectRef) {
    InitPanel();

	StoredObjectID = ObjectRef.ObjectID;

    m_Text = Spawn(class'UIText', self);
    m_Text.InitText(, "Twitch Flag");
}

simulated function OnInit() {
    local XComGameState_Unit Unit;
    local Vector Position;
    local Vector2D ScreenPosition;

    //Update();

    Unit = XComGameState_Unit(`XCOMHISTORY.GetGameStateForObjectID(StoredObjectID));
    Position = `XWORLD.GetPositionFromTileCoordinates(Unit.TileLocation);
    `LOG("Position: " $ Position.X $ ", " $ Position.Y);
    Position.X = 0;
    Position.Y = 0;

    ScreenPosition.x = 6500;
    ScreenPosition.y = -17000;

    `LOG("Queuing world message for Twitch unit flag", , 'TwitchIntegration');
    `PRES.QueueWorldMessage("Twitch",
                            Position,
                            Unit.GetReference(),
                            /* _eColor */,
                            class'UIWorldMessageMgr'.const.FXS_MSG_BEHAVIOR_READY,
                            /* _sId */ "",
                            /* _eBroadcastToTeams */,
                            /* _bUseScreenLocationParam */ true,
                            ScreenPosition,
                            /* _displayTime */ -1.0,
                            /* deprecated */,
                            "img:///TwitchIntegration_UI.Icon_Twitch"); //, , , , , , , , true);

    //SetTimer(1.0, true, 'Update');
}

simulated function Update()
{
    local XComGameStateHistory History;
	local Vector2D UnitPosition; // Unit position as a percentage of total screen space
	local Vector2D UnitScreenPos; // Unit position in pixels within the current resolution
	local Vector vUnitLoc;
	local float FlagScale;
	local Actor VisualizedActor;
	local X2VisualizerInterface VisualizedInterface;
	local XComGameState_Unit UnitState;
	local XGUnit VisualizedUnit;

    `LOG("Updating Twitch unit flag", , 'TwitchIntegration');
	const WORLD_Y_OFFSET = 40;

	// If not shown or ready, leave.
	if (!bIsInited) {
        `LOG("Twitch unit flag is not inited", , 'TwitchIntegration');
		return;
    }

    History = `XCOMHISTORY;

	// Do nothing if unit isn't visible.  (And hide if not already hidden).
	VisualizedActor = History.GetVisualizer(StoredObjectID);
	VisualizedUnit = XGUnit(VisualizedActor);
	UnitState = XComGameState_Unit(History.GetGameStateForObjectID(StoredObjectID));
	if (VisualizedActor == none || !VisualizedActor.IsVisible()) {
        `LOG("VisualizedActor is none or not visible", , 'TwitchIntegration');
        Hide();
        return;
    }

    if (UnitState != None && (UnitState.IsBeingCarried() || UnitState.IsDead())) {
        `LOG("UnitState is none or dead or carried", , 'TwitchIntegration');
        Hide();
        return;
    }

    if (VisualizedUnit != none && (VisualizedUnit.GetPawn().IsInState('RagDollBlend') || VisualizedUnit.m_bHideUIUnitFlag)) {
        `LOG("VisualizedUnit is none or ragdoll or flag hidden", , 'TwitchIntegration');
		Hide();
		return;
	}

	if ( (XComDestructibleActor(VisualizedActor) != none) && !class'X2TacticalVisibilityHelpers'.static.CanXComSquadSeeTarget(StoredObjectID) ) {
		Hide();
		return;
	}

	// Now get the unit's location data
	VisualizedInterface = X2VisualizerInterface(VisualizedActor);
	if (VisualizedInterface != none) {
		vUnitLoc = VisualizedInterface.GetUnitFlagLocation();
	}
	else {
		vUnitLoc = VisualizedActor.Location;
	}

	m_bIsOnScreen = class'UIUtilities'.static.IsOnscreen(vUnitLoc, UnitPosition, 0, WORLD_Y_OFFSET);

	if (!m_bIsOnScreen) {
        `LOG("Twitch unit flag is not on screen", , 'TwitchIntegration');
		Hide();
	}
	else {
		Show();

		UnitScreenPos = Movie.ConvertNormalizedScreenCoordsToUICoords(UnitPosition.X, UnitPosition.Y, false);
		UnitScreenPos.Y += m_LocalYOffset;

		if (m_iScaleOverride > 0) {
			SetFlagPosition(UnitScreenPos.X, UnitScreenPos.Y - m_iScaleOverride, m_iScaleOverride);
		}
		else {
            FlagScale = (UnitScreenPos.Y / 22.5) + 52.0;

			SetFlagPosition(UnitScreenPos.X, UnitScreenPos.Y, FlagScale);
		}
	}

    `LOG("Done updating Twitch unit flag: UnitPosition.X = " $ UnitPosition.X $ ", UnitPosition.Y = " $ UnitPosition.Y, , 'TwitchIntegration');
}

// Copied from UIUnitFlag
simulated function SetFlagPosition(int flagX, int flagY, int scale)
{
	local ASValue myValue;
	local Array<ASValue> myArray;

	// Only update if a new value has been passed in.
	if( (m_positionV2.X != flagX) || (m_positionV2.Y != flagY) || (m_scale != scale) )
	{
		m_scale = scale;
		m_positionV2.X = flagX;
		m_positionV2.Y = flagY;

		myValue.Type = AS_Number;

		myValue.n = m_positionV2.X;
		myArray.AddItem(myValue);
		myValue.n = m_positionV2.Y;
		myArray.AddItem(myValue);
		myValue.n = m_scale;
		myArray.AddItem(myValue);

        `LOG("About to Invoke in Twitch unit flag", , 'TwitchIntegration');

		Invoke("SetPosition", myArray);
        `LOG("Invoke complete", , 'TwitchIntegration');
	}
}