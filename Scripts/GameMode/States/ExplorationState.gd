extends State
class_name ExplorationState

@onready var player := get_tree().get_nodes_in_group("Player")[0] as PlayerController
@onready var spring_arm_pivot := player.get_node("SpringArmPivot")

func hello(message: String) -> void:
    print(message)

# Runs when the state is entered
func enter() -> void:
    print("Exploration entered")
    player.enabled = true

# Runs when the state is exited
func exit() -> void:
    player.enabled = false

# Updates every _process() update (When state is active)
func update(_delta) -> void:
    pass

# Updates every _physics_process() update (When state is active)
func physics_update(delta) -> void:
    spring_arm_pivot.camera_physics_process(delta)

func input_update(event) -> void:
    if event is InputEventKey and active:
        if event.is_pressed() and not event.is_echo() and event.keycode == KEY_R:
            Transitioned.emit(self, "BattleState")

func unhandled_input_update(event) -> void:
    spring_arm_pivot.unhandled_input_update(event)