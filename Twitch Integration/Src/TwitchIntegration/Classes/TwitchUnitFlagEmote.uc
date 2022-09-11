class TwitchUnitFlagEmote extends UIImage
    config(TwitchUI);

const TimerFrequency = 0.05;

var config float AnimationTimeInSeconds;
var config float DisplayTimeInSeconds;

var private int TargetWidth, TargetHeight;

simulated function TwitchUnitFlagEmote Init(int MaxWidth, int MaxHeight, optional name InitName, optional string initImagePath,  optional delegate<OnClickedCallback> OnClickDel) {
    super.InitImage(InitName, InitImagePath, OnClickDel);

    // This element's opacity is multiplicative with the opacity of the unit flag that contains it.
    // XCOM team's unit flags fade out for units who aren't selected. By setting our alpha arbitrarily
    // high, we can force this element to remain opaque even when the flag is faded.
    SetAlpha(500);

    SetSize(1, 1);
    Hide();

    TargetWidth = MaxWidth;
    TargetHeight = MaxHeight;

    return self;
}

simulated function UIImage LoadImage(string NewPath) {
    super.LoadImage(NewPath);

    ClearTimer(nameof(BeginAnimateOut));

    if (NewPath == "") {
        BeginAnimateOut();
    }
    else {
        BeginAnimateIn();

        if (DisplayTimeInSeconds > 0) {
            SetTimer(DisplayTimeInSeconds, /* inBLoop */ false, nameof(BeginAnimateOut));
        }
    }

    return self;
}

function BeginAnimateIn() {
    SetSize(1, 1);
    Show();
    AnimateSize(TargetWidth, TargetHeight, AnimationTimeInSeconds);
}

function BeginAnimateOut() {
    // Animate to (1, 1) because if you animate to (0, 0) it bounces back to full size for some reason
    AnimateSize(1, 1, AnimationTimeInSeconds);
    SetTimer(AnimationTimeInSeconds, /* inBLoop */ false, nameof(Hide));
}