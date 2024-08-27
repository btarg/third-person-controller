extends State
class_name ExplorationState

@onready var player := get_tree().get_nodes_in_group("Player").front() as PlayerController

# Runs when the state is entered
func enter() -> void:
    print("Exploration entered")
    player.enabled = true

# Runs when the state is exited
func exit() -> void:
    player.enabled = false

func update(_delta) -> void:
    pass

func physics_update(delta) -> void:
    player.player_process(delta)

func input_update(event) -> void:
    if event is InputEventKey and active:
        if event.is_pressed() and not event.is_echo() and event.keycode == KEY_R:
            Transitioned.emit(self, "BattleState")

func unhandled_input_update(event) -> void:
    player.unhandled_input_update(event)