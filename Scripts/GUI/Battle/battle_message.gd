extends Control
class_name BattleMessage

@onready var label := $Label as Label


func _ready() -> void:
    label.text = ""

func show_messages(messages: Array[String], duration: float = 1) -> void:
    if messages.size() < 1:
        return

    label.text = messages.pop_front()
    await get_tree().create_timer(duration).timeout
    if messages.size() > 0:
        show_messages(messages, duration)
    else:
        label.text = ""