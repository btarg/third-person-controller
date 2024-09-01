extends State
class_name TestEnemyBattleStartThinkState

# TODO: find a better way to get the BattleCharacter
@onready var battle_character := get_parent().get_parent() as BattleCharacter

func enter() -> void:
    print(battle_character.character_name + " is thinking about what to do")

func exit() -> void: pass

func update(delta: float) -> void: pass

func physics_update(delta: float) -> void: pass

func input_update(event: InputEvent) -> void: pass

func unhandled_input_update(event: InputEvent) -> void: pass