extends State
class_name PlayerThinkState

@onready var player := get_tree().get_nodes_in_group("Player").front() as PlayerController
@onready var battle_character := player.get_node("BattleCharacter") as BattleCharacter
@onready var battle_state := get_node("/root/GameModeStateMachine/BattleState") as BattleState


func _ready() -> void:
    battle_character.LeaveBattle.connect(_on_leave_battle)

func _on_leave_battle() -> void:
    if active:
        Transitioned.emit(self, "IdleState")

func enter() -> void:
    print("PLAYER is thinking about what to do")
    if battle_state.player_selected_character:
        print("Selected character: " + battle_state.player_selected_character.character_name)
    else:
        print("No character selected")


func exit() -> void:
    print(battle_character.character_name + " has stopped thinking")

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