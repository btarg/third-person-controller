extends LineRenderingState
class_name PlayerChooseSpellItemState

@onready var battle_state := get_node("/root/GameModeStateMachine/BattleState") as BattleState
@onready var battle_character := state_machine.get_parent() as BattleCharacter

@onready var think_state := get_node("../ThinkState") as PlayerThinkState

@onready var inventory_ui := battle_state.get_node("PlayerChooseSpellitemUI") as Control
@onready var inv_scroll_menu := inventory_ui.get_node("ButtonScrollMenu") as ButtonScrollMenu

# Ground position capture for "use anywhere" spells
var captured_ground_position := Vector3.ZERO

func _ready() -> void:
    inv_scroll_menu.item_button_pressed.connect(_choose_spell_item)
    inv_scroll_menu.item_button_hovered.connect(_hover_spell_item)
    inventory_ui.hide()

func enter() -> void:
    # Capture ground position when entering if we're targeting ground
    if battle_state.available_actions == BattleEnums.EAvailableCombatActions.GROUND:
        _capture_ground_position()

    # Only render line for enemies and allies
    if (battle_state.available_actions in 
    [BattleEnums.EAvailableCombatActions.NONE,
    BattleEnums.EAvailableCombatActions.SELF,
    BattleEnums.EAvailableCombatActions.GROUND]
    or battle_state.player_selected_character == null
    or battle_state.selected_self()):
        should_render_line = false
    else:
        captured_ground_position = battle_state.player_selected_character.get_parent().global_position
        line_current_character = battle_state.current_character
        line_target_character = battle_state.player_selected_character
        should_render_line = true

    inv_scroll_menu.item_inventory = battle_state.current_character.inventory
    inv_scroll_menu.update_labels()
    inventory_ui.show()
    print("[SPELL/ITEM] " + str(battle_state.current_character.inventory.items.size()) + " items in inventory")

    # Don't move focus unless targeting none or self
    if (battle_state.available_actions != BattleEnums.EAvailableCombatActions.GROUND):
        battle_state.top_down_player.allow_moving_focus = false
        battle_state.top_down_player.focused_node = battle_state.player_selected_character.get_parent()

func _hover_spell_item(chosen_item: BaseInventoryItem) -> void:
    if not active or not chosen_item:
        return

    # If the item is a spell, set the focus and move the camera to the spell target
    if chosen_item is SpellItem:
        var spell_item := chosen_item as SpellItem
        if spell_item.item_type == BaseInventoryItem.ItemType.SPELL_USE_ANYWHERE:
            # For free target spells, we can just show the ground position
            battle_state.top_down_player.focused_node = null
            battle_state.top_down_player.focus_position(captured_ground_position)
        else:
            # For other spells, focus on the selected character
            battle_state.top_down_player.focused_node = battle_state.player_selected_character.get_parent()
        battle_state.top_down_player.allow_moving_focus = false

func _choose_spell_item(chosen_item: BaseInventoryItem) -> void:
    if not active or not chosen_item:
        return

    # ==============================================================================
    # FREE TARGET SPELLS
    # ==============================================================================
    if (battle_state.available_actions == BattleEnums.EAvailableCombatActions.GROUND
        or battle_state.player_selected_character == battle_state.current_character):
        # Check if the item supports free targeting (use anywhere)
        var spell_item := chosen_item as SpellItem
        if spell_item and spell_item.item_type == BaseInventoryItem.ItemType.SPELL_USE_ANYWHERE:
            # Use captured ground position directly for ground targeting
            if battle_state.available_actions == BattleEnums.EAvailableCombatActions.GROUND:
                _confirm_spell_at_captured_position(spell_item)
                return

    # ==============================================================================
    # Default back to selecting self
    # ==============================================================================

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
        
        battle_character.spend_actions(chosen_item.actions_cost)
        _end_targeting()

    else:
        print("[SPELL/ITEM] Cannot use " + chosen_item.item_name + " on " + battle_state.player_selected_character.character_name)

func _confirm_spell_at_captured_position(spell_item: SpellItem) -> void:
    print("[GROUND TARGET] Using spell at captured position: " + str(captured_ground_position))
    
    # Use the spell at the captured position
    var spawned := SpellHelper.spawn_aoe_spell_effect(spell_item, battle_state.current_character, captured_ground_position)
    
    if not spawned:
        print("[GROUND TARGET] Failed to spawn spell effect at position: " + str(captured_ground_position))
        return
    
    # Spend the action cost
    battle_character.spend_actions(spell_item.actions_cost)
    
    # End targeting and go back to think state
    _end_targeting()

func _end_targeting() -> void:
    # check if active in case the character has left the battle (ie. died)
    if not active:
        return
    _back_to_think()

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

func _capture_ground_position() -> void:
    # Get the ground position from the current raycast when entering the state
    var camera := get_viewport().get_camera_3d()
    if camera:
        var result := Util.raycast_from_center_or_mouse(camera)
        
        if result:
            captured_ground_position = result.position
            print("[GROUND CAPTURE] Captured ground position: " + str(captured_ground_position))
        else:
            # Fallback to a position in front of the caster
            captured_ground_position = battle_state.current_character.get_parent().global_position + Vector3.FORWARD * 5.0
            print("[GROUND CAPTURE] Used fallback position: " + str(captured_ground_position))
