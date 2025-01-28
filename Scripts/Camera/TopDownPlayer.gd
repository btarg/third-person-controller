extends CharacterBody3D
class_name TopDownPlayerController

@onready var player := get_tree().get_first_node_in_group("Player") as PlayerController
@onready var spring_arm_pivot := get_child(0) as SpringArmCameraPivot
@onready var camera := spring_arm_pivot.camera

@export_group("Player control")
var speed: float = 7.0
var acceleration: float = 0.1
var deceleration: float = 0.2
var y_focus_acceleration: float = 0.01
var xz_focus_acceleration: float = 0.05

var allow_moving_focus: bool = true

var focused_node: Node3D = player:
    get:
        return focused_node
    set(value):
        focused_node = value
        moved_from_focus = false
        # zero velocity
        velocity = Vector3.ZERO

# player has moved away from focused node
var moved_from_focus: bool = false

var enabled: bool:
    get:
        return enabled
    set(value):
        enabled = value
        spring_arm_pivot.enabled = enabled

func teleport_to_focused_node() -> void:
    print("Teleporting to focused node " + focused_node.name)
    if focused_node:
        set_global_position(focused_node.global_position)
    else:
        printerr("No focused node set!")

func player_process(delta: float) -> void:
    if not enabled:
        return

    var move_direction := Vector3.ZERO
    move_direction.x = Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
    move_direction.z = Input.get_action_strength("move_backwards") - Input.get_action_strength("move_forwards")

    # print("[Top Down Camera] Move direction: ", move_direction)

    # if we have moved set moved_from_focus
    if move_direction.length() > 0.0 and allow_moving_focus:
        moved_from_focus = true

    # moved_from_focus = true if we should track the focused node
    if not moved_from_focus:
        if focused_node and focused_node.is_inside_tree():
            # print("Staying focused on node: ", focused_node)
            # ignore Y axis since we calculate that later and regardless of focused node
            var target_position := focused_node.global_transform.origin
            var current_position := global_transform.origin
            
            # Lerp position to focused node
            global_transform.origin.x = lerp(current_position.x, target_position.x, xz_focus_acceleration)
            global_transform.origin.z = lerp(current_position.z, target_position.z, xz_focus_acceleration)
    elif allow_moving_focus:
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
    
    # Keep the same Y level as the focused node
    if focused_node:
        var target_y := focused_node.global_transform.origin.y
        var current_y := global_transform.origin.y
        var new_y: float = lerp(current_y, target_y, y_focus_acceleration)
        global_transform.origin.y = new_y
    else:
        printerr("No focused node set!")

    move_and_slide()
    spring_arm_pivot.camera_physics_process(delta)


## Called from state
func input_update_from_battle_state(event: InputEvent) -> void:
    if enabled:
        if event is InputEventKey and event.is_pressed() and event.keycode == KEY_F:
            var new_focus := Node3D.new()
            focused_node = new_focus
        elif event is InputEventKey and event.is_pressed() and event.keycode == KEY_P:
            focused_node = player

        spring_arm_pivot.pivot_input_update(event)