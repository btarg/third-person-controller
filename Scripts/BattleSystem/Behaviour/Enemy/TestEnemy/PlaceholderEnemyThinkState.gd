extends State
class_name PlaceholderEnemyThinkState

@onready var battle_character := get_owner().get_node("BattleCharacter") as BattleCharacter

func wait(seconds: float) -> void:
    await get_tree().create_timer(seconds).timeout

func _ready() -> void:
    battle_character.OnLeaveBattle.connect(_on_leave_battle)

func _on_leave_battle() -> void:
    if active:
        _stop_thinking()

func enter() -> void:
    print(battle_character.character_name + " has %s HP" % battle_character.current_hp)
    print(battle_character.character_name + " is thinking about what to do")

    if battle_character.can_use_spells:
        print(battle_character.character_name + " can use spells")
    else:
        print(battle_character.character_name + " cannot use spells")

    _process_actions()

func _stop_thinking() -> void:
    Transitioned.emit(self, "IdleState")

func _process_actions() -> void:
    # Process one action at a time to avoid state machine lockup
    if battle_character.actions_left > 0:
        await wait(1)
        battle_character.spend_actions(1)
        # Don't recursively call _process_actions here - the spend_actions will trigger ready_next_turn
        # which will either give us another turn or move to the next character

func exit() -> void:
    print(battle_character.character_name + " has stopped thinking")
    
func _state_process(_delta: float) -> void: pass
func _state_physics_process(_delta: float) -> void: pass
func _state_input(_event: InputEvent) -> void: pass
func _state_unhandled_input(_event: InputEvent) -> void: pass
