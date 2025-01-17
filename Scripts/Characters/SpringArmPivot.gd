extends Node3D
class_name SpringArmCameraPivot

enum CameraMode {
    TOP_DOWN,
    THIRD_PERSON,
}

@export var camera_mode: CameraMode = CameraMode.THIRD_PERSON

@export_group("Rotation")
const LERP_VALUE: float = 0.15

@export var max_sensitivity: float = 0.15
@export var min_sensitivity: float = 0.075
var current_sensitivity: float = min_sensitivity

# Speed multiplier curve for right-stick input
@export var camera_speed_curve: Curve

@export_group("Zoom")
# Curve for top-down camera zoom angles
@export var angle_zoom_curve: Curve
# Use this value to smoothly sample the angle_zoom_curve (range: 0..1)
var angle_lerp_value: float = 0.5
## Determines how quickly we sample through the angle_zoom_curve
@export var angle_lerp_value_offset := 0.03
@export var zoom_speed: float = 0.25
@export var scroll_angle_speed: float = 0.1

@export_group("Spring arm")
@export var spring_arm_clamp_degrees: float = 75.0
var spring_arm_clamp := deg_to_rad(spring_arm_clamp_degrees)

@export_group("Top-down camera")
@export var top_down_min_angle_degrees: float = 10.0
@export var top_down_max_angle_degrees: float = 75.0
var min_angle_r := deg_to_rad(top_down_min_angle_degrees)  # near horizontal is -min_angle_r
var max_angle_r := deg_to_rad(top_down_max_angle_degrees)  # very top-down is -max_angle_r

@export_group("Acceleration")
@export var rotation_acceleration: float = 0.75
@export var rotation_deceleration: float = 0.2
@export var horizontal_speed_curve_acceleration_rate: float = 0.015
@export var top_down_horizontal_speed_modifier: float = 0.05

@export_group("FOV")
@export var change_fov_on_run: bool = true
@export var normal_fov: float = 75.0
@export var run_fov: float = 90.0

const CAMERA_BLEND: float = 0.1

@onready var spring_arm: SpringArm3D = $SpringArm3D
@onready var camera: Camera3D = $SpringArm3D.get_child(0) as Camera3D
@onready var player := owner as CharacterBody3D

@export var enabled: bool = true:
    get:
        return enabled
    set(value):
        enabled = value
        if enabled and camera != null:
            _setup_camera()

@export_group("Freelook camera control")
@onready var target_spring_length := spring_arm.spring_length
var min_spring_arm_length: float = 1.0
var max_spring_arm_length: float = 12.0
var spring_arm_scroll_speed: float = 1.0

func _ready() -> void:
    if camera_mode == CameraMode.THIRD_PERSON and enabled:
        _setup_camera()
    
func _setup_camera() -> void:
    camera.make_current()
    rotation_velocity_x = 0.0
    rotation_velocity_y = 0.0
    curve_lerp_value_tp = 0.0
    curve_lerp_value_top_down = 0.0
    spring_arm.rotation.x = clamp(spring_arm.rotation.x, -spring_arm_clamp, spring_arm_clamp)

func _controller_helper_use_mouse() -> void:
    if ControllerHelper.is_using_controller:
        ControllerHelper.is_using_controller = false
        Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func pivot_input_update(event: InputEvent) -> void:
    if not enabled:
        return

    if camera_mode == CameraMode.THIRD_PERSON:
        Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
    else:
        if not ControllerHelper.is_using_controller:
            Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
        else:
            Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

    if event is InputEventMouseMotion and Input.mouse_mode != Input.MOUSE_MODE_VISIBLE:
        _controller_helper_use_mouse()

    if camera_mode == CameraMode.THIRD_PERSON:
        if event is InputEventMouseMotion:
            rotate_y(-event.relative.x * 0.005)
            spring_arm.rotate_x(-event.relative.y * 0.005)
            spring_arm.rotation.x = clamp(spring_arm.rotation.x, -spring_arm_clamp, spring_arm_clamp)
    else:
        if event is InputEventMouseMotion and Input.is_action_pressed("right_click"):
            rotate_y(-event.relative.x * 0.005)
            spring_arm.rotate_x(-event.relative.y * 0.005)
            spring_arm.rotation.x = clamp(spring_arm.rotation.x, -spring_arm_clamp, spring_arm_clamp)
        elif event is InputEventMouseButton and event.is_pressed():
            if event.button_index == MOUSE_BUTTON_WHEEL_UP:
                target_spring_length = clamp(
                    spring_arm.spring_length - spring_arm_scroll_speed,
                    min_spring_arm_length,
                    max_spring_arm_length
                )
            elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
                target_spring_length = clamp(
                    spring_arm.spring_length + spring_arm_scroll_speed,
                    min_spring_arm_length,
                    max_spring_arm_length
                )

func camera_physics_process(_delta) -> void:
    if not enabled:
        return

    if change_fov_on_run and camera_mode == CameraMode.THIRD_PERSON:
        if player.is_on_floor() and player.velocity.length() > 0:
            camera.fov = lerp(camera.fov, run_fov if player.is_running else normal_fov, CAMERA_BLEND)
        else:
            camera.fov = lerp(camera.fov, normal_fov, CAMERA_BLEND)

    # Smoothly lerp spring_arm length
    spring_arm.spring_length = lerp(spring_arm.spring_length, target_spring_length, LERP_VALUE)

    if ControllerHelper.is_using_controller:
        _handle_controller_input()


var rotation_velocity_y: float = 0.0
var rotation_velocity_x: float = 0.0
var curve_lerp_value_top_down: float = 0.0
var curve_lerp_value_tp: float = 0.0

func _handle_controller_input() -> void:
    var right_stick := Vector2(
        Input.get_action_strength("look_left") - Input.get_action_strength("look_right"),
        Input.get_action_strength("look_up") - Input.get_action_strength("look_down")
    )
    
    if camera_mode == CameraMode.TOP_DOWN:
        # ---------------------------------------------------------
        # Baldur's Gate 3–style top-down camera
        # ---------------------------------------------------------
        if (abs(right_stick.x) + abs(right_stick.y)) >= 1:
            curve_lerp_value_top_down = lerp(curve_lerp_value_top_down, 1.0, horizontal_speed_curve_acceleration_rate * top_down_horizontal_speed_modifier)
        else:
            curve_lerp_value_top_down = 0.0

        var curve_value := camera_speed_curve.sample(curve_lerp_value_top_down)
        current_sensitivity = min_sensitivity + (max_sensitivity - min_sensitivity) * curve_value

        # Increase or decrease the angle_lerp_value based on Y
        if right_stick.y > 0.1:  # Zoom in
            target_spring_length = clamp(
                target_spring_length - zoom_speed,
                min_spring_arm_length,
                max_spring_arm_length
            )
            angle_lerp_value = clamp(angle_lerp_value - angle_lerp_value_offset, 0.0, 1.0)
        elif right_stick.y < -0.1:  # Zoom out
            target_spring_length = clamp(
                target_spring_length + zoom_speed,
                min_spring_arm_length,
                max_spring_arm_length
            )
            angle_lerp_value = clamp(angle_lerp_value + angle_lerp_value_offset, 0.0, 1.0)

        # Sample our angle_zoom_curve (range: 0..1)
        var normalized_sample := angle_zoom_curve.sample(angle_lerp_value)
        # Convert the curve’s [0..1] range to angles [-max_angle_r..-min_angle_r]
        var final_angle : float = lerp(-max_angle_r, -min_angle_r, normalized_sample)
        spring_arm.rotation.x = final_angle

        # Horizontal rotation
        right_stick.x *= current_sensitivity

    else:
        # ---------------------------------------------------------
        # Persona-style third-person "exploration" camera
        # ---------------------------------------------------------
        if (abs(right_stick.x) + abs(right_stick.y)) >= 1:
            curve_lerp_value_tp = lerp(curve_lerp_value_tp, 1.0, horizontal_speed_curve_acceleration_rate)
        else:
            curve_lerp_value_tp = 0.0

        var curve_value_tp := camera_speed_curve.sample(curve_lerp_value_tp)
        current_sensitivity = min_sensitivity + (max_sensitivity - min_sensitivity) * curve_value_tp
        right_stick *= current_sensitivity

    rotation_velocity_x = lerp(
        rotation_velocity_x,
        right_stick.y,
        rotation_acceleration if abs(right_stick.y) > 0.01 else rotation_deceleration
    )
    rotation_velocity_y = lerp(
        rotation_velocity_y,
        right_stick.x,
        rotation_acceleration if abs(right_stick.x) > 0.01 else rotation_deceleration
    )

    rotation_velocity_x = clamp(rotation_velocity_x, -current_sensitivity, current_sensitivity)
    rotation_velocity_y = clamp(rotation_velocity_y, -current_sensitivity, current_sensitivity)

    # Apply to both camera modes
    if abs(rotation_velocity_y) > 0.001 or abs(rotation_velocity_x) > 0.001:
        rotate_y(rotation_velocity_y)
        # For TOP_DOWN mode, X rotation is also coming from angle_zoom_curve, 
        # but the minimal stick input can still nudge the angle slightly:
        if camera_mode == CameraMode.THIRD_PERSON:
            spring_arm.rotate_x(rotation_velocity_x)
            spring_arm.rotation.x = clamp(spring_arm.rotation.x, -spring_arm_clamp, spring_arm_clamp)