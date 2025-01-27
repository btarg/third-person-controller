extends AnimatedSprite2D

func _ready() -> void:
    speed_scale = 2.0
    frame = 0
    play("fill")

func _input(event: InputEvent) -> void:
    if event is InputEventKey and event.is_pressed() and event.keycode == KEY_SPACE:
        play_backwards("fill")
