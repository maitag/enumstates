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
                state Running {
                    state "onEnter_movement_Grounded_Running:<br>PlayAnim(run), SetDustTrail(true)" as OnEnterHookRunning
                }
                state Running {
                    state "onExit_movement_Grounded_Running:<br>SetDustTrail(false)" as OnExitHookRunning
                }
                state Idle {
                    state "onEnter_movement_Grounded_Idle:<br>PlayAnim(idle)" as OnEnterHookIdle
                }
                state "onEnter_movement_Grounded" as OnEnterHookGrounded
                state "onExit_movement_Grounded" as OnExitHookGrounded
            }
            state Airborne {
                state Rising {
                    state "onEnter_movement_Airborne_Rising:<br>PlayAnim(jump_up)" as OnEnterHookRising
                }
                state Falling {
                    state "onEnter_movement_Airborne_Falling:<br>PlayAnim(fall_down)" as OnEnterHookFalling
                }
            }

            Running --> Rising : Jump [action == Ready]
            Idle --> Rising : Jump [action == Ready]
            Idle --> Running : StartRun(speed)
            Running --> Idle : StopRun
            Rising --> Idle : Land
            Falling --> Idle : Land
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
classDef green fill:#d4edda,stroke:#28a745,color:#155724
classDef red fill:#f8d7da,stroke:#dc3545,color:#721c24,font-weight:bold
classDef any fill:#aaaaaa,stroke-width:0px,color:#721c24, font-size:6px, rx:10px, ry:10px
class ___ any
class OnEnterHookRunning green
class OnEnterHookRising green
class OnEnterHookIdle green
class OnEnterHookGrounded green
class OnEnterHookFalling green
class OnExitHookRunning red
class OnExitHookRising red
class OnExitHookIdle red
class OnExitHookGrounded red
class OnExitHookFalling red
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
                state Running {
                    state "onEnter_ignition_KeyOn_Running:<br>PlaySound(engine_start)" as OnEnterHookRunning
                }
                state Running {
                    state "onExit_ignition_KeyOn_Running:<br>PlaySound(engine_stop)" as OnExitHookRunning
                }
                state "onEnter_ignition_KeyOn:<br>SetDashboardPower(true)" as OnEnterHookKeyOn
                state "onExit_ignition_KeyOn:<br>SetDashboardPower(false)" as OnExitHookKeyOn
            }
            KeyOff

            KeyOff --> Stopped : TurnKeyOn
            Stopped --> KeyOff : TurnKeyOff
            Running --> KeyOff : TurnKeyOff
            Stopped --> Running : PressStartButton [clutch == Pressed]
            Running --> Stopped : PressStopButton
        }

        --

        state lights {
            [*] --> LightsOff
            state LightsOn {
                state "onEnter_lights_LightsOn:<br>SetHeadlights(true)" as OnEnterHookLightsOn
            }
            state LightsOn {
                state "onExit_lights_LightsOn:<br>SetHeadlights(false)" as OnExitHookLightsOn
            }
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
classDef green fill:#d4edda,stroke:#28a745,color:#155724
classDef red fill:#f8d7da,stroke:#dc3545,color:#721c24,font-weight:bold
classDef any fill:#aaaaaa,stroke-width:0px,color:#721c24, font-size:6px, rx:10px, ry:10px
class ___ any
class OnEnterHookRunning green
class OnEnterHookKeyOn green
class OnExitHookRunning red
class OnExitHookKeyOn red
class OnEnterHookLightsOn green
class OnExitHookLightsOn red
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
                state Running {
                    state "onEnter_ignition_KeyOn_Running:<br>PlaySound(engine_start)" as OnEnterHookRunning
                }
                state Running {
                    state "onExit_ignition_KeyOn_Running:<br>PlaySound(engine_stop)" as OnExitHookRunning
                }
                state "onEnter_ignition_KeyOn:<br>SetDashboardPower(true)" as OnEnterHookKeyOn
                state "onExit_ignition_KeyOn:<br>SetDashboardPower(false)" as OnExitHookKeyOn
            }
            KeyOff

            KeyOff --> Stopped : TurnKeyOn
            Stopped --> KeyOff : TurnKeyOff
            Running --> KeyOff : TurnKeyOff
            Stopped --> Running : PressStartButton [clutch == Pressed]
            Running --> Stopped : PressStopButton
        }

        --

        state lights {
            [*] --> LightsOff
            state LightsOn {
                state "onEnter_lights_LightsOn:<br>SetHeadlights(true)" as OnEnterHookLightsOn
            }
            state LightsOn {
                state "onExit_lights_LightsOn:<br>SetHeadlights(false)" as OnExitHookLightsOn
            }
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
classDef green fill:#d4edda,stroke:#28a745,color:#155724
classDef red fill:#f8d7da,stroke:#dc3545,color:#721c24,font-weight:bold
classDef any fill:#aaaaaa,stroke-width:0px,color:#721c24, font-size:6px, rx:10px, ry:10px
class ___ any
class OnEnterHookRunning green
class OnEnterHookKeyOn green
class OnExitHookRunning red
class OnExitHookKeyOn red
class OnEnterHookLightsOn green
class OnExitHookLightsOn red
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
                state Running {
                    state "onEnter_ignition_KeyOn_Running:<br>PlaySound(engine_idle_loop)" as OnEnterHookRunning
                }
                state Running {
                    state "onExit_ignition_KeyOn_Running:<br>StopSound(engine_idle_loop)" as OnExitHookRunning
                }
                state Cranking {
                    state "onEnter_ignition_KeyOn_Cranking:<br>PlaySound(starter_crank)" as OnEnterHookCranking
                }
                state Cranking {
                    state "onExit_ignition_KeyOn_Cranking:<br>StopSound(starter_crank)" as OnExitHookCranking
                }
                state "onEnter_ignition_KeyOn:<br>SetDashboardPower(true)" as OnEnterHookKeyOn
                state "onExit_ignition_KeyOn:<br>SetDashboardPower(false)" as OnExitHookKeyOn
            }
            KeyOff

            KeyOff --> Stopped : TurnKeyOn
            Stopped --> KeyOff : TurnKeyOff
            Running --> KeyOff : TurnKeyOff
            Cranking --> KeyOff : TurnKeyOff
            Stopped --> Cranking : PressStartButton [clutch == Pressed]
            Cranking --> Stopped : ReleaseClutch
            Cranking --> Running : Tick [t - dt <= 0]
            Running --> Stopped : PressStopButton
        }

        --

        state lights {
            [*] --> LightsOff
            state LightsOn {
                state "onEnter_lights_LightsOn:<br>SetHeadlights(true)" as OnEnterHookLightsOn
            }
            state LightsOn {
                state "onExit_lights_LightsOn:<br>SetHeadlights(false)" as OnExitHookLightsOn
            }
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
classDef green fill:#d4edda,stroke:#28a745,color:#155724
classDef red fill:#f8d7da,stroke:#dc3545,color:#721c24,font-weight:bold
classDef any fill:#aaaaaa,stroke-width:0px,color:#721c24, font-size:6px, rx:10px, ry:10px
class ___ any
class OnEnterHookRunning green
class OnEnterHookKeyOn green
class OnEnterHookCranking green
class OnExitHookRunning red
class OnExitHookKeyOn red
class OnExitHookCranking red
class OnEnterHookLightsOn green
class OnExitHookLightsOn red
```