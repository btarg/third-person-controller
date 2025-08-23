extends BattleCharacterController
class_name PlayerController

@onready var spring_arm_pivot := $FreelookPivot as SpringArmCameraPivot

@export var exploration_control_enabled : bool:
    get:
        return exploration_control_enabled
    set(value):
        exploration_control_enabled = value
        print("[Player] Exploration state: " + str(exploration_control_enabled))
        if animator != null and not exploration_control_enabled:
            reset_to_idle()
        if spring_arm_pivot != null:
            spring_arm_pivot.enabled = exploration_control_enabled
        # Exploration control always gives us free movement
        if exploration_control_enabled:
            free_movement = true

            
func _ready() -> void:
    exploration_control_enabled = true
    spring_arm_pivot.enabled = true
    super()

## Called from state
func player_process(delta: float) -> void:
    # Update the spring arm pivot
    if exploration_control_enabled and spring_arm_pivot:
        spring_arm_pivot.camera_physics_process(delta)
    super(delta)

## Called from state
func input_update(event: InputEvent) -> void:
    if exploration_control_enabled and spring_arm_pivot:
        spring_arm_pivot.pivot_input_update(event)


