package samples;

// ---- Regions & Sub-States ----

enum IgnitionState {
    KeyOff;
    KeyOn(engine:EngineState); // Hierarchischer Substate: Motor hängt an der Zündung
}

enum EngineState {
    Stopped;
    Running;
    Cranking(remaining:Float); // Anlasser läuft für X Sekunden
}

enum LightState {
    LightsOff;
    LightsOn;
}

enum ClutchState {
    Released;
    Pressed;
}

