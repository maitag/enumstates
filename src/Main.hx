package;

import lime.app.Application;

import enumstates.EnumStates;
import enumstates.Test;
import enumstates.Benchs;

// ---- main states ------

enum ActionState {
	Ready;
	Dashing(remaining:Float);
}

enum MovementState {
	Grounded(sub:GroundState);
	Airborne(vy:Float, sub:AirState);
}

	// ---- sub-states for Grounded ---
	enum GroundState {
		Idle;
		Running(speed:Float);
	}

	// ---- sub-states for Airborne ---
	enum AirState {
		Rising;
		Falling;
	}


// ------- events ------------

enum PlayerEvent {
	StartRun(speed:Float);
	StopRun;
	Jump;
	Land;
	Dash;
	TimerStep(dt:Float);
}

enum PlayerEffect {
	PlayAnim(name:String);
	PlaySound(id:String);
	SetDustTrail(active:Bool);
}

class PlayerStateMachine implements EnumStates<PlayerEvent, PlayerEffect> {
	@:region public var movement:MovementState = Grounded(Idle);
	@:region public var action:ActionState = Ready;

	inline function update_movement(event:PlayerEvent):MovementState {
		return switch [movement, action, event] {
			// Parent-Transition: Gilt für Grounded(Idle) UND Grounded(Running(_))!
			case [Grounded(_), Ready, Jump]:
				emit(PlaySound("jump"));
				Airborne(10.0, Rising);

			// Sub-State-Delegation innerhalb von Grounded
			case [Grounded(sub), _, _]:
				var nextSub = update_grounded_sub(sub, event);
				nextSub == sub ? movement : Grounded(nextSub);

			// Parent-Transition: Gilt für Airborne(_, Rising) UND Airborne(_, Falling)!
			case [Airborne(_, _), _, Land]:
				emit(PlaySound("land"));
				Grounded(Idle);

			// Physik + Sub-State-Wechsel (Rising -> Falling) in Airborne
			case [Airborne(vy, sub), _, TimerStep(dt)]:
				var nextVy = action.match(Dashing(_)) ? 0.0 : vy - 9.81 * dt;
				var nextSub = nextVy <= 0 ? Falling : Rising;
					(nextVy == vy && nextSub == sub) ? movement : Airborne(nextVy, nextSub);

			default:
				movement;
		};
	}

	inline function update_grounded_sub(sub:GroundState, event:PlayerEvent):GroundState {
		return switch [sub, event] {
			case [Idle, StartRun(speed)]: Running(speed);
			case [Running(_), StopRun]: Idle;
			default: sub;
		};
	}

	function update_action(event:PlayerEvent):ActionState {
		return switch [action, event] {
			case [Ready, Dash]: Dashing(0.2);
			case [Dashing(t), TimerStep(dt)]:
				var left = t - dt;
				left <= 0 ? Ready : Dashing(left);
			default: action;
		};
	}

	// --- Parent-Hooks ---
	function onEnter_movement_Grounded() { trace("  [HOOK] Enter Grounded (Parent)");  }
	function onExit_movement_Grounded()  { trace("  [HOOK] Exit Grounded (Parent)"); }

	// --- Child-Hooks (4-teiliger Name: onEnter_<region>_<Parent>_<Child>) ---
	function onEnter_movement_Grounded_Idle() {
		emit(PlayAnim("idle"));
	}
	
	function onEnter_movement_Grounded_Running() {
		emit(PlayAnim("run"));
		emit(SetDustTrail(true));
	}

	function onExit_movement_Grounded_Running() {
		emit(SetDustTrail(false));
	}

	function onEnter_movement_Airborne_Rising()
		emit(PlayAnim("jump_up"));

	function onEnter_movement_Airborne_Falling()
		emit(PlayAnim("fall_down"));
}

class Main extends Application {
	public function new() {
		super();

		trace("=== 1. Start (Grounded -> Idle) ===");
		var p = new PlayerStateMachine(eff -> trace('  [EFFECT] $eff'));

		trace("\n=== 2. Losrennen (Grounded bleibt aktiv -> nur Running-Hook feuert!) ===");
		p.send(StartRun(6.5));
		trace('  State: ${p.movement}');

		// trace("\n=== 3. JSON-Snapshot eines verschachtelten Sub-States ===");
		// var json = p.toJson(true);
		// trace(json);

		trace("\n=== 4. Absprung aus dem Rennen (Exit Running -> Exit Grounded -> Enter Rising) ===");
		p.send(Jump);

		trace("\n=== 5. Scheitelpunkt überschreiten (Rising -> Falling) ===");
		p.timerStep(1.2);
		trace('  State: ${p.movement}');

		trace("\n=== 6. Landen (Enter Grounded -> Enter Idle) ===");
		p.send(Land);

		trace("\n=== final STATE ===\n" + p.toJson(true));
		
		// debug
		//trace(p.getGeneratedCode());

		// test
		Test.run();

		// bench
		Benchs.run(10000, 600);
	}
}
