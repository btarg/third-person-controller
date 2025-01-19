extends Control

# Key: Label, Value: Control
var labels := {}
var label_settings := preload("res://Assets/GUI/battle/damage_number.tres") as LabelSettings

@onready var container := $HBoxContainer as HBoxContainer
@export var display_seconds := 2.0

var is_animating := false

var _track_node: Node3D = null
var _track_camera: Camera3D = null

func _process(_delta: float) -> void:
    if not _track_node or not _track_camera:
        return

    var _track_position := _track_node.global_position
    for child in _track_node.get_children():
        if child is CollisionShape3D:
            _track_position = child.global_transform.origin
            if child.shape is BoxShape3D:
                _track_position.y += (((child as CollisionShape3D).shape) as BoxShape3D).size.y / 2
            break

    if _track_camera.is_position_behind(_track_position):
        return
    
    var centered_pos := _track_camera.unproject_position(_track_position)
    centered_pos.y -= container.size.y / 2
    set_position(centered_pos)

func _setup_labels(display_amount: int) -> void:

    for c in str(display_amount).split(""):
        var new_label := Label.new()
        new_label.text = c
        new_label.label_settings = label_settings.duplicate()
        new_label.visible = false
        add_child(new_label)

        # create a new "target" node for the tween
        var target := Control.new()
        target.custom_minimum_size = new_label.size
        container.add_child(target)
        labels.get_or_add(new_label, target)
    
    for label in labels:
        var target = labels.get(label)
        label.set_position(Vector2(target.position.x, target.position.y + 200))

func _reset_labels() -> void:
    for label in labels:
        var target := labels.get(label) as Control
        target.queue_free()
        label.queue_free()
    labels.clear()

    _track_node = null
    _track_camera = null

func _animate_labels() -> void:
    var i := 1
    is_animating = true
    for label in labels:
        var target := labels.get(label) as Control
        label.show()
        # slightly above target position
        var target_position_with_offset := Vector2(target.position.x, target.position.y - 50)

        var tween := get_tree().create_tween()
        tween.tween_property(label, "position", target_position_with_offset, 0.05).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
        await tween.finished
        
        tween = get_tree().create_tween()
        var tween_time := (0.1 * i)
        tween.tween_property(label, "position", target.position, tween_time).set_trans(Tween.TRANS_SPRING)
        await tween.finished
        i += 1
    is_animating = false

    await get_tree().create_timer(display_seconds).timeout
    _reset_labels()

func display_damage_number(damage: int, _result: BattleEnums.ESkillResult, focus_node: Node3D, cam: Camera3D) -> void:
    if is_animating:
        return
    
    _track_node = focus_node
    _track_camera = cam

    _setup_labels(damage)
    _animate_labels()