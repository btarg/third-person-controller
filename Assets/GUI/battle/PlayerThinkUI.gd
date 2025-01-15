extends Control
class_name PlayerThinkUI

@onready var label := get_node("Label") as RichTextLabel
const IMG_SIZE: int = 48

@onready var battle_state := get_node("/root/GameModeStateMachine/BattleState") as BattleState

func _ready() -> void:
    ControllerHelper.OnInputDeviceChanged.connect(set_text)
    set_text()

func set_text() -> void:
    if not battle_state.active or not battle_state.current_character:
        return
    if battle_state.current_character.character_type != BattleEnums.CharacterType.PLAYER:
        return
    var current_player_think_state := battle_state.current_character.behaviour_state_machine.find_child("ThinkState") as PlayerThinkState
    if not current_player_think_state:
        return
    var _current_update_mode := current_player_think_state.available_actions

    label.bbcode_enabled = true
    label.text = ""
    
    if _current_update_mode == BattleEnums.EAvailableCombatActions.SELF:
        label.text += ControllerHelper.get_button_glyph_img_embed("combat_defend", IMG_SIZE) + " Defend\n"
    if _current_update_mode == BattleEnums.EAvailableCombatActions.ENEMY:
        label.text += ControllerHelper.get_button_glyph_img_embed("combat_attack", IMG_SIZE) + " Attack\n"
        label.text += ControllerHelper.get_button_glyph_img_embed("combat_draw", IMG_SIZE) + " Draw\n"

    if _current_update_mode == BattleEnums.EAvailableCombatActions.GROUND:
        label.text += ControllerHelper.get_button_glyph_img_embed("combat_move", IMG_SIZE) + " Move\n"
    else:
        label.text += ControllerHelper.get_button_glyph_img_embed("combat_spellitem", IMG_SIZE) + " Cast spell / use item\n"