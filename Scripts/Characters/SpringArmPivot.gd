extends Node3D
class_name SpringArmCameraPivot

@export_group("Rotation")
@export var max_sensitivity : float = 0.15
@export var min_sensitivity : float = 0.075
var current_sensitivity : float = min_sensitivity
## Camera speed multiplier curve for when the stick is pushed fully in any direction.
@export var camera_speed_curve : Curve
## How far the camera can rotate up and down in degrees
@export var spring_arm_clamp_degrees: float = 75.0
var spring_arm_clamp := deg_to_rad(spring_arm_clamp_degrees)


@export_group("Acceleration")
@export var rotation_acceleration: float = 0.75
@export var rotation_deceleration: float = 0.2
## How fast we lerp through the curve
@export var curve_acceleration_rate : float = 0.015


@export_group("FOV")
@export var change_fov_on_run : bool = true
@export var normal_fov : float = 75.0
@export var run_fov : float = 90.0

@export_group("Debug")
@export var debug_messages : bool = false

const CAMERA_BLEND : float = 0.1

@onready var spring_arm : SpringArm3D = $SpringArm3D
@onready var camera : Camera3D = $SpringArm3D/FreelookCamera
@onready var player := owner as CharacterBody3D

@export var enabled : bool:
    get:
        return enabled
    set(value):
        enabled = value
        if enabled and camera != null:
            _setup_camera()
            Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _ready() -> void:
    Console.add_command("toggle_mouse", _show_mouse, 0)
    _setup_camera()

func _show_mouse() -> void:
    if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
        Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
    else:
        Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _setup_camera() -> void:
    if enabled:
        camera.make_current()

func input_update(event) -> void:
    if enabled:
        if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
            rotate_y(-event.relative.x * 0.005)
            spring_arm.rotate_x(-event.relative.y * 0.005)
            spring_arm.rotation.x = clamp(spring_arm.rotation.x, -spring_arm_clamp, spring_arm_clamp)


func camera_physics_process(_delta) -> void:
    if not enabled or not Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
        return

    if change_fov_on_run:
        if player.is_on_floor() and player.velocity.length() > 0:
            if player.is_running:
                camera.fov = lerp(camera.fov, run_fov, CAMERA_BLEND)
            else:
                camera.fov = lerp(camera.fov, normal_fov, CAMERA_BLEND)
        else:
            camera.fov = lerp(camera.fov, normal_fov, CAMERA_BLEND)

    _handle_controller_input()


# These variables are not inside _handle_controller_input because
# they would be reset every frame
var rotation_velocity_y: float = 0.0
var rotation_velocity_x: float = 0.0
# Current value for sampling the curve
var curve_lerp_value : float = 0.0

func _handle_controller_input() -> void:
    var right_stick := Vector2(
        (Input.get_action_strength("look_left") - Input.get_action_strength("look_right")),
        (Input.get_action_strength("look_up") - Input.get_action_strength("look_down"))
    )
    # If the stick is fully pushed in any direction, accelerate the curve lerp value
    if (abs(right_stick.x) + abs(right_stick.y)) >= 1:
        curve_lerp_value = lerp(curve_lerp_value, 1.0, curve_acceleration_rate)
    else:
        curve_lerp_value = 0.0

    # Sample the curve using the current lerp value
    var curve_value := camera_speed_curve.sample(curve_lerp_value)

    if debug_messages:
        print("X axis:" + str(right_stick.x))
        print("Y axis:" + str(right_stick.y))
        
        if curve_lerp_value > 0:
            print("Curve Lerp Value: " + str(curve_lerp_value))
            print("Curve Sample: " + str(curve_value))
    
    current_sensitivity = min_sensitivity + (max_sensitivity - min_sensitivity) * curve_value

    # Multiply by current sensitivity
    right_stick *= current_sensitivity

    # Accelerate or decelerate towards the new right stick value
    rotation_velocity_x = lerp(rotation_velocity_x, right_stick.y, rotation_acceleration if right_stick.y != 0 else rotation_deceleration)
    rotation_velocity_y = lerp(rotation_velocity_y, right_stick.x, rotation_acceleration if right_stick.x != 0 else rotation_deceleration)

    # Clamp the rotation velocities - otherwise the camera will spin out of control
    rotation_velocity_x = clamp(rotation_velocity_x, -current_sensitivity, current_sensitivity)
    rotation_velocity_y = clamp(rotation_velocity_y, -current_sensitivity, current_sensitivity)

    if debug_messages:
            print("Rotation Velocity Y: " + str(rotation_velocity_y))
            print("Rotation Velocity X: " + str(rotation_velocity_x))

    # Apply the rotation velocity to the camera
    if rotation_velocity_y != 0 or rotation_velocity_x != 0:
        rotate_y(rotation_velocity_y)
        spring_arm.rotate_x(rotation_velocity_x)
        spring_arm.rotation.x = clamp(spring_arm.rotation.x, -spring_arm_clamp, spring_arm_clamp)
