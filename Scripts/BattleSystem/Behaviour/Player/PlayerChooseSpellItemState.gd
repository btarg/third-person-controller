extends LineRenderingState
class_name PlayerChooseSpellItemState

@onready var battle_state := get_node("/root/GameModeStateMachine/BattleState") as BattleState
@onready var think_state := get_node("../ThinkState") as PlayerThinkState

@onready var spell_ui := battle_state.get_node("PlayerChooseSpellitemUI") as Control
@onready var spell_scroll_menu := spell_ui.get_node("ButtonScrollMenu") as ButtonScrollMenu

func _ready() -> void:
    spell_scroll_menu.item_button_pressed.connect(_choose_spell_item)
    spell_ui.hide()

func enter() -> void:

    spell_scroll_menu.item_inventory = battle_state.current_character.inventory
    print("[SPELL/ITEM] " + str(battle_state.current_character.inventory.items.size()) + " items in inventory")
    spell_ui.show()

    battle_state.top_down_player.allow_moving_focus = false

    # Only render line for enemies and allies
    if (battle_state.available_actions in 
    [BattleEnums.EAvailableCombatActions.NONE,
    BattleEnums.EAvailableCombatActions.SELF]
    or battle_state.player_selected_character == null
    or battle_state.selected_self()):
        should_render_line = false

    else:
        line_current_character = battle_state.current_character
        line_target_character = battle_state.player_selected_character
        should_render_line = true

    battle_state.top_down_player.focused_node = battle_state.player_selected_character.get_parent()

func _choose_spell_item(spell: BaseInventoryItem) -> void:
    if not active:
        return

    print("[SPELL/ITEM] Spell chosen: " + spell.item_name)
    think_state.chosen_spell_or_item = spell

    if think_state.chosen_spell_or_item.item_type == BaseInventoryItem.ItemType.SPELL:
        think_state.chosen_action = BattleEnums.EPlayerCombatAction.CA_CAST
    else:
        think_state.chosen_action = BattleEnums.EPlayerCombatAction.CA_ITEM

    if think_state.chosen_spell_or_item.can_use_on(
        battle_state.current_character, battle_state.player_selected_character):
        Transitioned.emit(self, "ChooseTargetState")
    else:
        print("[SPELL/ITEM] Cannot use " + think_state.chosen_spell_or_item.item_name + " on " + battle_state.player_selected_character.character_name)

func _back_to_think() -> void:
    if active:
        Transitioned.emit(self, "ThinkState")

func exit() -> void:
    should_render_line = false
    spell_ui.hide()

    super.exit()

func _state_process(_delta: float) -> void: pass
func _state_physics_process(_delta: float) -> void:
    super._state_physics_process(_delta)


func _state_input(event: InputEvent) -> void:
    if event.is_action_pressed("ui_cancel"):
        _back_to_think()
    if event is InputEventKey:
        if event.is_pressed():
            if event.keycode == KEY_1:
                spell_scroll_menu.item_inventory = battle_state.current_character.inventory

func _state_unhandled_input(_event: InputEvent) -> void: pass
