extends Node3D

var mouse_locked: bool = true

func _unhandled_input(event) -> void:
    if event is InputEventKey:
        if event.is_pressed() and event.keycode == KEY_ESCAPE:
            if mouse_locked:
                Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
                mouse_locked = false
            else:
                Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
                mouse_locked = true