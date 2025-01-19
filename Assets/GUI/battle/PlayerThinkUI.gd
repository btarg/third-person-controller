extends Control
class_name PlayerThinkUI

@onready var label := get_node("Label") as RichTextLabel
const IMG_SIZE: int = 48

@onready var battle_state := get_node("/root/GameModeStateMachine/BattleState") as BattleState
@onready var crosshair := $Crosshair as TextureRect

func _ready() -> void:
    crosshair.visible = false
    ControllerHelper.OnInputDeviceChanged.connect(set_text)
    BattleSignalBus.OnAvailableActionsChanged.connect(set_text)
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
    
    # We can move and defend when hovering ground or self
    if battle_state.available_actions in [BattleEnums.EAvailableCombatActions.SELF,
    BattleEnums.EAvailableCombatActions.GROUND]:
        final_text += ControllerHelper.get_button_glyph_img_embed("combat_defend", IMG_SIZE) + " Defend\n"
        final_text += ControllerHelper.get_button_glyph_img_embed("combat_move", IMG_SIZE) + " Move\n"

    if battle_state.available_actions == BattleEnums.EAvailableCombatActions.ENEMY:
        final_text += ControllerHelper.get_button_glyph_img_embed("combat_attack", IMG_SIZE) + " Attack\n"
        final_text += ControllerHelper.get_button_glyph_img_embed("combat_draw", IMG_SIZE) + " Draw\n"


    if battle_state.available_actions == BattleEnums.EAvailableCombatActions.MOVING:

        if ControllerHelper.is_using_controller:
            final_text += ControllerHelper.get_button_glyph_img_embed("move_forwards", IMG_SIZE, true, true) + " Move\n"
        else:
            final_text += ControllerHelper.get_button_glyph_img_embed_by_name("keyboard_mouse/keyboard_arrows_all", IMG_SIZE) + " Move\n"

        final_text += ControllerHelper.get_button_glyph_img_embed("run", IMG_SIZE) + " Sprint\n"
        final_text += ControllerHelper.get_button_glyph_img_embed("ui_cancel", IMG_SIZE) + " Cancel movement\n"
    
    else:
        final_text += ControllerHelper.get_button_glyph_img_embed("combat_spellitem", IMG_SIZE) + " Cast spell / use item\n"
    
    label.text = final_text