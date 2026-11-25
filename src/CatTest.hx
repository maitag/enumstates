package;

import lime.app.Application;
import enumstates.EnumStates;

// ---- cat states ----
enum Mental {
	Happy;
	Snuggly;
	Confused;
	Stressed;
	Angry;
	Unknown;
}

// ---- main events -----
enum Event {
	HumanEntersRoom;
	HumanGiveFood;
	HumanSaySomething;
	CatFriendStartsLicking;
	DogEntersRoom;
	WindowOpens;
	DoorOpens;
}

// ---- effects ----- (param for emit-functions in enter/exit callbacks)
enum CatEffect {
	Miau; // <- german for meow
	Purr;
	Hiss;
	EyeRolling;
	Snuggles;
}

// -----------------------
// ---- State Machine ----
// -----------------------

class Cat implements EnumStates<Event, CatEffect> {
	// (parallele) states
	@:region public var mental:Mental = Unknown;

	inline function update_mental(event:Event):Mental {
		return switch [mental, event] {
			case [_, HumanEntersRoom]: Happy;
			case [_, HumanGiveFood]: Snuggly;
			case [_, DogEntersRoom]: Stressed;
			case [Unknown | Happy, HumanSaySomething]: Confused;
			default: mental;
		};
	}

	// --- mental-hooks  ---
	function onEnter_mental_Happy() {
		emit(Purr);
	}

	function onExit_mental_Happy() {
		emit(Miau);
	}

	function onEnter_mental_Snuggly() {
		emit(Snuggles);
	}

	function onExit_mental_Snuggly() {
		emit(Miau);
	}

	function onEnter_mental_Confused() {
		emit(EyeRolling);
	}

	function onEnter_mental_Stressed() {
		emit(Hiss);
	}
}

class CatTest extends Application {
	public function new() {
		super();

		var cat = new Cat(eff -> trace('  [EFFECT] $eff'));

		// trace(cat.getGeneratedCode());
		trace(cat.toMermaid());

		// var car = new samples.Car(eff -> trace('[EFFECT] $eff'));
		// trace(car.toMermaid());
	}
}
