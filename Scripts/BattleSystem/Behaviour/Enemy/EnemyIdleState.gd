extends State
class_name EnemyIdleState

func go_to_think_state() -> void:
    if active:
        print("Going to think...")
        Transitioned.emit(self, "BattleStartThinkState")

## Called when the state is entered
func enter() -> void: pass
## Called when the state is exited
func exit() -> void: pass
## Updates every _process() update (When state is active)
func update(delta: float) -> void: pass
## Updates every _physics_process() update (When state is active)
func physics_update(delta: float) -> void: pass
## Updates every _input() update (When state is active)
func input_update(event: InputEvent) -> void: pass
## Updates every _unhandled_input() update (When state is active)
func unhandled_input_update(event: InputEvent) -> void: pass