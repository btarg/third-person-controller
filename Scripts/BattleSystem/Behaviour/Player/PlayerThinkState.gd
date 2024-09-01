extends State
class_name PlayerThinkState

# TODO: find a better way to get the BattleCharacter
@onready var player := get_tree().get_nodes_in_group("Player").front() as PlayerController
@onready var battle_character := player.get_node("BattleCharacter") as BattleCharacter

func _ready() -> void:
    battle_character.LeaveBattle.connect(_on_leave_battle)

func _on_leave_battle() -> void:
    if active:
        _stop_thinking()

func enter() -> void:
    print("PLAYER is thinking about what to do")

func _stop_thinking() -> void:
    Transitioned.emit(self, "IdleState")

func exit() -> void:
    print(battle_character.character_name + " has stopped thinking")

func update(delta: float) -> void: pass

func physics_update(delta: float) -> void:
    if active:
        print("Player is thinking")

func input_update(event: InputEvent) -> void:
    if event.is_action_pressed("ui_select") and not event.is_echo():
        print("Player attacks!")
        _stop_thinking()
        battle_character.battle_state.ready_next_turn()

func unhandled_input_update(event: InputEvent) -> void: pass