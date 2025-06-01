extends CharacterBody3D
class_name TopDownPlayerController

@onready var player := get_tree().get_first_node_in_group("Player") as PlayerController
@onready var spring_arm_pivot := get_child(0) as SpringArmCameraPivot
@onready var camera := spring_arm_pivot.camera
@onready var collision_shape := get_node("CollisionShape3D") as CollisionShape3D

@export_group("Player control")
var speed: float = 7.0
var acceleration: float = 0.1
var deceleration: float = 0.2

@export_group("Focus control")
var allow_moving_focus: bool = true
var focused_position: Vector3
var is_focusing_position: bool = false
var y_focus_acceleration: float = 0.01
var xz_focus_acceleration: float = 0.05


var focused_node: Node3D = player:
    get:
        return focused_node
    set(value):
        focused_node = value
        is_focusing_position = false  # Clear position focus when setting node
        moved_from_focus = false
        # zero velocity
        velocity = Vector3.ZERO
        # Disable collisions when focusing
        collision_shape.disabled = true

# player has manually moved, which breaks focus
var moved_from_focus: bool = false

# Flag to indicate when camera has reached its focus target
var is_at_focus: bool = false

var enabled: bool:
    get:
        return enabled
    set(value):
        enabled = value
        spring_arm_pivot.enabled = enabled

func snap_to_focused_node() -> void:
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
        # Re-enable collisions when breaking focus
        collision_shape.disabled = false

    # moved_from_focus = true if we should track the focused node or position
    if not moved_from_focus:
        if is_focusing_position:
            # Focus on a specific position
            var current_position := global_transform.origin
            global_transform.origin.x = lerp(current_position.x, focused_position.x, xz_focus_acceleration)
            global_transform.origin.z = lerp(current_position.z, focused_position.z, xz_focus_acceleration)
            
            # Check if we've reached the focused position
            var distance_to_target := Vector2(global_position.x - focused_position.x, global_position.z - focused_position.z).length()
            is_at_focus = distance_to_target < 0.1
            
        elif focused_node and focused_node.is_inside_tree():
            # print("Staying focused on node: ", focused_node)
            # ignore Y axis since we calculate that later and regardless of focused node
            var target_position := focused_node.global_transform.origin
            var current_position := global_transform.origin
            
            # Lerp position to focused node
            global_transform.origin.x = lerp(current_position.x, target_position.x, xz_focus_acceleration)
            global_transform.origin.z = lerp(current_position.z, target_position.z, xz_focus_acceleration)
            
            # Check if we've reached the focused node
            var distance_to_target := Vector2(global_position.x - target_position.x, global_position.z - target_position.z).length()
            is_at_focus = distance_to_target < 0.1
    elif allow_moving_focus:
        # Get the camera's transform and project vectors onto horizontal plane
        var camera_transform := camera.global_transform
        var camera_forward := camera_transform.basis.z
        var camera_right := camera_transform.basis.x
        
        # Project forward and right vectors onto the XZ plane (remove Y component)
        camera_forward.y = 0
        camera_right.y = 0
        
        # Check if vectors are too small after projection (camera facing directly down)
        if camera_forward.length() < 0.1 or camera_right.length() < 0.1:
            # Fallback to world directions when camera is facing directly down
            camera_forward = Vector3(0, 0, 1)  # World forward
            camera_right = Vector3(1, 0, 0)   # World right
        else:
            # Normalize to ensure consistent speed in all directions
            camera_forward = camera_forward.normalized()
            camera_right = camera_right.normalized()
        
        # Calculate movement direction relative to camera
        var final_direction := (camera_right * move_direction.x) + (camera_forward * move_direction.z)
        final_direction.y = 0  # Ensure movement is only on XZ plane

        # Calculate the target velocity
        var target_velocity: Vector3 = final_direction * speed

        # Lerp the velocity for smoother movement
        velocity.x = lerp(velocity.x, target_velocity.x, acceleration)
        velocity.z = lerp(velocity.z, target_velocity.z, acceleration)
    
    # Keep the same Y level as the focused node or position
    if is_focusing_position:
        var target_y := focused_position.y
        var current_y := global_transform.origin.y
        var new_y: float = lerp(current_y, target_y, y_focus_acceleration)
        global_transform.origin.y = new_y
    elif focused_node:
        var target_y := focused_node.global_transform.origin.y
        var current_y := global_transform.origin.y
        var new_y: float = lerp(current_y, target_y, y_focus_acceleration)
        global_transform.origin.y = new_y
    else:
        printerr("No focused node or position set!")

    move_and_slide()
    
    
    spring_arm_pivot.camera_physics_process(delta)

func focus_position(target_position: Vector3) -> void:
    """Focus the camera on a specific Vector3 position instead of a node."""
    print("Focusing on position: " + str(target_position))
    focused_position = target_position
    is_focusing_position = true
    moved_from_focus = false
    # zero velocity
    velocity = Vector3.ZERO
    # Disable collisions when focusing on position
    collision_shape.disabled = true


## Called from state
func input_update_from_battle_state(event: InputEvent) -> void:
    if enabled:
        if event is InputEventKey and event.is_pressed() and event.keycode == KEY_P:
            focused_node = player

        spring_arm_pivot.pivot_input_update(event)