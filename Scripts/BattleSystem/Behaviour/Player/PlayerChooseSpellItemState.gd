extends State
class_name PlayerChooseSpellItemState

@onready var battle_state := GameModeStateMachine.get_node("BattleState") as BattleState
@onready var battle_character := state_machine.get_parent() as BattleCharacter

@onready var inventory_ui := battle_state.get_node("PlayerChooseSpellitemUI") as Control
@onready var inv_scroll_menu := inventory_ui.get_node("ButtonScrollMenu") as ButtonScrollMenu

# Store the selected spell for targeting
var selected_spell_item: BaseInventoryItem = null

func _ready() -> void:
    inv_scroll_menu.item_button_pressed.connect(_choose_spell_item)
    inv_scroll_menu.item_button_hovered.connect(_hover_spell_item)
    inventory_ui.hide()

func enter() -> void:
    selected_spell_item = null
    
    inv_scroll_menu.item_inventory = battle_state.current_character.inventory
    inv_scroll_menu.update_labels()
    inventory_ui.show()
    print("[SPELL/ITEM] " + str(battle_state.current_character.inventory.items.size()) + " items in inventory")

    # Focus the appropriate character and disable camera movement
    var should_focus := battle_state.available_actions not in [
        BattleEnums.EAvailableCombatActions.GROUND,
        BattleEnums.EAvailableCombatActions.NONE
    ]
    
    if should_focus:
        var target_character: BattleCharacter = battle_state.player_selected_character
        
        # If action is SELF or no target selected, focus current character
        if (battle_state.available_actions == BattleEnums.EAvailableCombatActions.SELF
        or not battle_state.player_selected_character):
            target_character = battle_state.current_character
            
        battle_state.top_down_player.focused_node = target_character.get_parent()
    else:
        battle_state.top_down_player.stop_moving()
    battle_state.top_down_player.allow_moving_focus = false


func _hover_spell_item(chosen_item: BaseInventoryItem) -> void:
    if not active or not chosen_item:
        return
    # TODO: Could add preview logic here in the future

func _choose_spell_item(chosen_item: BaseInventoryItem) -> void:
    if not active or not chosen_item:
        return

    # Store the selected item for the targeting state
    selected_spell_item = chosen_item
    
    # Check if we have enough resources to use this item
    if not chosen_item.can_use_on(battle_state.current_character, battle_state.current_character, false):
        if not chosen_item.check_cost(battle_state.current_character):
            print("[SPELL/ITEM] Cannot afford " + chosen_item.item_name)
            return

    print("[SPELL/ITEM] Selected " + chosen_item.item_name + " - moving to targeting")
    
    # Hide inventory and transition to targeting state
    inventory_ui.hide()
    Transitioned.emit(self, "PlayerTargetingState")

func _back_to_think() -> void:
    if active:
        Transitioned.emit(self, "ThinkState")

func exit() -> void:
    inventory_ui.hide()
    super.exit()

func _state_process(_delta: float) -> void: pass
func _state_physics_process(_delta: float) -> void: pass

func _state_input(event: InputEvent) -> void:
    if event.is_action_pressed("ui_cancel"):
        _back_to_think()

func _state_unhandled_input(_event: InputEvent) -> void: pass
