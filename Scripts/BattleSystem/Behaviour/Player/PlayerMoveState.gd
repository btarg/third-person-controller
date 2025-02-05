extends State
class_name PlayerMoveState

@onready var battle_character := state_machine.get_parent() as BattleCharacter
@onready var battle_state := get_node("/root/GameModeStateMachine/BattleState") as BattleState
@onready var think_state := get_node("../ThinkState") as PlayerThinkState

func _ready() -> void:
    battle_character.OnLeaveBattle.connect(_on_leave_battle)
    
func _on_leave_battle() -> void:
    if active:
        _stop_thinking()

func enter() -> void:
    battle_state.available_actions = BattleEnums.EAvailableCombatActions.MOVING
    think_state.player_think_ui.show()
    think_state.player_think_ui.set_text()

    print("[MOVE] " + battle_character.character_name + " is in the move state!")
    # Enable stick/WASD movement for the battle character
    battle_character.character_controller.free_movement = true
    battle_state.top_down_player.focused_node = battle_character.get_parent()
    battle_state.top_down_player.allow_moving_focus = false

func _back_to_think() -> void:
    Transitioned.emit(self, "ThinkState")

func _stop_thinking() -> void:
    Transitioned.emit(self, "IdleState")

func exit() -> void:
    print("[MOVE] " + battle_character.character_name + " is leaving the move state!")
    # Disable stick/WASD movement for the battle character
    battle_character.character_controller.stop_moving()
    battle_character.character_controller.free_movement = false
    battle_state.top_down_player.allow_moving_focus = true

    battle_state.available_actions = BattleEnums.EAvailableCombatActions.GROUND
    battle_state.select_character(battle_state.current_character, true)
    think_state.player_think_ui.set_text()


func _state_process(_delta: float) -> void: pass

func _state_physics_process(_delta: float) -> void:
    pass

func _state_input(_event: InputEvent) -> void: pass

func _state_unhandled_input(event: InputEvent) -> void:
    if (event.is_action_pressed("ui_cancel")
    or event.is_action_pressed("combat_move")):
        _back_to_think()
