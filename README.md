# enumstates
haxe macro powered statecharts using enums and pattern matching

(work in progress)


stateDiagram-v2
    [*] --> PlayerStateMachine

    state PlayerStateMachine {
        state movement {
            [*] --> Grounded
            Grounded : entry / onEnter_movement_Grounded()
            Grounded : exit / onExit_movement_Grounded()
            state Grounded {
                [*] --> Idle
                Running : entry / PlayAnim("run"), SetDustTrail(true)
                Running : exit / SetDustTrail(false)
                Idle : entry / PlayAnim("idle")
            }
            state Airborne {
                Rising : entry / PlayAnim("jump_up")
                Falling : entry / PlayAnim("fall_down")
            }

            Grounded --> Rising : Jump [action == Ready]
            Idle --> Running : StartRun(speed)
            Running --> Idle : StopRun
            Airborne --> Idle : Land
            Rising --> Falling : TimerStep(dt) [action.match(Dashing(_)) ? 0.0 : vy - 9.81 * dt <= 0]
            Falling --> Rising : TimerStep(dt) [!(action.match(Dashing(_)) ? 0.0 : vy - 9.81 * dt <= 0)]
        }

        --

        state action {
            [*] --> Ready

            Ready --> Dashing : Dash
            Dashing --> Ready : TimerStep(dt) [t - dt <= 0]
        }
    }