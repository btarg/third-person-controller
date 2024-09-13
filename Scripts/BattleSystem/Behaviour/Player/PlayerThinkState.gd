class_name PlayerThinkState
extends State

# TODO: this isn't used for anything useful at the moment
@onready var exploration_player := get_tree().get_nodes_in_group("Player").front() as PlayerController

# TODO: get the battle character from the parent node
@onready var battle_character := get_parent().get_parent() as BattleCharacter
# One level up is state machine, two levels up is the battle character. The inventory is on the same level
@onready var inventory_manager := get_node("../../../Inventory") as InventoryManager
@onready var battle_state := get_node("/root/GameModeStateMachine/BattleState") as BattleState

@onready var player_think_ui := exploration_player.get_node("PlayerThinkUI") as Control
@onready var action_info_label := player_think_ui.get_node("CurrentActionInfo") as Label

var chosen_action: BattleEnums.EPlayerCombatAction = BattleEnums.EPlayerCombatAction.CA_DEFEND

@onready var fire_spell: BaseInventoryItem = preload("res://Scripts/Inventory/Resources/Spells/test_fire_spell.tres")
@onready var heal_spell: BaseInventoryItem = preload("res://Scripts/Inventory/Resources/Spells/test_healing_spell.tres")
@onready var almighty_spell: BaseInventoryItem = preload("res://Scripts/Inventory/Resources/Spells/test_almighty_spell.tres")
@onready var chosen_spell_or_item: BaseInventoryItem = fire_spell

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
    player_think_ui.show()
    # TODO: pick spell or item with UI
    chosen_spell_or_item = fire_spell
    action_info_label.text = "Current spell/item: " + chosen_spell_or_item.item_name

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
    if event.is_action_pressed("combat_attack"):
        chosen_action = BattleEnums.EPlayerCombatAction.CA_ATTACK
    elif event.is_action_pressed("combat_spellitem"):

        if chosen_spell_or_item.item_type == BaseInventoryItem.ItemType.SPELL:
            chosen_action = BattleEnums.EPlayerCombatAction.CA_CAST
        else:
            chosen_action = BattleEnums.EPlayerCombatAction.CA_ITEM
    elif event.is_action_pressed("combat_draw"):
        chosen_action = BattleEnums.EPlayerCombatAction.CA_DRAW
    else:
        return
    Transitioned.emit(self, "ChooseTargetState")

func unhandled_input_update(_event: InputEvent) -> void: pass
