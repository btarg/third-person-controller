extends State
class_name ExplorationState

@onready var player := get_tree().get_nodes_in_group("Player").duplicate().pop_front() as PlayerController

# Runs when the state is entered
func enter() -> void:
    print("Exploration entered")
    player.exploration_control_enabled = true

# Runs when the state is exited
func exit() -> void:
    player.exploration_control_enabled = false
    player.free_movement = false

func _state_process(_delta) -> void:
    pass

func _state_physics_process(delta: float) -> void:
    player.player_process(delta)

func _state_input(event: InputEvent) -> void:
    if event.is_action_pressed("debug_enter_battle"):
        Transitioned.emit(self, "BattleState")

    elif event is InputEventKey\
    and event.is_pressed()\
    and event.keycode == KEY_ESCAPE:
        get_tree().quit()
        
    player.input_update(event)
