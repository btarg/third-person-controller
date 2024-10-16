extends State
class_name EnemyDownedState

@onready var battle_character := state_machine.get_parent() as BattleCharacter

func _ready() -> void:
    battle_character.OnLeaveBattle.connect(_on_leave_battle)

func _on_leave_battle() -> void:
    if active:
        _stop_thinking()

func enter() -> void:
    print(battle_character.character_name + " is down!")
    battle_character.down_turns -= 1
    
    _stop_thinking()
    battle_character.battle_state.ready_next_turn()

func _stop_thinking() -> void:
    Transitioned.emit(self, "IdleState")

func exit() -> void: pass
func _state_process(_delta: float) -> void: pass
func _state_physics_process(_delta: float) -> void: pass
func _state_input(_event: InputEvent) -> void: pass
func _state_unhandled_input(_event: InputEvent) -> void: pass
