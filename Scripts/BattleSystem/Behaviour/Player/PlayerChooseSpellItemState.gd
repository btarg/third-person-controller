extends LineRenderingState
class_name PlayerChooseSpellItemState

@onready var battle_state := get_node("/root/GameModeStateMachine/BattleState") as BattleState
@onready var battle_character := state_machine.get_parent() as BattleCharacter

@onready var think_state := get_node("../ThinkState") as PlayerThinkState

@onready var inventory_ui := battle_state.get_node("PlayerChooseSpellitemUI") as Control
@onready var inv_scroll_menu := inventory_ui.get_node("ButtonScrollMenu") as ButtonScrollMenu

func _ready() -> void:
    inv_scroll_menu.item_button_pressed.connect(_choose_spell_item)
    inventory_ui.hide()

func enter() -> void:
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


    inv_scroll_menu.item_inventory = battle_state.current_character.inventory
    inv_scroll_menu.update_labels()
    inventory_ui.show()
    print("[SPELL/ITEM] " + str(battle_state.current_character.inventory.items.size()) + " items in inventory")

    battle_state.top_down_player.focused_node = battle_state.player_selected_character.get_parent()

func _choose_spell_item(chosen_item: BaseInventoryItem) -> void:
    if not active or not chosen_item:
        return

    # If we are using the item on another character, check if the target is in range
    if battle_state.available_actions != BattleEnums.EAvailableCombatActions.SELF:
        # distance between current character and selected character
        # floor this to int to prevent bullshit
        var distance: float = floori(battle_state.current_character.get_parent().global_position.distance_to(
            battle_state.player_selected_character.get_parent().global_position))
        # TODO: draw spell range radius
        if (distance > battle_state.current_character.stats.get_stat(CharacterStatEntry.ECharacterStat.AttackRange)
        or distance > chosen_item.effective_range):
            print("[SPELL/ITEM] Target is out of range (distance: " + str(distance) + ", range: " + str(chosen_item.effective_range) + ")")
            return


    if chosen_item.can_use_on(
        battle_state.current_character, battle_state.player_selected_character):
        should_render_line = false
        inventory_ui.hide()
        await battle_state.message_ui.show_messages([chosen_item.item_name])
        var status := chosen_item.use(battle_state.current_character, battle_state.player_selected_character)
        print("[SPELL/ITEM] Final use status: " + Util.get_enum_name(BaseInventoryItem.UseStatus, status))
        _end_targeting()
    else:
        print("[SPELL/ITEM] Cannot use " + chosen_item.item_name + " on " + battle_state.player_selected_character.character_name)

func _end_targeting() -> void:
    # check if active in case the character has left the battle (ie. died)
    if not active:
        return
    _back_to_think()
    battle_character.spend_actions(1)

func _back_to_think() -> void:
    if active:
        Transitioned.emit(self, "ThinkState")

func exit() -> void:
    should_render_line = false
    inventory_ui.hide()

    super.exit()

func _state_process(_delta: float) -> void: pass
func _state_physics_process(_delta: float) -> void:
    super._state_physics_process(_delta)

func _state_input(event: InputEvent) -> void:
    if event.is_action_pressed("ui_cancel"):
        _back_to_think()

func _state_unhandled_input(_event: InputEvent) -> void: pass
