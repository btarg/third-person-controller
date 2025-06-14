class_name SpellAreaNotifier extends Node

enum NotificationType {
    SELECT, ## This character is selected for spell casting
    EFFECT_TRIGGER ## This character has entered the area of effect for a spell
}

signal OnEntered(area: SpellArea, type: NotificationType)
signal OnExited(area: SpellArea, type: NotificationType)

func _ready() -> void:
    OnEntered.connect(_on_area_entered)
    OnExited.connect(_on_area_exited)

func _on_area_entered(_area: SpellArea, type: NotificationType) -> void:
    if type == NotificationType.EFFECT_TRIGGER:
        print(get_parent().name + ": Entered area of effect for spell")
    elif type == NotificationType.SELECT:
        print(get_parent().name + ": Selected for spell casting")

func _on_area_exited(_area: SpellArea, type: NotificationType) -> void:
    if type == NotificationType.EFFECT_TRIGGER:
        print(get_parent().name + ": Exited area of effect for spell")
    elif type == NotificationType.SELECT:
        print(get_parent().name + ": Deselected for spell casting")

func _exit_tree() -> void:
    OnEntered.disconnect(_on_area_entered)
    OnExited.disconnect(_on_area_exited)