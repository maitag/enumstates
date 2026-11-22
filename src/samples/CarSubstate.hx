package samples;

import enumstates.EnumStates;

import samples.CarStates.IgnitionState;
import samples.CarStates.EngineState;
import samples.CarStates.LightState;
import samples.CarStates.ClutchState;

// ---- State Machine ----
class CarSubstate implements EnumStates<CarEvent, CarEffect> {
    @:region public var ignition:IgnitionState = KeyOff;
    @:region public var lights:LightState = LightsOff;
    @:region public var clutch:ClutchState = Released;

    // 1. Parent-Region: Kümmert sich nur um KeyOff <-> KeyOn und delegiert Sub-States
    inline function update_ignition(event:CarEvent):IgnitionState {
        return switch [ignition, event] {
            case [KeyOff, TurnKeyOn]:
                KeyOn(Stopped);

            // Parent-Transition: Gilt für KeyOn(Stopped) UND KeyOn(Running)
            case [KeyOn(_), TurnKeyOff]:
                KeyOff;

            // Sub-State-Delegation innerhalb von KeyOn
            case [KeyOn(sub), _]:
                var nextSub = update_engine_sub(sub, event);
                nextSub == sub ? ignition : KeyOn(nextSub);

            default:
                ignition;
        };
    }

    // Delegierte Sub-State-Funktion für den Motor (greift direkt auf Region 'clutch' zu)
    inline function update_engine_sub(sub:EngineState, event:CarEvent):EngineState {
        return switch [sub, clutch, event] {
            // Motor startet nur bei getretener Kupplung
            case [Stopped, Pressed, PressStartButton]:
                Running;

            case [Running, _, PressStopButton]:
                Stopped;

            default:
                sub;
        };
    }

    // 2. Region: Licht
    inline function update_lights(event:CarEvent):LightState {
        return switch [lights, event] {
            case [LightsOff, ToggleLights]:
                LightsOn;

            case [LightsOn, ToggleLights]:
                LightsOff;

            case [LightsOn, TurnKeyOff]:
                LightsOff;

            default:
                lights;
        };
    }

    // 3. Region: Kupplung
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

    // --- Hierarchische Lifecycle-Hooks ---
    function onEnter_ignition_KeyOn() {
        emit(SetDashboardPower(true));
    }

    function onExit_ignition_KeyOn() {
        emit(SetDashboardPower(false));
    }

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
        var car = new CarSubstate(eff -> trace('[EFFECT] $eff'));

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