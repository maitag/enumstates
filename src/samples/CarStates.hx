package samples;

// ---- Regions & Sub-States ----

enum IgnitionState {
    KeyOff;
    KeyOn(engine:EngineState); // Hierarchischer Substate: Motor hängt an der Zündung
}

enum EngineState {
    Stopped;
    Running;
}

enum LightState {
    LightsOff;
    LightsOn;
}

enum ClutchState {
    Released;
    Pressed;
}

// ---- extra for car cranking sample ----

enum IgnitionStateCranking {
    KeyOff;
    KeyOn(engine:EngineStateCranking); // Hierarchischer Substate: Motor hängt an der Zündung
}

enum EngineStateCranking {
    Stopped;
    Running;
    Cranking(remaining:Float); // Anlasser läuft für X Sekunden
}
