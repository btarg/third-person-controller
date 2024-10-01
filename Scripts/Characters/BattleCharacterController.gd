extends CharacterBody3D
class_name BattleCharacterController

@onready var nav_agent : NavigationAgent3D = get_node_or_null("NavigationAgent3D")

var _should_move := false
func set_move_target(position: Vector3) -> void:
    if nav_agent:
        nav_agent.set_target_position(position)
    else:
        push_warning("No NavigationAgent3D found for " + name)
        return
    _should_move = true

func nav_update() -> void:
    if not nav_agent or not _should_move:
        return

    var destination := nav_agent.get_next_path_position()
    var local_destination := destination - global_position

    if local_destination.length() < 0.1:
        _should_move = false # finished moving
        return

    var direction := local_destination.normalized()
    velocity = direction * 5.0

    apply_floor_snap()
    move_and_slide()