package samples;

enum CarEvent {
    TurnKeyOn;
    TurnKeyOff;
    PressClutch;
    ReleaseClutch;
    PressStartButton;
    PressStopButton;
    ToggleLights;
    //TimerStep(dt:Float); // Aktiviert automatisch car.timerStep(dt) im Makro
    Tick;
}
