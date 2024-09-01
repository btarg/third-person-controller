extends State
class_name PlayerThinkState

# TODO: find a better way to get the BattleCharacter
@onready var player := get_tree().get_nodes_in_group("Player").front() as PlayerController
@onready var battle_character := player.get_node("BattleCharacter") as BattleCharacter

func _ready() -> void:
	battle_character.TurnEnded.connect(_stop_thinking)

func enter() -> void:
	print("PLAYER is thinking about what to do")

func _stop_thinking(character: BattleCharacter) -> void:
	if battle_character != character or not active:
		return
	Transitioned.emit(self, "IdleState")

func exit() -> void:
	print(battle_character.character_name + " has stopped thinking")

func update(delta: float) -> void: pass

func physics_update(delta: float) -> void: pass

func input_update(event: InputEvent) -> void: pass

func unhandled_input_update(event: InputEvent) -> void:
	if active and not event.is_echo() and event.is_action_pressed("ui_select"):
		print("Player attacks!")
		battle_character.battle_state.ready_next_turn()
