extends Node
class_name State

signal Transitioned
var active := false

func enter() -> void: pass
func exit() -> void: pass
func update(delta: float) -> void: pass
func physics_update(delta: float) -> void: pass
func input_update(event: InputEvent) -> void: pass
