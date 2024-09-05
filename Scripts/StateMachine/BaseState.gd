extends Node
class_name State

@warning_ignore("UNUSED_SIGNAL")
signal Transitioned
var active := false

## Called when the state is entered
func enter() -> void: pass
## Called when the state is exited
func exit() -> void: pass
## Updates every _process() update (When state is active)
@warning_ignore("UNUSED_PARAMETER")
func update(delta: float) -> void: pass
## Updates every _physics_process() update (When state is active)
@warning_ignore("UNUSED_PARAMETER")
func physics_update(delta: float) -> void: pass
## Updates every _input() update (When state is active)
@warning_ignore("UNUSED_PARAMETER")
func input_update(event: InputEvent) -> void: pass
## Updates every _unhandled_input() update (When state is active)
@warning_ignore("UNUSED_PARAMETER")
func unhandled_input_update(event: InputEvent) -> void: pass