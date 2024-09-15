class_name PlayerThinkState
extends State

# TODO: this isn't used for anything useful at the moment
@onready var exploration_player := get_tree().get_nodes_in_group("Player").front() as PlayerController

# TODO: get the battle character from the parent node
@onready var battle_character := get_parent().get_parent() as BattleCharacter
# One level up is state machine, two levels up is the battle character. The inventory is on the same level
@onready var inventory_manager := get_node("../../../Inventory") as InventoryManager
@onready var battle_state := get_node("/root/GameModeStateMachine/BattleState") as BattleState

@onready var player_think_ui := battle_state.get_node("PlayerThinkUI") as Control
@onready var action_info_label := player_think_ui.get_node("CurrentActionInfo") as Label

var chosen_action: BattleEnums.EPlayerCombatAction = BattleEnums.EPlayerCombatAction.CA_DEFEND

@onready var fire_spell: BaseInventoryItem = preload("res://Scripts/Inventory/Resources/Spells/test_fire_spell.tres")
@onready var heal_spell: BaseInventoryItem = preload("res://Scripts/Inventory/Resources/Spells/test_healing_spell.tres")
@onready var almighty_spell: BaseInventoryItem = preload("res://Scripts/Inventory/Resources/Spells/test_almighty_spell.tres")
@onready var chosen_spell_or_item: BaseInventoryItem = fire_spell

## State machine within a state machine!!!!
enum EPlayerThinkUIState {
    NONE,
    CHOOSING_ACTION,
    SELECT_SPELL_ITEM,
    SELECT_TARGET
}
## This is used for selecting spells, items etc. via UI before moving to target selection
@export var current_player_think_ui_state := EPlayerThinkUIState.NONE:
    get:
        return current_player_think_ui_state
    set(value):
        current_player_think_ui_state = value

        match value:
            EPlayerThinkUIState.CHOOSING_ACTION:
                action_info_label.text = "Choose an action"
            EPlayerThinkUIState.SELECT_SPELL_ITEM:
                action_info_label.text = "Press again for " + chosen_spell_or_item.item_name
            _:
                action_info_label.text = ""


func _ready() -> void:
    Console.add_command("choose_item", _choose_item_command, 1)

    player_think_ui.hide()
    battle_character.OnLeaveBattle.connect(_on_leave_battle)

func _choose_item_command(item_name: String) -> void:
    if not active:
        return

    var item: BaseInventoryItem = inventory_manager.get_item(item_name)
    if item:
        chosen_spell_or_item = item
        Console.print_line("Chosen item: " + item_name)
    else:
        Console.print_line("Item not found") 

func _on_leave_battle() -> void:
    if active:
        Transitioned.emit(self, "IdleState")
    else:
        exit()

func enter() -> void:
    current_player_think_ui_state = EPlayerThinkUIState.CHOOSING_ACTION

    player_think_ui.show()

    # TODO: pick spell or item with UI
    chosen_spell_or_item = fire_spell

    print("PLAYER is thinking about what to do")

    # remember last selected character
    if battle_state.player_selected_character:
        print("Selected character: " + battle_state.player_selected_character.character_name)
    else:
        print("No character selected")


func exit() -> void:
    current_player_think_ui_state = EPlayerThinkUIState.NONE
    print(battle_character.character_name + " has stopped thinking")
    player_think_ui.hide()

func update(_delta: float) -> void: pass
func physics_update(_delta: float) -> void: pass

func input_update(event: InputEvent) -> void:
    if event.is_echo() or not active:
        return

    if event is InputEventKey and event.keycode == KEY_G:
        print("Think UI state: " + Util.get_enum_name(EPlayerThinkUIState, current_player_think_ui_state)) 
        return

    elif event.is_action_pressed("ui_cancel"):
        if current_player_think_ui_state != EPlayerThinkUIState.CHOOSING_ACTION:
            current_player_think_ui_state = EPlayerThinkUIState.CHOOSING_ACTION
            return
        else:
            battle_state.force_exit_battle()
            return
    elif event.is_action_pressed("combat_attack"):
        if current_player_think_ui_state != EPlayerThinkUIState.CHOOSING_ACTION:
            return
        chosen_action = BattleEnums.EPlayerCombatAction.CA_ATTACK
        
    elif event.is_action_pressed("combat_spellitem"):
        if current_player_think_ui_state != EPlayerThinkUIState.SELECT_SPELL_ITEM:
            current_player_think_ui_state = EPlayerThinkUIState.SELECT_SPELL_ITEM
            return
        else:
            if chosen_spell_or_item.item_type == BaseInventoryItem.ItemType.SPELL:
                chosen_action = BattleEnums.EPlayerCombatAction.CA_CAST
            else:
                chosen_action = BattleEnums.EPlayerCombatAction.CA_ITEM

    elif (event.is_action_pressed("combat_draw")
    and current_player_think_ui_state == EPlayerThinkUIState.CHOOSING_ACTION):
        chosen_action = BattleEnums.EPlayerCombatAction.CA_DRAW
    else:
        return
    
    current_player_think_ui_state = EPlayerThinkUIState.SELECT_TARGET
    Transitioned.emit(self, "ChooseTargetState")

func unhandled_input_update(_event: InputEvent) -> void: pass
