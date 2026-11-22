# enumstates
haxe macro powered statecharts using enums and pattern matching

(work in progress)


player jumping state sample:
```mermaid
stateDiagram-v2
    [*] --> PlayerStateMachine

    state PlayerStateMachine {
        state movement {
            [*] --> Grounded
            state Grounded {
                [*] --> Idle
                Running : entry / PlayAnim("run"), SetDustTrail(true)
                Running : exit / SetDustTrail(false)
                Idle : entry / PlayAnim("idle")
            }
            note left of Grounded : entry / onEnter_movement_Grounded(), exit / onExit_movement_Grounded()
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
            Ready
            Dashing

            Ready --> Dashing : Dash
            Dashing --> Ready : TimerStep(dt) [t - dt <= 0]
        }
    }
```


car sample:
```mermaid
stateDiagram-v2
    [*] --> Car

    state Car {
        state ignition {
            [*] --> KeyOff
            state KeyOn {
                Stopped
                Running : entry / PlaySound("engine_start")
                Running : exit / PlaySound("engine_stop")
            }
            note left of KeyOn : entry / SetDashboardPower(true), exit / SetDashboardPower(false)
            KeyOff

            KeyOff --> Stopped : TurnKeyOn
            KeyOn --> KeyOff : TurnKeyOff
            Stopped --> Running : PressStartButton [clutch == Pressed]
            Running --> Stopped : PressStopButton
        }

        --

        state lights {
            [*] --> LightsOff
            LightsOn : entry / SetHeadlights(true)
            LightsOn : exit / SetHeadlights(false)
            LightsOff

            LightsOff --> LightsOn : ToggleLights
            LightsOn --> LightsOff : ToggleLights
            LightsOn --> LightsOff : TurnKeyOff
        }

        --

        state clutch {
            [*] --> Released
            Released
            Pressed

            Released --> Pressed : PressClutch
            Pressed --> Released : ReleaseClutch
        }
    }
```


car and substate handling:
```mermaid
stateDiagram-v2
    [*] --> CarSubstate

    state CarSubstate {
        state ignition {
            [*] --> KeyOff
            state KeyOn {
                Stopped
                Running : entry / PlaySound("engine_start")
                Running : exit / PlaySound("engine_stop")
            }
            note left of KeyOn : entry / SetDashboardPower(true), exit / SetDashboardPower(false)
            KeyOff

            KeyOff --> Stopped : TurnKeyOn
            KeyOn --> KeyOff : TurnKeyOff
            Stopped --> Running : PressStartButton [clutch == Pressed]
            Running --> Stopped : PressStopButton
        }

        --

        state lights {
            [*] --> LightsOff
            LightsOn : entry / SetHeadlights(true)
            LightsOn : exit / SetHeadlights(false)
            LightsOff

            LightsOff --> LightsOn : ToggleLights
            LightsOn --> LightsOff : ToggleLights
            LightsOn --> LightsOff : TurnKeyOff
        }

        --

        state clutch {
            [*] --> Released
            Released
            Pressed

            Released --> Pressed : PressClutch
            Pressed --> Released : ReleaseClutch
        }
    }
```

car with cranking:
```mermaid
stateDiagram-v2
    [*] --> CarCranking

    state CarCranking {
        state ignition {
            [*] --> KeyOff
            state KeyOn {
                Stopped
                Running : entry / PlaySound("engine_idle_loop")
                Running : exit / StopSound("engine_idle_loop")
                Cranking : entry / PlaySound("starter_crank")
                Cranking : exit / StopSound("starter_crank")
            }
            note left of KeyOn : entry / SetDashboardPower(true), exit / SetDashboardPower(false)
            KeyOff

            KeyOff --> Stopped : TurnKeyOn
            KeyOn --> KeyOff : TurnKeyOff
            Stopped --> Cranking : PressStartButton [clutch == Pressed]
            Cranking --> Stopped : ReleaseClutch
            Cranking --> Running : TimerStep(dt) [t - dt <= 0]
            Running --> Stopped : PressStopButton
        }

        --

        state lights {
            [*] --> LightsOff
            LightsOn : entry / SetHeadlights(true)
            LightsOn : exit / SetHeadlights(false)
            LightsOff

            LightsOff --> LightsOn : ToggleLights
            LightsOn --> LightsOff : ToggleLights
            LightsOn --> LightsOff : TurnKeyOff
        }

        --

        state clutch {
            [*] --> Released
            Released
            Pressed

            Released --> Pressed : PressClutch
            Pressed --> Released : ReleaseClutch
        }
    }
```