extends State
class_name TestEnemyThinkState

# TODO: find a better way to get the BattleCharacter
@onready var battle_character := get_parent().get_parent() as BattleCharacter

func wait(seconds: float) -> void:
    await get_tree().create_timer(seconds).timeout

func _ready() -> void:
    battle_character.OnLeaveBattle.connect(_on_leave_battle)

func _on_leave_battle() -> void:
    if active:
        _stop_thinking()

func enter() -> void:
    print(battle_character.character_name + " is thinking about what to do")
    await wait(0.75)

    _stop_thinking()
    battle_character.battle_state.ready_next_turn()

func _stop_thinking() -> void:
    Transitioned.emit(self, "IdleState")

func exit() -> void:
    print(battle_character.character_name + " has stopped thinking")
    
func update(_delta: float) -> void: pass
func physics_update(_delta: float) -> void: pass
func input_update(_event: InputEvent) -> void: pass
func unhandled_input_update(_event: InputEvent) -> void: pass
