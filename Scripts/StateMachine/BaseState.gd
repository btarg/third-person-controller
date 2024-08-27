extends Node
class_name State

signal Transitioned
var active := false

func enter() -> void: pass
func exit() -> void: pass
## Updates every _process() update (When state is active)
func update(delta: float) -> void: pass
## Updates every _physics_process() update (When state is active)
func physics_update(delta: float) -> void: pass
## Updates every _input() update (When state is active)
func input_update(event: InputEvent) -> void: pass
## Updates every _unhandled_input() update (When state is active)
func unhandled_input_update(event: InputEvent) -> void: pass