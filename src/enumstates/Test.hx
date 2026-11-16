package enumstates;

// Tief verschachtelte States für Test 2
enum TestSubMode {
	Scan(range:Int);
	LockOn(targetId:String);
}

enum TestDoorState {
	Closed(locked:Bool);
	Open(mode:TestSubMode);
}

enum TestAlarmState {
	Disarmed;
	Armed(countdown:Float);
	Triggered;
}

enum TestEvent {
	Unlock;
	Lock;
	OpenDoor;
	CloseDoor;
	SwitchToLockOn(target:String);
	ArmAlarm;
	TimerStep(dt:Float);
}

enum TestEffect {
	Log(msg:String);
	SirenOn;
}

class SecurityDoor implements EnumStates<TestEvent, TestEffect> {
	@:region
	public var door:TestDoorState = Closed(true);

	@:region
	public var alarm:TestAlarmState = Disarmed;

	public var hookLog:Array<String> = [];

	inline function update_door(event:TestEvent):TestDoorState {
		return switch [door, alarm, event] {
			case [Closed(true), _, Unlock]:
				Closed(false);
			case [Closed(false), _, Lock]:
				Closed(true);
			// Guard: Tür lässt sich nur öffnen, wenn unverschlossen -> startet im Sub-State Scan(10)
			case [Closed(false), _, OpenDoor]:
				emit(Log("door_opened"));
				Open(Scan(10));
			// Wechsel innerhalb des Parent-States Open (Scan -> LockOn)
			case [Open(Scan(_)), _, SwitchToLockOn(id)]:
				Open(LockOn(id));
			case [Open(_), _, CloseDoor]:
				Closed(false);
			default:
				door;
		}
	}

	inline function update_alarm(event:TestEvent):TestAlarmState {
		return switch [door, alarm, event] {
			case [_, Disarmed, ArmAlarm]:
				Armed(3.0);
			case [_, Armed(t), TimerStep(dt)]:
				var left = t - dt;
				left <= 0 ? Armed(0.0) : Armed(left);
			// Parallele Reaktion: Tür wird geöffnet, während Alarm scharf (countdown == 0) ist!
			case [_, Armed(t), OpenDoor] if (t <= 0):
				emit(SirenOn);
				Triggered;
			default:
				alarm;
		}
	}

	// Hooks für Closed
	inline function onEnter_door_Closed() {
		hookLog.push("enter_closed");
	}

	inline function onExit_door_Closed() {
		hookLog.push("exit_closed");
	}

	// Hierarchische Hooks für Open (Parent) und Sub-States (Child)
	inline function onEnter_door_Open() {
		hookLog.push("enter_open");
	}

	inline function onExit_door_Open() {
		hookLog.push("exit_open");
	}

	inline function onEnter_door_Open_Scan() {
		hookLog.push("enter_open_scan");
	}

	inline function onExit_door_Open_Scan() {
		hookLog.push("exit_open_scan");
	}

	inline function onEnter_door_Open_LockOn() {
		hookLog.push("enter_open_lockon");
	}

	inline function onExit_door_Open_LockOn() {
		hookLog.push("exit_open_lockon");
	}

	// Reentrancy-Test: Beim Auslösen wird Lock in die Queue eingereiht
	inline function onEnter_alarm_Triggered() {
		hookLog.push("enter_triggered");
		send(Lock);
	}
}

class Test {
	public static function run():Void {
		var effects:Array<String> = [];
		var sys = new SecurityDoor(e -> effects.push(Std.string(e)));

		// 1. Initial-Hook prüfen
		assert(sys.hookLog.join(",") == "enter_closed", "Initial hook failed");

		// 2. Verschlossene Tür darf nicht aufgehen
		sys.send(OpenDoor);
		assert(sys.door.match(Closed(true)), "Locked door should not open");

		// 3. Alarm scharfschalten & Countdown ablaufen lassen
		sys.send(ArmAlarm);
		sys.timerStep(3.5);
		assert(sys.alarm.match(Armed(0.0)), "Alarm should be armed at 0.0");

		// 4. Aufschließen & Öffnen -> prüft Parent->Child Enter-Hooks + parallelen Alarm + Reentrancy
		sys.hookLog.resize(0);
		sys.send(Unlock);
		sys.send(OpenDoor);
		assert(sys.door.match(Open(Scan(10))), "Door should be Open(Scan(10))");
		assert(sys.alarm.match(Triggered), "Alarm should be Triggered");
		assert(effects.join(",") == "Log(door_opened),SirenOn", "Effects mismatch: " + effects);
		assert(sys.hookLog.join(",") == "exit_closed,enter_open,enter_open_scan,enter_triggered",
			"Hook order mismatch: " + sys.hookLog);

		// 5. Sub-State-Wechsel innerhalb von Open (Scan -> LockOn): Parent darf NICHT neu betreten werden!
		sys.hookLog.resize(0);
		sys.send(SwitchToLockOn("Drone_42"));
		assert(sys.door.match(Open(LockOn("Drone_42"))), "Sub-state should be LockOn(Drone_42)");
		assert(sys.hookLog.join(",") == "exit_open_scan,enter_open_lockon",
			"Sub-state transition hooks wrong: " + sys.hookLog);

		// 6. JSON-Roundtrip OHNE Entry-Hooks (triggerEntryHooks = false)
		var json = sys.toJson();
		var restoredSilent = new SecurityDoor();
		restoredSilent.hookLog.resize(0);
		restoredSilent.fromJson(json, false);
		assert(restoredSilent.door.match(Open(LockOn("Drone_42"))) && restoredSilent.alarm.match(Triggered),
			"Silent JSON restore state mismatch");
		assert(restoredSilent.hookLog.length == 0,
			"Silent JSON restore should not fire hooks: " + restoredSilent.hookLog);

		// 7. JSON-Roundtrip MIT Entry-Hooks (triggerEntryHooks = true) -> prüft Parent->Child-Reihenfolge beim Laden!
		var restoredWithHooks = new SecurityDoor();
		restoredWithHooks.hookLog.resize(0);
		restoredWithHooks.fromJson(json, true);
		assert(restoredWithHooks.door.match(Open(LockOn("Drone_42"))),
			"Hooked JSON restore state mismatch");
		assert(restoredWithHooks.hookLog.join(",") == "enter_open,enter_open_lockon,enter_triggered",
			"Hooked JSON restore hooks wrong: " + restoredWithHooks.hookLog);

		// 8. Schließen aus tiefem Sub-State -> prüft Child->Parent Exit-Reihenfolge!
		restoredWithHooks.hookLog.resize(0);
		restoredWithHooks.send(CloseDoor);
		assert(restoredWithHooks.door.match(Closed(false)), "Door should be Closed(false)");
		assert(restoredWithHooks.hookLog.join(",") == "exit_open_lockon,exit_open,enter_closed",
			"Deep exit hook order wrong: " + restoredWithHooks.hookLog);

		trace("=== ALLE 8 TESTS ERFOLGREICH BESTANDEN! ===");
	}

	private static function assert(cond:Bool, msg:String):Void {
		if (!cond) throw 'ASSERTION FAILED: $msg';
	}
}
