extends Node3D
class_name SpringArmCameraPivot

enum CameraMode {
    TOP_DOWN,
    THIRD_PERSON,
}
## Third person camera mode is used for exploration, Top-down is the BG3 style camera
@export var camera_mode: CameraMode = CameraMode.THIRD_PERSON

@export_group("Rotation")
const LERP_VALUE: float = 0.15

@export var max_sensitivity : float = 0.15
@export var min_sensitivity : float = 0.075
var current_sensitivity : float = min_sensitivity
## Camera speed multiplier curve for when the stick is pushed fully in any direction.
@export var camera_speed_curve : Curve
## How far the camera can rotate up and down in degrees
@export var spring_arm_clamp_degrees: float = 75.0
var spring_arm_clamp := deg_to_rad(spring_arm_clamp_degrees)


@export_group("Top-down camera")
@export var top_down_min_angle_degrees : float = 10.0
@export var top_down_max_angle_degrees : float = 75.0
## How fast the top-down camera can zoom when using the zoom input (right stick on controller)
@export var zoom_speed : float = 0.25
## How fast the angle changes when zooming in/out (typically higher = flatter)
@export var angle_speed : float = 0.015


@export_group("Acceleration")
@export var rotation_acceleration: float = 0.75
@export var rotation_deceleration: float = 0.2
## How fast we lerp through the curve
@export var curve_acceleration_rate : float = 0.015
## Modifier for how fast we lerp through the curve when moving horizontally (top down camera only)
@export var top_down_horizontal_speed_modifier : float = 0.05

@export_group("FOV")
@export var change_fov_on_run : bool = true
@export var normal_fov : float = 75.0
@export var run_fov : float = 90.0

const CAMERA_BLEND : float = 0.1

@onready var spring_arm : SpringArm3D = $SpringArm3D
# The camera is the first child of the spring arm
@onready var camera : Camera3D = $SpringArm3D.get_child(0) as Camera3D

# If we are the third person character, then our owner is the exploration player
@onready var player := owner as CharacterBody3D

@export var enabled : bool:
    get:
        return enabled
    set(value):
        enabled = value
        if enabled and camera != null:
            _setup_camera()

            if camera_mode == CameraMode.THIRD_PERSON:
                Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
            else:
                Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

@export_group("Freelook camera control")
## Spring arm length used for zooming in and out
@onready var target_spring_length := spring_arm.spring_length
var min_spring_arm_length: float = 1.0
var max_spring_arm_length: float = 12.0
var spring_arm_scroll_speed: float = 1.0

func _ready() -> void:
    if camera_mode == CameraMode.THIRD_PERSON:
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

func pivot_input_update(event: InputEvent) -> void:
    if enabled:
        if camera_mode == CameraMode.THIRD_PERSON:
            if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
                var mouse_input_target_yaw : float = -event.relative.x * 0.005
                rotate_y(mouse_input_target_yaw)
                spring_arm.rotate_x(-event.relative.y * 0.005)
                spring_arm.rotation.x = clamp(spring_arm.rotation.x, -spring_arm_clamp, spring_arm_clamp)

        else:
            if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
                rotate_y(-event.relative.x * 0.005)
                spring_arm.rotate_x(-event.relative.y * 0.005)
                spring_arm.rotation.x = clamp(spring_arm.rotation.x, -spring_arm_clamp, spring_arm_clamp)
            elif event is InputEventMouseButton and event.is_pressed():
                # Angle boundaries, same as in _handle_controller_input
                var min_angle_r = deg_to_rad(top_down_min_angle_degrees)
                var max_angle_r = deg_to_rad(top_down_max_angle_degrees)

                if event.button_index == MOUSE_BUTTON_WHEEL_UP:
                    # Zoom in
                    target_spring_length = clamp(
                        spring_arm.spring_length - spring_arm_scroll_speed,
                        min_spring_arm_length,
                        max_spring_arm_length
                    )
                    # Flatten angle toward -min_angle_r
                    var new_angle := spring_arm.rotation.x + angle_speed
                    new_angle = clamp(new_angle, -max_angle_r, -min_angle_r)
                    
                    var angle_tween := get_tree().create_tween()
                    angle_tween.tween_property(spring_arm, "rotation:x", spring_arm.rotation.x, new_angle)
                    # spring_arm.rotation.x = new_angle

                elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
                    # Zoom out
                    target_spring_length = clamp(
                        spring_arm.spring_length + spring_arm_scroll_speed,
                        min_spring_arm_length,
                        max_spring_arm_length
                    )
                    # Look more down toward -max_angle_r
                    var new_angle := spring_arm.rotation.x - angle_speed
                    new_angle = clamp(new_angle, -max_angle_r, -min_angle_r)

                    var angle_tween := get_tree().create_tween()
                    angle_tween.tween_property(spring_arm, "rotation:x", spring_arm.rotation.x, new_angle)

                    # spring_arm.rotation.x = new_angle

func camera_physics_process(_delta) -> void:
    if not enabled:
        return

    if change_fov_on_run and camera_mode == CameraMode.THIRD_PERSON:
        if player.is_on_floor() and player.velocity.length() > 0:
            if player.is_running:
                camera.fov = lerp(camera.fov, run_fov, CAMERA_BLEND)
            else:
                camera.fov = lerp(camera.fov, normal_fov, CAMERA_BLEND)
        else:
            camera.fov = lerp(camera.fov, normal_fov, CAMERA_BLEND)

    # Lerp the spring length
    spring_arm.spring_length = lerp(spring_arm.spring_length, target_spring_length, LERP_VALUE)

    _handle_controller_input()


# These variables are not declared inside _handle_controller_input because
# they would be reset every frame
var rotation_velocity_y: float = 0.0
var rotation_velocity_x: float = 0.0
# Current value for sampling the curve
var curve_lerp_value_top_down : float = 0.0
var curve_lerp_value_tp : float = 0.0

func _handle_controller_input() -> void:
    var right_stick := Vector2(
        Input.get_action_strength("look_left") - Input.get_action_strength("look_right"),
        Input.get_action_strength("look_up") - Input.get_action_strength("look_down")
    )
    
    if camera_mode == CameraMode.TOP_DOWN:
        # ---------------------------------------------------------
        # Baldur's Gate 3–style top-down camera
        # Up on stick => zoom in + flatten angle
        # Down on stick => zoom out + look down more
        # ---------------------------------------------------------

        # Use the speed curve for horizontal rotation:
        # The exploration camera's curve accelerates way too fast for the top-down camera,
        # so I'm being lazy and just multiplying the curve sample value by a small number rather
        # than making a separate curve for it. - 14/01/2025
        if (abs(right_stick.x) + abs(right_stick.y)) >= 1:
            curve_lerp_value_top_down = lerp(curve_lerp_value_top_down, 1.0, curve_acceleration_rate * top_down_horizontal_speed_modifier)
        else:
            curve_lerp_value_top_down = 0.0

        var curve_value := camera_speed_curve.sample(curve_lerp_value_top_down)

        current_sensitivity = min_sensitivity + (max_sensitivity - min_sensitivity) * curve_value

        # Treat Y > 0 as zooming in (flatten angle) and Y < 0 as zooming out (more top-down)
        var min_angle_r := deg_to_rad(top_down_min_angle_degrees)  # near horizontal is -min_angle_r
        var max_angle_r := deg_to_rad(top_down_max_angle_degrees)  # very top-down is -max_angle_r

        if right_stick.y > 0.1:
            # Zoom in
            target_spring_length = clamp(
                target_spring_length - zoom_speed,
                min_spring_arm_length,
                max_spring_arm_length
            )
            # Flatten angle toward -min_angle_r
            var new_angle := spring_arm.rotation.x + angle_speed
            new_angle = clamp(new_angle, -max_angle_r, -min_angle_r)
            spring_arm.rotation.x = new_angle
        elif right_stick.y < -0.1:
            # Zoom out
            target_spring_length = clamp(
                target_spring_length + zoom_speed,
                min_spring_arm_length,
                max_spring_arm_length
            )
            # Look down more toward -max_angle_r
            var new_angle := spring_arm.rotation.x - angle_speed
            new_angle = clamp(new_angle, -max_angle_r, -min_angle_r)
            spring_arm.rotation.x = new_angle

        # Horizontal rotation (X axis of stick)
        right_stick.x *= current_sensitivity
        rotation_velocity_y = lerp(
            rotation_velocity_y,
            right_stick.x,
            rotation_acceleration if abs(right_stick.x) > 0.01 else rotation_deceleration
        )
        rotation_velocity_y = clamp(rotation_velocity_y, -current_sensitivity, current_sensitivity)

    else:
        # ---------------------------------------------------------
        # Persona-style third-person "exploration" camera
        # ---------------------------------------------------------

        if (abs(right_stick.x) + abs(right_stick.y)) >= 1:
            curve_lerp_value_tp = lerp(curve_lerp_value_tp, 1.0, curve_acceleration_rate)
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

    # APPLY TO BOTH CAMERA MODES
    if abs(rotation_velocity_y) > 0.001 or abs(rotation_velocity_x) > 0.001:
        rotate_y(rotation_velocity_y)
        spring_arm.rotate_x(rotation_velocity_x)
        spring_arm.rotation.x = clamp(spring_arm.rotation.x, -spring_arm_clamp, spring_arm_clamp)

    # on the spring arm, rotation X is up/down and rotation Y is left/right
    # print(Vector2(spring_arm.rotation.x, spring_arm.rotation.y))