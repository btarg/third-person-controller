@abstract class_name State extends Node

@onready var state_machine := get_parent() as StateMachine

@warning_ignore("UNUSED_SIGNAL")
signal Transitioned
var active := false

## Called when the state is entered
@abstract func enter() -> void
## Called when the state is exited
@abstract func exit() -> void
## Updates every _process() update (When state is active)
@abstract func _state_process(delta: float) -> void
## Updates every _physics_process() update (When state is active)
@abstract func _state_physics_process(delta: float) -> void
## Updates every _input() update (When state is active)
@abstract func _state_input(event: InputEvent) -> void
## Updates every _unhandled_input() update (When state is active)
@abstract func _state_unhandled_input(event: InputEvent) -> void