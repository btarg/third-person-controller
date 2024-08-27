extends Node3D

var mouse_locked: bool = false

func _ready() -> void:
    toggle_mouse_lock()

func _unhandled_input(event) -> void:
    if event is InputEventKey:
        if event.is_pressed() and event.keycode == KEY_ESCAPE:
            toggle_mouse_lock()

func toggle_mouse_lock() -> void:
    if mouse_locked:
        Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
        mouse_locked = false
    else:
        Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
        mouse_locked = true