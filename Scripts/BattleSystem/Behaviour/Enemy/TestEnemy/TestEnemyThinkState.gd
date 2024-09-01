extends State
class_name TestEnemyThinkState

# TODO: find a better way to get the BattleCharacter
@onready var battle_character := get_parent().get_parent() as BattleCharacter

func _ready() -> void:
    battle_character.TurnEnded.connect(_stop_thinking)

func enter() -> void:
    print(battle_character.character_name + " is thinking about what to do")

func _stop_thinking(character: BattleCharacter) -> void:
    if battle_character == character and active:
        Transitioned.emit(self, "IdleState")
    else:
        print("Character is not active")

func exit() -> void:
    print(battle_character.character_name + " has stopped thinking")

func update(delta: float) -> void: pass

func physics_update(delta: float) -> void: pass

func input_update(event: InputEvent) -> void: pass


func unhandled_input_update(event: InputEvent) -> void:
    if active and event.is_action_pressed("ui_select"):
        print(battle_character.character_name + " attacks!")
        battle_character.battle_state.ready_next_turn()