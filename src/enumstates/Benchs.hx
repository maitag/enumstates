package enumstates;

import haxe.Timer;


enum BenchMoveState {
	Patrol(timer:Float);
	Chase(targetDist:Float);
	Stunned(left:Float);
}

enum BenchWeaponState {
	Ready;
	Cooldown(left:Float);
}

enum BenchEvent {
	Tick; // TimerStep(dt:Float); // Tick is for optimization
	SpotEnemy(dist:Float);
	Hit(duration:Float);
}

enum BenchEffect {
	Attack;
	Recover;
}

class BenchAgent implements EnumStates<BenchEvent, BenchEffect> {
	@:region
	public var move:BenchMoveState = Patrol(0.0);

	@:region
	public var weapon:BenchWeaponState = Ready;

	public var attackCount:Int = 0;

	inline function update_move(event:BenchEvent):BenchMoveState {
		return switch [move, weapon, event] {
			// case [Patrol(t), _, TimerStep(dt)]:
			case [Patrol(t), _, Tick]:
				Patrol(t + dt);
			case [Patrol(_), _, SpotEnemy(dist)]:
				Chase(dist);
			// case [Chase(dist), _, TimerStep(dt)]:
			case [Chase(dist), _, Tick]:
				var nextDist = dist - 5.0 * dt;
				1.5 >= nextDist ? Patrol(0.0) : Chase(nextDist);
			case [_, _, Hit(dur)]:
				Stunned(dur);
			// case [Stunned(left), _, TimerStep(dt)]:
			case [Stunned(left), _, Tick]:
				var rem = left - dt;
				0.0 >= rem ? Patrol(0.0) : Stunned(rem);
			default:
				move;
		}
	}

	inline function update_weapon(event:BenchEvent):BenchWeaponState {
		return switch [move, weapon, event] {
			// case [Chase(dist), Ready, TimerStep(_)] if (3.0 >= dist):
			case [Chase(dist), Ready, Tick] if (3.0 >= dist):
				emit(Attack);
				Cooldown(0.5);
			// case [_, Cooldown(left), TimerStep(dt)]:
			case [_, Cooldown(left), Tick]:
				var rem = left - dt;
				if (0.0 >= rem) {
					emit(Recover);
					Ready;
				} else {
					Cooldown(rem);
				}
			default:
				weapon;
		}
	}
}

class Benchs {
	public static function run(entityCount:Int = 10000, frames:Int = 600):Void {
		var tCreateStart = Timer.stamp();
		var agents:Array<BenchAgent> = [];
		agents.resize(entityCount);

		for (i in 0...entityCount) {
			var a = new BenchAgent();
			a.onEffect = function(eff) {
				if (eff == Attack) a.attackCount++;
			};
			if (i % 3 == 1) a.send(SpotEnemy(8.0));
			else if (i % 3 == 2) a.send(Hit(0.4));
			agents[i] = a;
		}
		var createMs = (Timer.stamp() - tCreateStart) * 1000.0;

		for (w in 0...10) {
			for (i in 0...entityCount) {
				agents[i].timerStep(0.016);
			}
		}

		var dt = 1.0 / 60.0;
		var tStart = Timer.stamp();

		for (f in 0...frames) {
			for (i in 0...entityCount) {
				agents[i].timerStep(dt);
			}
		}

		var totalSec = Timer.stamp() - tStart;
		var totalMs = totalSec * 1000.0;
		var totalUpdates = (entityCount : Float) * frames;
		var msPerFrame = totalMs / frames;
		var updatesPerSec = totalUpdates / totalSec;

		var totalAttacks = 0;
		for (a in agents) totalAttacks += a.attackCount;

		trace('=== STATECHART BENCHMARK ($entityCount entities x $frames Frames) ===');
		trace('  instantiating:    ${Math.round(createMs * 100) / 100} ms');
		trace('  total time:       ${Math.round(totalMs * 100) / 100} ms');
		trace('  time per frame:   ${Math.round(msPerFrame * 1000) / 1000} ms (budget at 60 FPS: 16.67 ms)');
		trace('  updatesPerSecond: ${Math.round(updatesPerSec / 1000)} k');
		trace('  triggered attacks:$totalAttacks');
	}
}
