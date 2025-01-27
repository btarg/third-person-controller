extends Polygon2D


func _input(event: InputEvent) -> void:
    # on click set global position
    if event is InputEventMouseButton:
        if event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
            set_global_position(get_viewport().get_mouse_position())