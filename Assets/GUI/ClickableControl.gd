extends Control
class_name ClickableControl

signal OnClicked

func _gui_input(event: InputEvent) -> void:
    if event is InputEventMouseButton:
        if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
            OnClicked.emit()