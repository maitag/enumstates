package samples;

import enumstates.EnumStates;

import samples.CarStates.IgnitionState;
import samples.CarStates.LightState;
import samples.CarStates.ClutchState;

// ---- State Machine ----
class Car implements EnumStates<CarEvent, CarEffect> {
    // 3 orthogonale Regiones (parallel states)
    @:region public var ignition:IgnitionState = KeyOff;
    @:region public var lights:LightState = LightsOff;
    @:region public var clutch:ClutchState = Released;

    // 1. Region: Zündung & hierarchischer Substate Motor
    inline function update_ignition(event:CarEvent):IgnitionState {
        return switch [ignition, clutch, event] {
            // Zündung einschalten -> betritt KeyOn und Initial-Substate Stopped
            case [KeyOff, _, TurnKeyOn]:
                KeyOn(Stopped);

            // Parent-Transition: Schlüssel abziehen schaltet Zündung UND laufenden Motor aus
            case [KeyOn(_), _, TurnKeyOff]:
                KeyOff;

            // Motor startet NUR, wenn Zündung an (Stopped) UND Kupplung getreten (Pressed)
            case [KeyOn(Stopped), Pressed, PressStartButton]:
                KeyOn(Running);

            case [KeyOn(Running), _, PressStopButton]:
                KeyOn(Stopped);

            default:
                ignition;
        };
    }

    // 2. Region: Licht (unabhängig vom Motor, reagiert aber auf TurnKeyOff)
    inline function update_lights(event:CarEvent):LightState {
        return switch [lights, event] {
            case [LightsOff, ToggleLights]:
                LightsOn;

            case [LightsOn, ToggleLights]:
                LightsOff;

            // Zündung aus schaltet auch das Licht mit aus
            case [LightsOn, TurnKeyOff]:
                LightsOff;

            default:
                lights;
        };
    }

    // 3. Region: Kupplung (lässt sich jederzeit treten und loslassen)
    inline function update_clutch(event:CarEvent):ClutchState {
        return switch [clutch, event] {
            case [Released, PressClutch]:
                Pressed;

            case [Pressed, ReleaseClutch]:
                Released;

            default:
                clutch;
        };
    }

    // --- Hierarchische Lifecycle-Hooks (werden vom Makro automatisch sortiert) ---
    function onEnter_ignition_KeyOn() {
        emit(SetDashboardPower(true));
    }

    function onExit_ignition_KeyOn() {
        emit(SetDashboardPower(false));
    }

    // Child-Hooks: onEnter_<region>_<Parent>_<Child>
    function onEnter_ignition_KeyOn_Running() {
        emit(PlaySound("engine_start"));
    }

    function onExit_ignition_KeyOn_Running() {
        emit(PlaySound("engine_stop"));
    }

    // --- Licht-Hooks ---
    function onEnter_lights_LightsOn() {
        emit(SetHeadlights(true));
    }

    function onExit_lights_LightsOn() {
        emit(SetHeadlights(false));
    }
	
	// ------------------ TEST ---------------------
	
	public static function test() {
        var car = new Car(eff -> trace('[EFFECT] $eff'));

        car.send(TurnKeyOn);        // -> SetDashboardPower(true)
        car.send(PressStartButton); // Passiert nichts (clutch == Released)

        car.send(PressClutch);      // -> clutch = Pressed
        car.send(PressStartButton); // -> PlaySound("engine_start"), ignition = KeyOn(Running)
        car.send(ReleaseClutch);    // -> clutch = Released (Motor läuft weiter)
        car.send(ToggleLights);     // -> SetHeadlights(true)

        // Schlüssel abziehen: Feuert automatisch Exit-Hooks von innen nach außen:
        // 1. onExit_ignition_KeyOn_Running -> PlaySound("engine_stop")
        // 2. onExit_ignition_KeyOn         -> SetDashboardPower(false)
        // 3. onExit_lights_LightsOn        -> SetHeadlights(false)
        car.send(TurnKeyOff);

        // Generiert direkt das passende UML-Diagramm inklusive paralleler Regionen & Hooks:
        trace("\n" + car.toMermaid());
    }
}

