class_name PlayerThinkState
extends State

@onready var player := get_tree().get_nodes_in_group("Player").front() as PlayerController
@onready var battle_character := player.get_node("BattleCharacter") as BattleCharacter
@onready var battle_state := get_node("/root/GameModeStateMachine/BattleState") as BattleState

@onready var player_think_ui := player.get_node("PlayerThinkUI") as Control

var chosen_action: BattleEnums.EPlayerCombatAction = BattleEnums.EPlayerCombatAction.CA_DEFEND
@onready var chosen_spell_or_item: BaseInventoryItem = preload("res://Scripts/Inventory/Resources/Spells/test_fire_spell.tres")

func _ready() -> void:
    player_think_ui.hide()
    battle_character.OnLeaveBattle.connect(_on_leave_battle)

func _on_leave_battle() -> void:
    if active:
        Transitioned.emit(self, "IdleState")
    else:
        exit()

func enter() -> void:
    player_think_ui.show()

    print("PLAYER is thinking about what to do")

    # remember last selected character
    if battle_state.player_selected_character:
        print("Selected character: " + battle_state.player_selected_character.character_name)
    else:
        print("No character selected")


func exit() -> void:
    print(battle_character.character_name + " has stopped thinking")
    player_think_ui.hide()

func update(_delta: float) -> void: pass


func physics_update(_delta: float) -> void: pass
func input_update(event: InputEvent) -> void:
    if event.is_echo() or not active:
        return
    # TODO: pick action with UI - add signal to a button
    if event.is_action_pressed("left_click"):
        chosen_action = BattleEnums.EPlayerCombatAction.CA_CAST_ENEMY
        # TODO: also pick spell/item with UI
        Transitioned.emit(self, "ChooseTargetState")

func unhandled_input_update(_event: InputEvent) -> void: pass
