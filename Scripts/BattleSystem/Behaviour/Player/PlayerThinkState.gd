extends State
class_name PlayerThinkState

@onready var player := get_tree().get_nodes_in_group("Player").front() as PlayerController
@onready var battle_character := player.get_node("BattleCharacter") as BattleCharacter
@onready var battle_state := get_node("/root/GameModeStateMachine/BattleState") as BattleState

@onready var player_think_ui := player.get_node("PlayerThinkUI") as Control

func _ready() -> void:
    player_think_ui.hide()
    battle_character.LeaveBattle.connect(_on_leave_battle)

func _on_leave_battle() -> void:
    if active:
        Transitioned.emit(self, "IdleState")

func enter() -> void:
    player_think_ui.show()

    print("PLAYER is thinking about what to do")

    # remember last selected character
    if battle_state.player_selected_character:
        print("Selected character: " + battle_state.player_selected_character.character_name)
        player_think_ui.get_node("SelectedEnemyLabel").text = "Selected: " + battle_state.player_selected_character.character_name
    else:
        print("No character selected")
        player_think_ui.get_node("SelectedEnemyLabel").text = "No character selected"


func exit() -> void:
    print(battle_character.character_name + " has stopped thinking")
    player_think_ui.hide()

func update(_delta: float) -> void: pass

func physics_update(_delta: float) -> void: pass
func input_update(event: InputEvent) -> void:
    if event.is_echo():
        return

    if event.is_action_pressed("left_click"):
        Transitioned.emit(self, "ChooseTargetState")
    elif event.is_action_pressed("ui_select"):
        print("Player attacks!")
        _on_leave_battle()
        battle_character.battle_state.ready_next_turn()

func unhandled_input_update(_event: InputEvent) -> void: pass