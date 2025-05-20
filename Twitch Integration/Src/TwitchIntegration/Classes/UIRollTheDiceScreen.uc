class UIRollTheDiceScreen extends UIScreen
    dependson(TwitchStateManager);


const LINE_HEIGHT_PX = 31.85; // Each line of text is not quite 32px high. Value determined experimentally
const NUM_OPTIONS_VISIBLE = 5; // Needs to be odd so the winning option is centered

var localized string strCloseButton;
var localized string strDialogTitle;
var localized string strHeaderText;

var array<string> Options;
var int TargetUnitObjectID;
var int WinningOptionIndex;
var name WinningOptionTemplateName;

var float SecondsUntilCarouselStart;
var float SecondsToRampUp;
var float SecondsAtMaxSpeed;
var float TextSpeed;

var private UIBGBox m_bgBox;
var private UIButton m_CloseButton;
var private UIMask m_Mask;
var private UIPanel m_OptionHighlight;
var private UIText m_OptionsText;
var private UIX2PanelHeader	m_TitleHeader;

var private int m_TextStartY;
var private float m_DistanceTraveledInCurrentState;
var private float m_DistanceUntilNextTickSound;
var private float m_TimeInCurrentState;

// Variables only used in deceleration state
var private float m_TargetY;
var private float m_OriginalDistanceToTargetY;

var private SoundCue TickCue; // sound that plays while the carousel is spinning

// TODO this may need a mouse guard? check when doing it through vis system
// TODO make right mouse close the screen
simulated function InitScreen(XComPlayerController InitController, UIMovie InitMovie, optional name InitName) {
    local string HeaderText, OptionsText;
    local int I, MaxOptionLength, TextWidth;

    super.InitScreen(InitController, InitMovie, InitName);

    ShuffleOptions();

    TickCue = SoundCue(DynamicLoadObject("SoundUI.MenuScrollCue", class'SoundCue'));

    m_bgBox = Spawn(class'UIBGBox', self);
    m_bgBox.InitBG('', 0, 0, 700, 160 + NUM_OPTIONS_VISIBLE * LINE_HEIGHT_PX, eUIState_Normal);

    HeaderText = Repl(strHeaderText, "<ViewerName/>", GetDisplayName());
	m_TitleHeader = Spawn(class'UIX2PanelHeader', self);
	m_TitleHeader.InitPanelHeader('', strDialogTitle, HeaderText);

    // Put together the options center-aligned
    for (I = 0; I < Options.Length; I++) {
        MaxOptionLength = Max(MaxOptionLength, Len(Options[I]));

        OptionsText $= "<p align='center'>" $ Options[I] $ "</p>";
    }

    // OptionsText is doubled so we can fake wrapping around the spinner later
    OptionsText $= OptionsText;

    // Arbitrary guess at the max text length since there isn't a proper text size event for UIText
    TextWidth = MaxOptionLength * 11;

    m_OptionHighlight = Spawn(class'UIPanel', self);
    m_OptionHighlight.InitPanel('', class'UIUtilities_Controls'.const.MC_X2Background);

    m_OptionsText = Spawn(class'UIText', self);
    m_OptionsText.InitText('', OptionsText, /* InitTitleFont */ false, RealizeUI);
    m_OptionsText.SetSize(TextWidth, LINE_HEIGHT_PX * Options.Length * 2);

    m_Mask = Spawn(class'UIMask', self).InitMask();
    m_Mask.SetMask(m_OptionsText);
    m_Mask.SetSize(TextWidth, NUM_OPTIONS_VISIBLE * LINE_HEIGHT_PX);

    m_CloseButton = Spawn(class'UIButton', self);
    m_CloseButton.InitButton('CloseRollTheDiceScreenButton', strCloseButton, OnCloseButtonPress);
    m_CloseButton.OnSizeRealized = RealizeUI;
    m_CloseButton.SetDisabled(true);

    m_DistanceUntilNextTickSound = LINE_HEIGHT_PX;

    GotoState('WaitingToStart');
}

event Tick(float DeltaTime) {
    local float DeltaY;

    m_TimeInCurrentState += DeltaTime;

    DeltaY = CalculateTextSpeed() * DeltaTime;

    m_OptionsText.SetY(m_OptionsText.Y - DeltaY);

    m_DistanceUntilNextTickSound -= Abs(DeltaY);
    m_DistanceTraveledInCurrentState += DeltaY;

    if (m_DistanceUntilNextTickSound <= 0) {
        m_DistanceUntilNextTickSound = LINE_HEIGHT_PX + m_DistanceUntilNextTickSound;
        PlaySound(TickCue);
    }

    // Snap back to the top of the text
    if (m_TextStartY - m_OptionsText.Y > m_OptionsText.Height / 2) {
        m_OptionsText.SetY(m_TextStartY);
    }
}

// Calculates the speed to move the carousel text in pixels per second. Overridden
// in various states.
protected function float CalculateTextSpeed() {
    return 0.0f;
}

protected function string GetDisplayName() {
    local TwitchChatter Viewer;
    local XComGameState_Unit UnitState;
    local XComGameState_TwitchObjectOwnership OwnershipState;

    OwnershipState = class'XComGameState_TwitchObjectOwnership'.static.FindForObject(TargetUnitObjectID);

    if (OwnershipState != none) {
        if (`TISTATEMGR.TryGetViewer(OwnershipState.TwitchLogin, Viewer)) {
            return Viewer.DisplayName;
        }

        return OwnershipState.TwitchLogin;
    }

    UnitState = XComGameState_Unit(`XCOMHISTORY.GetGameStateForObjectID(TargetUnitObjectID));

    return UnitState.GetFullName();
}

private function OnCloseButtonPress(UIButton Button) {
    `SCREENSTACK.Pop(self);
    Movie.Pres.PlayUISound(eSUISound_MenuClose);
}

// Positions the carousel text and related elements. Ignored once the carousel starts spinning, to avoid
// resetting the Y position on the text and therefore jumping the carousel around.
protected function PositionTextElements() {
    local int TextX;

    m_TextStartY = m_TitleHeader.Y + 85;
    TextX = m_CloseButton.X - (m_Mask.Width - m_CloseButton.Width) / 2; // have to use mask width here, text keeps resizing strangely

    m_OptionsText.AnchorCenter();
    m_OptionsText.SetPosition(TextX, m_TextStartY);

    m_Mask.AnchorCenter();
    m_Mask.SetPosition(TextX, m_TextStartY);

    m_OptionHighlight.AnchorCenter();
    m_OptionHighlight.SetPosition(TextX, m_TextStartY + (m_Mask.Height - m_OptionHighlight.Height) / 2);
    m_OptionHighlight.SetSize(m_Mask.Width, 42);
}

protected function ShuffleOptions() {
    local int I, J;
    local string Temp;

    // Basic Fisher-Yates shuffle
    for (I = Options.Length - 1; I >= 1; I--) {
        J = Rand(I + 1);

        Temp = Options[I];
        Options[I] = Options[J];
        Options[J] = Temp;

        if (I == WinningOptionIndex) {
            WinningOptionIndex = J;
        }
        else if (J == WinningOptionIndex) {
            WinningOptionIndex = I;
        }
    }
}

private function RealizeUI() {
    local int BgTop, BgLeft, BgBottom, BgRight;

    BgBottom = m_bgBox.Height / 2;
    BgRight = m_bgBox.Width / 2;
    BgTop = -BgBottom;
    BgLeft = -BgRight;

    m_bgBox.AnchorCenter();
    m_bgBox.SetPosition(BgLeft, BgTop);

    m_CloseButton.AnchorCenter();
    m_CloseButton.SetPosition(-m_CloseButton.Width / 2, BgBottom - m_CloseButton.Height - 10);

    m_TitleHeader.AnchorCenter();
    m_TitleHeader.SetWidth(m_bgBox.Width - 20);
    m_TitleHeader.SetPosition(-m_TitleHeader.width / 2, BgTop + 10);

    PositionTextElements();
}

state WaitingToStart {
	event BeginState(Name PreviousStateName) {
        m_TimeInCurrentState = 0.0f;
    }

    event Tick(float DeltaTime) {
        super.Tick(DeltaTime);

        if (m_TimeInCurrentState >= SecondsUntilCarouselStart) {
            GotoState('Accelerating');
        }
    }
}

state Accelerating {
    ignores PositionTextElements;

	event BeginState(Name PreviousStateName) {
        m_TimeInCurrentState = 0.0f;
    }

    event Tick(float DeltaTime) {
        super.Tick(DeltaTime);

        if (m_TimeInCurrentState >= SecondsToRampUp) {
            GotoState('AtMaxSpeed');
        }
    }

    protected function float CalculateTextSpeed() {
        return Lerp(0.0f, TextSpeed, m_TimeInCurrentState / SecondsToRampUp);
    }
}

state AtMaxSpeed {
    ignores PositionTextElements;

	event BeginState(Name PreviousStateName) {
        m_TimeInCurrentState = 0.0f;
    }

    event Tick(float DeltaTime) {
        super.Tick(DeltaTime);

        if (m_TimeInCurrentState >= SecondsAtMaxSpeed) {
            GotoState('Decelerating');
        }
    }

    protected function float CalculateTextSpeed() {
        return TextSpeed;
    }
}

state Decelerating {
    ignores PositionTextElements;

	event BeginState(Name PreviousStateName) {
        m_TimeInCurrentState = 0.0f;

        `TILOG(`SHOWVAR(WinningOptionIndex) @ Options[WinningOptionIndex]);

        // TODO if the target is too close or too far, jump the list position so we have a satisfying deceleration
        m_TargetY = m_TextStartY - WinningOptionIndex * LINE_HEIGHT_PX + (NUM_OPTIONS_VISIBLE / 2) * LINE_HEIGHT_PX;

        // If one of the very first options won, we want to scroll to the second occurrence of the
        // option in the list. The first occurrence may not have any text above it and show an ugly gap.
        if (WinningOptionIndex < 3) {
            m_TargetY -= Options.Length * LINE_HEIGHT_PX;
        }

        m_OriginalDistanceToTargetY = CalculateDistanceToTarget();

        `TILOG(`SHOWVAR(m_TargetY));
    }

    event Tick(float DeltaTime) {
        local float DistanceBeforeTick, DistanceAfterTick;

        DistanceBeforeTick = CalculateDistanceToTarget();
        super.Tick(DeltaTime);
        DistanceAfterTick = CalculateDistanceToTarget();

        if (DistanceAfterTick > DistanceBeforeTick) {
            GotoState('Stopped');
        }
    }

    protected function float CalculateDistanceToTarget() {
        local float DistanceToTarget;

        if (m_OptionsText.Y < m_TargetY) {
            // If we'll have to loop around to reach our target, then the total distance is the
            // distance to the loop point, plus the distance from the start to the target
            DistanceToTarget += Abs(m_TextStartY - m_OptionsText.Y - m_OptionsText.Height / 2);
            DistanceToTarget += Abs(m_TextStartY - m_TargetY);
        }
        else {
            DistanceToTarget = Abs(m_OptionsText.Y - m_TargetY);
        }

        return DistanceToTarget;
    }

    protected function float CalculateTextSpeed() {
        local float DistanceElapsedPercentage, DistanceToTarget, Result;

        DistanceToTarget = CalculateDistanceToTarget();
        DistanceElapsedPercentage = (m_OriginalDistanceToTargetY - DistanceToTarget) / m_OriginalDistanceToTargetY;

        if (DistanceElapsedPercentage < 0.95) {
            Result = FInterpEaseInOut(TextSpeed, TextSpeed / 3, DistanceElapsedPercentage, /* Exp */ 1.5);
        }
        else {
            Result = FInterpEaseInOut(TextSpeed / 3, TextSpeed / 5, DistanceElapsedPercentage, /* Exp */ 2.5);
        }

        return Result;
    }
}

state Stopped {
    ignores PositionTextElements;

    event BeginState(Name PreviousStateName) {
        m_TimeInCurrentState = 0.0f;

        m_OptionsText.SetY(m_TargetY);
    }

    event Tick(float DeltaTime) {
        local SoundCue CompletionCue;

        super.Tick(DeltaTime);

        if (m_TimeInCurrentState - DeltaTime < 0.3 && m_TimeInCurrentState >= 0.3) {
            CompletionCue = SoundCue(DynamicLoadObject("SoundTacticalUI_Hacking.Stop_Hack_Bar_Fill_Cue", class'SoundCue'));
            PlaySound(CompletionCue);

            m_CloseButton.SetDisabled(false);
        }
    }
}

defaultproperties
{
    SecondsUntilCarouselStart=0.4
    SecondsToRampUp=0.5
    SecondsAtMaxSpeed=2.0
    TextSpeed=500
}