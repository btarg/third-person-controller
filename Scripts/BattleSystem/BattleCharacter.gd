extends Node
class_name BattleCharacter

enum CharacterType {
    PLAYER,
    FRIENDLY,
    NEUTRAL,
    ENEMY
}
@export var character_type : CharacterType = CharacterType.PLAYER
@export var character_name : String = "Test Enemy"
@export var max_hp: int = 100
@export var current_hp: int = 100
@export var vitality : int = 10

@onready var battle_state := get_node("/root/GameModeStateMachine/BattleState") as BattleState
@onready var exploration_state := get_node("/root/GameModeStateMachine/ExplorationState") as ExplorationState

var initiative: int = 0

@export var active := true

func roll_initiative() -> int:
    initiative = DiceRoller.roll_flat(20, 1)
    return initiative

func _ready() -> void:
    get_parent().name = character_name

    if character_type == CharacterType.FRIENDLY:
        print(self.get_parent().name + " is a friendly character")
    elif character_type == CharacterType.ENEMY:
        print(self.get_parent().name + " is an enemy character")
    elif character_type == CharacterType.PLAYER:
        print(self.get_parent().name + " is a player character")
    else:
        print(self.get_parent().name + " is a neutral character")
