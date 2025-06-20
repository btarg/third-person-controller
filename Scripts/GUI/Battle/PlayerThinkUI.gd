extends Control
class_name PlayerThinkUI

@onready var label := get_node("Label") as RichTextLabel
const IMG_SIZE: int = 48

@onready var battle_state := GameModeStateMachine.get_node("BattleState") as BattleState
@onready var crosshair := $Crosshair as TextureRect

func _ready() -> void:
    crosshair.visible = false
    ControllerHelper.OnInputDeviceChanged.connect(set_text)
    BattleSignalBus.OnAvailableCombatChoicesChanged.connect(set_text)
    label.bbcode_enabled = true
    
    set_text()

func set_text() -> void:
    if not battle_state.active or not battle_state.current_character:
        return
    if battle_state.current_character.character_type != BattleEnums.ECharacterType.PLAYER:
        return

    var final_text := ""

    if ControllerHelper.is_using_controller:
        crosshair.visible = (battle_state.available_actions != BattleEnums.EAvailableCombatActions.MOVING)
        final_text += ControllerHelper.get_button_glyph_img_embed("look_left", IMG_SIZE, true, false) + " Pan camera\n"
        final_text += ControllerHelper.get_button_glyph_img_embed("look_up", IMG_SIZE, false, true) + " Zoom\n"
    else:
        crosshair.visible = false

        final_text += ControllerHelper.get_button_glyph_img_embed("right_click", IMG_SIZE) + " Pan camera\n"
        final_text += ControllerHelper.get_button_glyph_img_embed_by_name("keyboard_mouse/mouse_scroll_vertical", IMG_SIZE) + " Zoom\n"
    
    # Get current state to determine what hints to show
    var current_state_machine := battle_state.current_character.behaviour_state_machine
    var current_state := current_state_machine.current_state
    var is_in_targeting_state := current_state and current_state.name == "PlayerTargetingState"
    
    # Spell/item selection is always available (except when moving)
    if battle_state.available_actions != BattleEnums.EAvailableCombatActions.MOVING:
        if is_in_targeting_state:
            # In targeting mode - check if we have a valid target before showing confirm hint            
            # Get the targeting state to check the selected spell
            var targeting_state := current_state as PlayerTargetingState
            if targeting_state and targeting_state.selected_spell_item:
                
                # Always assume valid target for field spells
                var can_confirm_target := targeting_state.is_valid_target(battle_state.player_selected_character)\
                if battle_state.player_selected_character else targeting_state.selected_spell_item.item_type == BaseInventoryItem.ItemType.FIELD_SPELL
                

                if can_confirm_target:
                    final_text += ControllerHelper.get_button_glyph_img_embed("combat_select_target", IMG_SIZE) + " Confirm target\n"
                
            final_text += ControllerHelper.get_button_glyph_img_embed("ui_cancel", IMG_SIZE) + " Back to spell selection\n"
        else:
            # In think mode - always show spell/item selection
            final_text += ControllerHelper.get_button_glyph_img_embed("combat_spellitem", IMG_SIZE) + " Cast spell / use item\n"
    
    # Context-sensitive actions based on what's being targeted
    if battle_state.available_actions == BattleEnums.EAvailableCombatActions.ENEMY and not is_in_targeting_state:
        # Only show attack/draw when hovering enemies in think state (not targeting state)
        final_text += ControllerHelper.get_button_glyph_img_embed("combat_select_target", IMG_SIZE) + " Attack\n"
        final_text += ControllerHelper.get_button_glyph_img_embed("combat_draw", IMG_SIZE) + " Draw\n"
    
    elif battle_state.available_actions in [BattleEnums.EAvailableCombatActions.SELF, BattleEnums.EAvailableCombatActions.GROUND] and not is_in_targeting_state:
        # Movement is available when hovering ground or self (not in targeting state)
        final_text += ControllerHelper.get_button_glyph_img_embed("combat_move", IMG_SIZE) + " Move\n"
        # final_text += ControllerHelper.get_button_glyph_img_embed("combat_defend", IMG_SIZE) + " Defend\n"
    
    elif battle_state.available_actions == BattleEnums.EAvailableCombatActions.MOVING:
        # Special movement state
        if ControllerHelper.is_using_controller:
            final_text += ControllerHelper.get_button_glyph_img_embed("move_forwards", IMG_SIZE, true, true) + " Move\n"
        else:
            final_text += ControllerHelper.get_button_glyph_img_embed_by_name("keyboard_mouse/keyboard_arrows_all", IMG_SIZE) + " Move\n"

        final_text += ControllerHelper.get_button_glyph_img_embed("run", IMG_SIZE) + " Sprint\n"
        final_text += ControllerHelper.get_button_glyph_img_embed("combat_move", IMG_SIZE) + " Confirm movement\n"
        final_text += ControllerHelper.get_button_glyph_img_embed("ui_cancel", IMG_SIZE) + " Cancel movement\n"
    
    label.text = final_text