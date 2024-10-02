extends BattleCharacterController
class_name PlayerController

const LERP_VALUE : float = 0.15

var snap_vector : Vector3 = Vector3.DOWN
var speed : float

@onready var player_mesh : Node3D = $Mesh
@onready var spring_arm_pivot := $FreelookPivot as SpringArmCameraPivot

@export var exploration_control_enabled : bool:
    get:
        return exploration_control_enabled
    set(value):
        exploration_control_enabled = value
        if animator != null and not exploration_control_enabled:
            reset_to_idle()
        if spring_arm_pivot != null:
            spring_arm_pivot.enabled = exploration_control_enabled
            
func _ready() -> void:
    spring_arm_pivot.enabled = exploration_control_enabled
    super()

## Called from state
func input_update(event: InputEvent) -> void:
    spring_arm_pivot.input_update(event)

## Called from state
func player_process(delta: float) -> void:

    if not exploration_control_enabled or spring_arm_pivot == null:
        return

    spring_arm_pivot.camera_physics_process(delta)

    var move_direction := Vector3.ZERO
    move_direction.x = Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
    move_direction.z = Input.get_action_strength("move_backwards") - Input.get_action_strength("move_forwards")
    move_direction = move_direction.rotated(Vector3.UP, spring_arm_pivot.rotation.y)
    
    velocity.y -= gravity * delta
    
    speed = run_speed if Input.is_action_pressed("run") else walk_speed
    is_running = (speed == run_speed) and (abs(velocity.x) > 1 or abs(velocity.z) > 1)

    velocity.x = move_direction.x * speed
    velocity.z = move_direction.z * speed
    
    if move_direction:
        player_mesh.rotation.y = lerp_angle(player_mesh.rotation.y, atan2(velocity.x, velocity.z), LERP_VALUE)
    
    var just_landed := is_on_floor() and snap_vector == Vector3.ZERO
    var is_jumping := is_on_floor() and Input.is_action_just_pressed("jump")
    if is_jumping:
        velocity.y = jump_strength
        snap_vector = Vector3.ZERO
    elif just_landed:
        snap_vector = Vector3.DOWN
    apply_floor_snap()
    move_and_slide()
    
    animate(delta)