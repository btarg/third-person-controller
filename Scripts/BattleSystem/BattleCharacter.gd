extends Node
class_name BattleCharacter

@export var character_type : BattleEnums.CharacterType = BattleEnums.CharacterType.PLAYER

@export var default_character_name: String = "Test Enemy"
@onready var character_name : String = default_character_name:
    get:
        return character_name
    set(value):
        character_name = value
        get_parent().name = character_name


@onready var battle_state := get_node("/root/GameModeStateMachine/BattleState") as BattleState
@onready var exploration_state := get_node("/root/GameModeStateMachine/ExplorationState") as ExplorationState
@onready var behaviour_state_machine := self.get_node("StateMachine") as StateMachine


@onready var stats := $CharacterStats as CharacterStats

@onready var current_hp: float = stats.get_stat(CharacterStatEntry.ECharacterStat.MaxHP)
@onready var vitality := stats.get_stat(CharacterStatEntry.ECharacterStat.Vitality)

signal OnLeaveBattle

var active := false
var initiative: int = 0

func _ready() -> void:
    battle_state.TurnStarted.connect(_on_turn_started)
    print(character_name + " CURRENT HP: " + str(current_hp))

func on_leave_battle() -> void:
    character_name = default_character_name
    OnLeaveBattle.emit()

func _on_turn_started(character: BattleCharacter) -> void:
    if character == self:
        start_turn()
    elif active:
        active = false

func start_turn() -> void:
    print("========")
    print(character_name + " is starting their turn")
    print("========")
    active = true

    behaviour_state_machine.set_state("ThinkState")


func roll_initiative() -> int:
    initiative = DiceRoller.roll_flat(20, 1) + int(vitality)
    return initiative

func battle_input(_event) -> void: pass