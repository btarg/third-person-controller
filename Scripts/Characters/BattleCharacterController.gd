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
var _position_buffer := PackedVector3Array()
var _buffer_head_idx := 0
const POSITION_SAMPLES := 5
const STUCK_THRESHOLD := 0.3
var _tick_counter := 0
const TICKS_BETWEEN_SAMPLES := 5


func _ready() -> void:
    BattleSignalBus.TurnStarted.connect(reset_movement)
    reset_movement(battle_character)


func reset_movement(character: BattleCharacter) -> void:
    if character != battle_character:
        return
    movement_left = base_movement
    _last_successful_position = global_position

    if nav_agent:
        if not nav_agent.target_reached.is_connected(stop_moving):
            nav_agent.target_reached.connect(stop_moving)

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

func is_moving() -> bool:
    return _should_move && velocity.length() > 0

func stop_moving() -> void:
    if not is_moving():
        print(battle_character.character_name + " is not moving")
        return
    _should_move = false

    velocity = Vector3.ZERO
    reset_to_idle()

    # Reset the buffer
    _last_movement_deltas.clear()
    _position_buffer.clear()
    _buffer_head_idx = 0

    print(battle_character.character_name + " stopped moving")
    print("Movement left: " + str(movement_left))

func nav_update(delta: float) -> void:
    velocity.y -= gravity * delta
    if (not nav_agent) or (not _should_move):
        return

    var destination := nav_agent.get_next_path_position()
    var local_destination := destination - global_position
    
    amount_moved = (_last_successful_position - global_position).length()
    
    # Store position every N ticks
    _tick_counter += 1
    if _tick_counter >= TICKS_BETWEEN_SAMPLES:
        _tick_counter = 0
        if _position_buffer.size() < POSITION_SAMPLES:
            _position_buffer.append(global_position)
        else:
            _position_buffer[_buffer_head_idx] = global_position
            _buffer_head_idx = (_buffer_head_idx + 1) % POSITION_SAMPLES
    
    # Check for stuck condition when buffer is full
    if _position_buffer.size() == POSITION_SAMPLES:
        var oldest_pos := _position_buffer[(_buffer_head_idx + 1) % POSITION_SAMPLES]
        var total_movement := (global_position - oldest_pos).length()
        # print("[MOVE] Total movement this sample: ", total_movement)
        if total_movement < STUCK_THRESHOLD:
            print("[MOVE] Stuck detected! Movement: ", total_movement)
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