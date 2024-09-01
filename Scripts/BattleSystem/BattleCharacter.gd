extends Node
class_name BattleCharacter

enum CharacterType {
	PLAYER,
	FRIENDLY,
	NEUTRAL,
	ENEMY
}

@export var character_type : CharacterType = CharacterType.PLAYER

@export var default_character_name: String = "Test Enemy"
@onready var character_name : String = default_character_name:
	get:
		return character_name
	set(value):
		character_name = value
		get_parent().name = character_name


@export var max_hp: int = 100
@export var current_hp: int = 100
@export var vitality : int = 10

@onready var battle_state := get_node("/root/GameModeStateMachine/BattleState") as BattleState
@onready var exploration_state := get_node("/root/GameModeStateMachine/ExplorationState") as ExplorationState

@onready var behaviour_state_machine := $StateMachine as StateMachine
@onready var enemy_idle_state := behaviour_state_machine.get_node("IdleState") as EnemyIdleState


var initiative: int = 0

@export var active := false

func on_joined_battle() -> void:
	battle_state.TurnStarted.connect(_on_turn_started)

func on_leave_battle() -> void:
	battle_state.TurnStarted.disconnect(_on_turn_started)
	character_name = default_character_name

func _on_turn_started(character: BattleCharacter) -> void:
	if character == self:
		start_turn()
	elif active:
		# end turn if we were the last active character
		end_turn()

func start_turn() -> void:
	print(character_name + " is starting their turn")
	active = true

	if character_type == CharacterType.ENEMY:
		enemy_idle_state.go_to_think_state()
	else:
		print("Not thinking")

func end_turn() -> void:
	print(character_name + " has ended their turn")
	active = false

func take_turn() -> void:
	print(character_name + " Attacks!")
	battle_state.ready_next_turn()

func roll_initiative() -> int:
	initiative = DiceRoller.roll_flat(20, 1)
	return initiative

func battle_input(event) -> void:
	if not active:
		return

	if event.is_action_pressed("ui_select"):
		take_turn()
	elif event.is_action_pressed("ui_cancel"):
		battle_state.leave_battle(self)
