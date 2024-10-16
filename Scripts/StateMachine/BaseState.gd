extends Node
class_name State

@onready var state_machine := get_parent() as StateMachine

@warning_ignore("UNUSED_SIGNAL")
signal Transitioned
var active := false

## Called when the state is entered
func enter() -> void: pass
## Called when the state is exited
func exit() -> void: pass
## Updates every _process() update (When state is active)
@warning_ignore("UNUSED_PARAMETER")
func _state_process(delta: float) -> void: pass
## Updates every _physics_process() update (When state is active)
@warning_ignore("UNUSED_PARAMETER")
func _state_physics_process(delta: float) -> void: pass
## Updates every _input() update (When state is active)
@warning_ignore("UNUSED_PARAMETER")
func _state_input(event: InputEvent) -> void: pass
## Updates every _unhandled_input() update (When state is active)
@warning_ignore("UNUSED_PARAMETER")
func _state_unhandled_input(event: InputEvent) -> void: pass