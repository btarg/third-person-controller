extends State
class_name PlayerMoveState

@onready var battle_character := state_machine.get_parent() as BattleCharacter
@onready var battle_state := get_node("/root/GameModeStateMachine/BattleState") as BattleState
@onready var think_state := get_node("../ThinkState") as PlayerThinkState

var distance_travelled: int = 0.0
var turn_cost_to_move: int = 0

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
    battle_character.character_controller.movement_limited = true

    battle_state.top_down_player.focused_node = battle_character.get_parent()
    battle_state.top_down_player.allow_moving_focus = false

func _finish_move() -> void:

    # Add a small buffer to the distance travelled to prevent floating point errors
    if floor(distance_travelled) == 0 or distance_travelled > (battle_character.character_controller.movement_left + 0.1):
        print("[MOVE] " + battle_character.character_name + " cannot confirm move!")
        return
    
    print("[MOVE] " + battle_character.character_name + " has moved " + str(distance_travelled) + " units, spending " +
        str(turn_cost_to_move) + " turns!")

    if (turn_cost_to_move > battle_character.actions_left):
        print("[MOVE] " + battle_character.character_name + " has no turns left to move!")
        return


    _back_to_think()
    battle_character.spend_actions(turn_cost_to_move)

    # Reset the distance travelled
    distance_travelled = 0
    turn_cost_to_move = 0
    battle_character.character_controller.update_home_position()


func _back_to_think() -> void:
    Transitioned.emit(self, "ThinkState")

func _stop_thinking() -> void:
    Transitioned.emit(self, "IdleState")

func exit() -> void:
    print("[MOVE] " + battle_character.character_name + " is leaving the move state!")
    # Disable stick/WASD movement for the battle character
    battle_character.character_controller.stop_moving()
    battle_character.character_controller.free_movement = false
    battle_character.character_controller.movement_limited = false
    battle_state.top_down_player.allow_moving_focus = true

    battle_state.available_actions = BattleEnums.EAvailableCombatActions.GROUND
    battle_state.select_character(battle_state.current_character, true)
    think_state.player_think_ui.set_text()


func _state_process(_delta: float) -> void:
    pass

func _state_physics_process(_delta: float) -> void:
    distance_travelled = int(battle_character.character_controller.home_position.distance_to(
        battle_character.character_controller.global_position))

    if floor(distance_travelled) == 0:
        turn_cost_to_move = 0
        return

    turn_cost_to_move = max(1, ceili(distance_travelled / battle_character.stats.get_stat(
        CharacterStatEntry.ECharacterStat.Speed)))

    print("[MOVE] it will cost " + str(turn_cost_to_move) + " turns to move " + str(distance_travelled) + " units! (base speed: " +
        str(battle_character.stats.get_stat(CharacterStatEntry.ECharacterStat.Speed)) + ")")


func _state_unhandled_input(event: InputEvent) -> void:
    if (event.is_action_pressed("ui_cancel")):
        battle_character.character_controller.return_to_home_position()
        _back_to_think()
    elif (event.is_action_pressed("combat_move")):
        _finish_move()

func _state_input(_event: InputEvent) -> void: pass