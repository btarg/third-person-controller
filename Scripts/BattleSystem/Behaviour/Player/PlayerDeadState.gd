extends State
class_name PlayerDeadState

@onready var battle_character := state_machine.get_parent() as BattleCharacter

func _ready() -> void:
    battle_character.OnLeaveBattle.connect(_on_leave_battle)
    BattleSignalBus.OnHeal.connect(_on_heal)
    
func _on_leave_battle() -> void:
    if active:
        _stop_thinking()

func enter() -> void:
    print(battle_character.character_name + " is dead and cannot take a turn!")

    _stop_thinking()
    battle_character.actions_left = 0
    battle_character.battle_state.ready_next_turn()

func _stop_thinking() -> void:
    Transitioned.emit(self, "IdleState")

# Dead characters cannot normally be selected by regular spells,
# but those with only_on_dead_characters set to true can target them.
func _on_heal(_healed_character: BattleCharacter) -> void:
    if _healed_character == battle_character:
        print("[REVIVE] " + battle_character.character_name + " has been revived and can re-enter the battle!")
        Transitioned.emit(self, "IdleState")

func exit() -> void: pass
func _state_process(_delta: float) -> void: pass
func _state_physics_process(_delta: float) -> void: pass
func _state_input(_event: InputEvent) -> void: pass
func _state_unhandled_input(_event: InputEvent) -> void: pass
