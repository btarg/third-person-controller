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
@export var evasion: int = 10

@onready var battle_state := get_node("/root/GameModeStateMachine/BattleState") as BattleState
@onready var exploration_state := get_node("/root/GameModeStateMachine/ExplorationState") as ExplorationState

@onready var behaviour_state_machine := self.get_node("StateMachine") as StateMachine
@onready var idle_state := behaviour_state_machine.get_node("IdleState") as IdleState

signal LeaveBattle

var active := false

var initiative: int = 0

func _ready() -> void:
	battle_state.TurnStarted.connect(_on_turn_started)
	
func on_leave_battle() -> void:
	character_name = default_character_name
	LeaveBattle.emit()

func _on_turn_started(character: BattleCharacter) -> void:
	if character == self:
		start_turn()
	elif not active:
		active = false

func start_turn() -> void:
	print("========")
	print(character_name + " is starting their turn")
	print("========")
	active = true

	idle_state.go_to_think_state()


func roll_initiative() -> int:
	initiative = DiceRoller.roll_flat(20, 1)
	return initiative

func battle_input(event) -> void:
	if not active:
		return
	if event.is_action_pressed("ui_cancel"):
		battle_state.leave_battle(self)
