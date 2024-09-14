extends CharacterBody3D
class_name TopDownPlayerController

@onready var player := get_tree().get_nodes_in_group("Player")[0] as PlayerController
@onready var spring_arm_pivot := $TopDownPlayerPivot as Node3D
@onready var spring_arm := spring_arm_pivot.get_node("SpringArm3D") as SpringArm3D
@onready var camera := spring_arm.get_node("TopDownCamera") as Camera3D

@export_group("Rotation")
## How far the camera can rotate up and down in degrees
@export var spring_arm_clamp_degrees: float = 90
var spring_arm_clamp := deg_to_rad(spring_arm_clamp_degrees)
const LERP_VALUE: float = 0.15

@export_group("Player control")
var speed: float = 7.0
var acceleration: float = 0.1
var deceleration: float = 0.2
var y_focus_acceleration: float = 0.01
var xz_focus_acceleration: float = 0.05

@onready var focused_node: Node3D = player:
    get:
        return focused_node
    set(value):
        focused_node = value
        moved_from_focus = false


@onready var target_spring_length := spring_arm.spring_length

# player has moved away from focused node
var moved_from_focus: bool = false

@export var enabled: bool:
    get:
        return enabled
    set(value):
        enabled = value
        if enabled and camera != null:
            camera.make_current()

@export_group("Camera control")
var min_spring_arm_length: float = 1.0
var max_spring_arm_length: float = 12.0
var spring_arm_scroll_speed: float = 1.0

func _ready() -> void:
    if enabled:
        camera.make_current()
        print("Hello from TopDownPlayerController")

func player_process(_delta) -> void:
    if not enabled:
        return

    var move_direction: Vector3 = Vector3.ZERO
    move_direction.x = Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
    move_direction.z = Input.get_action_strength("move_backwards") - Input.get_action_strength("move_forwards")

    # if we have moved set moved_from_focus
    if move_direction.length() > 0.0:
        moved_from_focus = true

    # moved_from_focus = true if we should track the focused node
    if not moved_from_focus:
        if focused_node and focused_node.is_inside_tree():
            # ignore Y axis since we calculate that later and regardless of focused node
            var target_position := focused_node.global_transform.origin
            var current_position := global_transform.origin
            
            # Lerp position to focused node
            global_transform.origin.x = lerp(current_position.x, target_position.x, xz_focus_acceleration)
            global_transform.origin.z = lerp(current_position.z, target_position.z, xz_focus_acceleration)
    else:
        # Get the camera's forward direction
        var camera_forward: Vector3 = camera.global_transform.basis.z.normalized()
        var camera_right: Vector3 = camera.global_transform.basis.x.normalized()

        # Calculate the movement direction based on the camera's forward and right vectors
        var final_direction: Vector3 = (camera_right * move_direction.x) + (camera_forward * move_direction.z)
        final_direction.y = 0 # Ensure the movement is only on the XZ plane

        # Calculate the target velocity
        var target_velocity: Vector3 = final_direction * speed

        # Lerp the velocity for smoother movement
        velocity.x = lerp(velocity.x, target_velocity.x, acceleration)
        velocity.z = lerp(velocity.z, target_velocity.z, acceleration)

    # Lerp the spring length
    spring_arm.spring_length = lerp(spring_arm.spring_length, target_spring_length, LERP_VALUE)
    
    # Keep the same Y level as the focused node
    if focused_node:
        var target_y := focused_node.global_transform.origin.y
        var current_y := global_transform.origin.y
        var new_y: float = lerp(current_y, target_y, y_focus_acceleration)
        global_transform.origin.y = new_y
    else:
        printerr("No focused node set!")

    move_and_slide()

func unhandled_input_update(event) -> void:
    if enabled:
        if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
            rotate_y(-event.relative.x * 0.005)
            spring_arm.rotate_x(-event.relative.y * 0.005)
            spring_arm.rotation.x = clamp(spring_arm.rotation.x, -spring_arm_clamp, spring_arm_clamp)
        elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_WHEEL_UP:
            target_spring_length = clamp(spring_arm.spring_length - spring_arm_scroll_speed, min_spring_arm_length, max_spring_arm_length)
        elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
            target_spring_length = clamp(spring_arm.spring_length + spring_arm_scroll_speed, min_spring_arm_length, max_spring_arm_length)
        elif event is InputEventKey and event.is_pressed() and event.keycode == KEY_F:
            # instantiate an empty node
            var new_focus := Node3D.new()
            focused_node = new_focus
        elif event is InputEventKey and event.is_pressed() and event.keycode == KEY_P:
            focused_node = player
