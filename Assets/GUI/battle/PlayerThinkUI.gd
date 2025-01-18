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
    
    set_text()

func set_text() -> void:
    if not battle_state.active or not battle_state.current_character:
        return
    if battle_state.current_character.character_type != BattleEnums.ECharacterType.PLAYER:
        return

    label.bbcode_enabled = true
    label.text = ""

    if ControllerHelper.is_using_controller:
        crosshair.visible = (battle_state.available_actions != BattleEnums.EAvailableCombatActions.MOVING)
        label.text += ControllerHelper.get_button_glyph_img_embed("look_left", IMG_SIZE, true, false) + " Pan camera\n"
        label.text += ControllerHelper.get_button_glyph_img_embed("look_up", IMG_SIZE, false, true) + " Zoom\n"
    else:
        crosshair.visible = false

        label.text += ControllerHelper.get_button_glyph_img_embed("right_click", IMG_SIZE) + " Pan camera\n"
        label.text += ControllerHelper.get_button_glyph_img_embed_by_name("keyboard_mouse/mouse_scroll_vertical", IMG_SIZE) + " Zoom\n"
    
    if battle_state.available_actions == BattleEnums.EAvailableCombatActions.SELF:
        label.text += ControllerHelper.get_button_glyph_img_embed("combat_defend", IMG_SIZE) + " Defend\n"
    if battle_state.available_actions == BattleEnums.EAvailableCombatActions.ENEMY:
        label.text += ControllerHelper.get_button_glyph_img_embed("combat_attack", IMG_SIZE) + " Attack\n"
        label.text += ControllerHelper.get_button_glyph_img_embed("combat_draw", IMG_SIZE) + " Draw\n"

    if battle_state.available_actions == BattleEnums.EAvailableCombatActions.GROUND:
        label.text += ControllerHelper.get_button_glyph_img_embed("combat_move", IMG_SIZE) + " Move\n"

    elif battle_state.available_actions == BattleEnums.EAvailableCombatActions.MOVING:

        if ControllerHelper.is_using_controller:
            label.text += ControllerHelper.get_button_glyph_img_embed("move_forwards", IMG_SIZE, true, true) + " Move\n"
        else:
            label.text += ControllerHelper.get_button_glyph_img_embed_by_name("keyboard_mouse/keyboard_arrows_all", IMG_SIZE) + " Move\n"

        label.text += ControllerHelper.get_button_glyph_img_embed("run", IMG_SIZE) + " Sprint\n"
        label.text += ControllerHelper.get_button_glyph_img_embed("ui_cancel", IMG_SIZE) + " Cancel movement\n"
    
    else:
        label.text += ControllerHelper.get_button_glyph_img_embed("combat_spellitem", IMG_SIZE) + " Cast spell / use item\n"
    