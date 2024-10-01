extends CharacterBody3D
class_name BattleCharacterController

@onready var nav_agent : NavigationAgent3D = get_node_or_null("NavigationAgent3D")
@onready var battle_character := $BattleCharacter as BattleCharacter

var base_movement := 0.0
var movement_left := 0.0

var _should_move := false
var amount_moved := 0.0

var _last_successful_position := Vector3.INF

func _ready() -> void:
    base_movement = battle_character.stats.get_stat(CharacterStatEntry.ECharacterStat.Movement)
    movement_left = base_movement


func set_move_target(target_pos: Vector3) -> void:
    if _last_successful_position == Vector3.INF:
        _last_successful_position = global_position
    amount_moved = 0.0
    
    print("[MOVE] %s has %s movement" % [battle_character.character_name, str(movement_left)])

    if movement_left <= 0:
        print("[MOVE] %s has no movement left" % battle_character.character_name)
        return

    if nav_agent:
        nav_agent.set_target_position(target_pos)
    else:
        push_warning("No NavigationAgent3D found for " + name)
        return
    _should_move = true

func stop_moving() -> void:
    _should_move = false
    if velocity.length() == 0:
        print(battle_character.character_name + " is not moving")
        return

    velocity = Vector3.ZERO
    print(battle_character.character_name + " stopped moving")
    print("Movement left: " + str(movement_left))

func nav_update() -> void:
    if (not nav_agent) or (not _should_move):
        return

    var destination := nav_agent.get_next_path_position()
    var local_destination := destination - global_position
    # TODO: figure out why we need an offset for destination
    if (local_destination.length() <= 0.6
    or movement_left <= 0):
        stop_moving()
        return

    amount_moved = (_last_successful_position - global_position).length()
    print("Amount moved: " + str(amount_moved))

    movement_left -= amount_moved
    if movement_left < 0:
        movement_left = 0

    var direction := local_destination.normalized()
    velocity = direction * 5.0

    # this needs to be set before move_and_slide
    _last_successful_position = global_position

    apply_floor_snap()
    move_and_slide()

    