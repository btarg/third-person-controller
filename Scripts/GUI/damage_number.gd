extends Control
class_name DamageNumber

# Key: Label, Value: Control
var labels := {}
var label_settings := preload("res://Assets/GUI/battle/damage_number.tres") as LabelSettings

var container : HBoxContainer
@export var display_seconds := 2.0

var is_animating := false

var track_node: Node3D = null
var track_camera: Camera3D = null
var display_damage := 0

var skill_element := BattleEnums.EAffinityElement.PHYS
var skill_result := BattleEnums.ESkillResult.SR_SUCCESS

func _process(_delta: float) -> void:
    if not track_node or not track_camera:
        return

    var _track_position := track_node.global_position
    for child in track_node.get_children():
        if child is CollisionShape3D:
            _track_position = child.global_transform.origin
            if child.shape is BoxShape3D:
                _track_position.y += (((child as CollisionShape3D).shape) as BoxShape3D).size.y / 2
            break

    if track_camera.is_position_behind(_track_position):
        return
    
    var centered_pos := track_camera.unproject_position(_track_position)
    centered_pos.y -= container.size.y / 2
    set_position(centered_pos)

func _setup_labels(display_amount: int) -> void:
    var display_string := str(display_amount).split("")
    
    var color := Color.WHITE
    match skill_result:
        BattleEnums.ESkillResult.SR_SUCCESS:
            match skill_element:
                BattleEnums.EAffinityElement.HEAL:
                    color = Color.SPRING_GREEN
                _:
                    color = Color.WHITE
        BattleEnums.ESkillResult.SR_CRITICAL:
            match skill_element:
                BattleEnums.EAffinityElement.HEAL:
                    color = Color.GREEN
                _:
                    color = Color.YELLOW
            display_string.append("!")
        BattleEnums.ESkillResult.SR_RESISTED:
            color = Color.GRAY
        BattleEnums.ESkillResult.SR_FAIL,\
        BattleEnums.ESkillResult.SR_IMMUNE:
            if skill_element != BattleEnums.EAffinityElement.HEAL:
                # add a label for "miss", but not for healing spells
                display_string = "MISS".split("")
                color = Color.GRAY
            else:
                color = Color.AQUAMARINE
        BattleEnums.ESkillResult.SR_REFLECTED:
            # add a label for "reflect"
            display_string = "REFLECT".split("")
            color = Color.GRAY
        _:
            # ABSORB doesn't need a number, because we show the amount healed
            # TODO: add a separate indicator for resisted, absorbed or blocked damage
            queue_free()
            return

    for c in display_string:
        var new_label := Label.new()
        new_label.text = c
        new_label.label_settings = label_settings.duplicate()
        new_label.visible = false
        new_label.modulate = color
        add_child(new_label)

        # create a new "target" node for the tween
        var target := Control.new()
        target.mouse_filter = Control.MOUSE_FILTER_IGNORE
        target.custom_minimum_size = new_label.size
        container.add_child(target)
        labels.get_or_add(new_label, target)
    
    for label in labels:
        var target = labels.get(label)
        label.set_position(Vector2(target.position.x, target.position.y + 200))
        label.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _animate_labels() -> void:
    var i := 1
    is_animating = true
    for label in labels:
        var target := labels.get(label) as Control
        label.show()
        # slightly above target position
        var target_position_with_offset := Vector2(target.position.x, target.position.y - 50)

        var tween : Tween = label.create_tween()
        tween.tween_property(label, "position", target_position_with_offset, 0.05).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
        await tween.finished
        
        tween = label.create_tween()
        var tween_time := (0.1 * i)
        tween.tween_property(label, "position", target.position, tween_time).set_trans(Tween.TRANS_SPRING)
        await tween.finished
        i += 1
    is_animating = false

    await get_tree().create_timer(display_seconds).timeout
    queue_free()

# Use a consructor-like pattern

func _ready() -> void:
    if track_node and track_camera:

        container = HBoxContainer.new()
        add_child(container)

        _setup_labels(display_damage)
        _animate_labels()

static func create_damage_number(damage: int, element: BattleEnums.EAffinityElement, result: BattleEnums.ESkillResult, focus_node: Node3D, cam: Camera3D) -> DamageNumber:
    var damage_number := DamageNumber.new()
    damage_number.mouse_filter = Control.MOUSE_FILTER_IGNORE

    damage_number.track_node = focus_node
    damage_number.track_camera = cam
    damage_number.display_damage = damage
    damage_number.skill_element = element
    damage_number.skill_result = result
    

    return damage_number