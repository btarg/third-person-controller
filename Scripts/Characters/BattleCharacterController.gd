extends CharacterBody3D
class_name BattleCharacterController

@export_group("Movement variables")
@export var walk_speed : float = 2.0
@export var run_speed : float = 6.0
@export var jump_strength : float = 15.0
@export var gravity : float = 50.0

@onready var nav_agent : NavigationAgent3D = get_node_or_null("NavigationAgent3D")
@onready var battle_character := $BattleCharacter as BattleCharacter

# Animation
@onready var animator : AnimationTree = get_node_or_null("AnimationTree")
var is_running: bool = false
const ANIMATION_BLEND : float = 7.0

# Movement stat
# @onready var base_movement := battle_character.stats.get_stat(CharacterStatEntry.ECharacterStat.Movement)

# DEBUG
var base_movement := 999999999.0
var movement_left := 0.0

var _should_move := false
var amount_moved := 0.0

var _last_successful_position := Vector3.INF

func _ready() -> void:
    BattleSignalBus.TurnStarted.connect(reset_movement)
    reset_movement(battle_character)

func reset_movement(character: BattleCharacter) -> void:
    if character != battle_character:
        return
    movement_left = base_movement
    _last_successful_position = global_position

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
    reset_to_idle()

func nav_update(delta: float) -> void:
    velocity.y -= gravity * delta
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
    # print("[MOVE] Movement left: " + str(movement_left))

    movement_left -= amount_moved
    if movement_left < 0:
        movement_left = 0

    var direction := local_destination.normalized()
    # FIX: Only set the X and Z to avoid gravity being discarded
    velocity.x = direction.x * run_speed
    velocity.z = direction.z * run_speed

    # rotate towards the destination
    var target_rotation := atan2(direction.x, direction.z)
    rotation.y = lerp_angle(rotation.y, target_rotation, 0.1)

    # this needs to be set before move_and_slide
    _last_successful_position = global_position
    
    apply_floor_snap()
    move_and_slide()

    is_running = true
    animate(delta)

func animate(delta: float) -> void:

    if animator == null:
        return

    if is_on_floor():
        animator.set("parameters/ground_air_transition/transition_request", "grounded")
        
        if velocity.length() > 0:
            if is_running:
                animator.set("parameters/iwr_blend/blend_amount", lerp(animator.get("parameters/iwr_blend/blend_amount"), 1.0, delta * ANIMATION_BLEND))
            else:
                animator.set("parameters/iwr_blend/blend_amount", lerp(animator.get("parameters/iwr_blend/blend_amount"), 0.0, delta * ANIMATION_BLEND))
        else:
            animator.set("parameters/iwr_blend/blend_amount", lerp(animator.get("parameters/iwr_blend/blend_amount"), -1.0, delta * ANIMATION_BLEND))
    else:
        print(name + " is not on floor!")
        animator.set("parameters/ground_air_transition/transition_request", "air")



func reset_to_idle() -> void:
    print("[ANIM] Resetting to idle")
    animator.set("parameters/ground_air_transition/transition_request", "grounded")
    var tween := create_tween()
    tween.tween_property(animator, "parameters/iwr_blend/blend_amount", -1.0, 0.25)