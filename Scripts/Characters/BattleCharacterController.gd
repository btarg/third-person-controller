extends CharacterBody3D
class_name BattleCharacterController

@export_group("Movement variables")
@export var walk_speed : float = 2.0
@export var run_speed : float = 6.0
@export var jump_strength : float = 15.0
@export var gravity : float = 50.0

@onready var nav_agent : NavigationAgent3D = get_node_or_null("NavigationAgent3D")
@onready var battle_character := $BattleCharacter as BattleCharacter

@onready var character_mesh := $Mesh as Node3D
# Used for lerping the rotation animation
const LERP_VALUE : float = 0.15

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
# Stuck detection
var _last_movement_deltas := PackedFloat32Array()
var _buffer_head_idx := 0
const MOVEMENT_DELTA_SAMPLES := 6


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
    reset_to_idle()

    _last_movement_deltas.clear()
    _buffer_head_idx = 0

    print(battle_character.character_name + " stopped moving")
    print("Movement left: " + str(movement_left))

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
    
    var last_amount_moved := amount_moved
    amount_moved = (_last_successful_position - global_position).length()
    var delta_move := absf(amount_moved - last_amount_moved)
    
    if _last_movement_deltas.size() < MOVEMENT_DELTA_SAMPLES:
        _last_movement_deltas.append(delta_move)
    else:
        _last_movement_deltas[_buffer_head_idx] = delta_move
        _buffer_head_idx = (_buffer_head_idx + 1) % MOVEMENT_DELTA_SAMPLES

    # print(_last_movement_deltas)
    
    # Sum the deltas
    if _last_movement_deltas.size() == MOVEMENT_DELTA_SAMPLES:
        var sum_deltas := 0.0
        for i in range(_last_movement_deltas.size()):
            sum_deltas += _last_movement_deltas[i]
        var average_delta := sum_deltas / MOVEMENT_DELTA_SAMPLES
    
        # print("[MOVE] Average delta: " + str(average_delta))
        
        if is_zero_approx(average_delta):
            print("[MOVE] Stuck detected!")
            stop_moving()
            return

    movement_left -= amount_moved
    if movement_left < 0:
        movement_left = 0

    var direction := local_destination.normalized()
    # FIX: Only set the X and Z to avoid gravity being discarded
    velocity.x = direction.x * run_speed
    velocity.z = direction.z * run_speed

    # FIX: Only rotate the mesh, not the actual player body (this is how third-person camera does it)
    character_mesh.rotation.y = lerp_angle(character_mesh.rotation.y, atan2(velocity.x, velocity.z), LERP_VALUE)

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
        # print(name + " is not on floor!")
        animator.set("parameters/ground_air_transition/transition_request", "air")



func reset_to_idle() -> void:
    print("[ANIM] Resetting to idle")
    animator.set("parameters/ground_air_transition/transition_request", "grounded")
    var tween := create_tween()
    tween.tween_property(animator, "parameters/iwr_blend/blend_amount", -1.0, 0.25)