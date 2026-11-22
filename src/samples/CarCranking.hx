package samples;

import enumstates.EnumStates;

import samples.CarStates.IgnitionStateCranking;
import samples.CarStates.EngineStateCranking;
import samples.CarStates.LightState;
import samples.CarStates.ClutchState;


// ---- State Machine ----
class CarCranking implements EnumStates<CarEvent, CarEffect> {
    @:region public var ignition:IgnitionStateCranking = KeyOff;
    @:region public var lights:LightState = LightsOff;
    @:region public var clutch:ClutchState = Released;

    // 1. Parent-Region: Zündung
    inline function update_ignition(event:CarEvent):IgnitionStateCranking {
        return switch [ignition, event] {
            case [KeyOff, TurnKeyOn]:
                KeyOn(Stopped);

            // Parent-Transition: Schlüssel abziehen stoppt Stopped, Cranking UND Running
            case [KeyOn(_), TurnKeyOff]:
                KeyOff;

            // Delegation an den Motor-Substate
            case [KeyOn(sub), _]:
                var nextSub = update_engine_sub(sub, event);
                nextSub == sub ? ignition : KeyOn(nextSub);

            default:
                ignition;
        };
    }

    // Delegierte Sub-State-Logik für den Motor inkl. Anlasser-Timer
    inline function update_engine_sub(sub:EngineStateCranking, event:CarEvent):EngineStateCranking {
        return switch [sub, event] {
            case [Stopped, PressStartButton] if (clutch == Pressed):
                Cranking(0.8);
    
            case [Cranking(_), ReleaseClutch]:
                Stopped;
    
            case [Cranking(t), TimerStep(dt)]:
                var left = t - dt;
                left <= 0 ? Running : Cranking(left);
    
            case [Running, PressStopButton]:
                Stopped;
    
            default:
                sub;
        };
    }

    
    // 2. Region: Licht
    inline function update_lights(event:CarEvent):LightState {
        return switch [lights, event] {
            case [LightsOff, ToggleLights]: LightsOn;
            case [LightsOn, ToggleLights]: LightsOff;
            case [LightsOn, TurnKeyOff]: LightsOff;
            default: lights;
        };
    }

    // 3. Region: Kupplung
    inline function update_clutch(event:CarEvent):ClutchState {
        return switch [clutch, event] {
            case [Released, PressClutch]: Pressed;
            case [Pressed, ReleaseClutch]: Released;
            default: clutch;
        };
    }

    // --- Hierarchische Lifecycle-Hooks ---
    function onEnter_ignition_KeyOn() {
        emit(SetDashboardPower(true));
    }

    function onExit_ignition_KeyOn() {
        emit(SetDashboardPower(false));
    }

    function onEnter_ignition_KeyOn_Cranking() {
        emit(PlaySound("starter_crank"));
    }

    function onExit_ignition_KeyOn_Cranking() {
        emit(StopSound("starter_crank"));
    }

    function onEnter_ignition_KeyOn_Running() {
        emit(PlaySound("engine_idle_loop"));
    }

    function onExit_ignition_KeyOn_Running() {
        emit(StopSound("engine_idle_loop"));
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
        var car = new CarCranking(eff -> trace('[EFFECT] $eff'));

        car.send(TurnKeyOn);        // -> SetDashboardPower(true)
        car.send(PressClutch);      // -> clutch = Pressed
        car.send(PressStartButton); // -> PlaySound("starter_crank"), ignition = KeyOn(Cranking(0.8))

        car.timerStep(0.5);         // -> ignition = KeyOn(Cranking(0.3)) (Anlasser läuft noch)
        car.timerStep(0.4);         // -> StopSound("starter_crank"), PlaySound("engine_idle_loop")
                                    //    ignition = KeyOn(Running)

        car.send(ReleaseClutch);    // -> clutch = Released (Motor bleibt Running)
  
        // Schlüssel abziehen: Feuert automatisch Exit-Hooks von innen nach außen:
        // 1. onExit_ignition_KeyOn_Running -> PlaySound("engine_stop")
        // 2. onExit_ignition_KeyOn         -> SetDashboardPower(false)
        // 3. onExit_lights_LightsOn        -> SetHeadlights(false)
        car.send(TurnKeyOff);

        // Generiert direkt das passende UML-Diagramm inklusive paralleler Regionen & Hooks:
        trace("\n" + car.toMermaid());
    }
}