extends Control
class_name PlayerThinkUI

@onready var label := get_node("Label") as RichTextLabel
const IMG_SIZE: int = 48

func _ready() -> void:
    ControllerHelper.OnInputDeviceChanged.connect(_set_text)
    _set_text()

func _set_text() -> void:
    label.bbcode_enabled = true
    label.text = ""
    label.text += ControllerHelper.get_button_glyph_img_embed("combat_attack", IMG_SIZE) + " Attack\n"
    label.text += ControllerHelper.get_button_glyph_img_embed("combat_spellitem", IMG_SIZE) + " Cast spell / use item\n"
    label.text += ControllerHelper.get_button_glyph_img_embed("combat_draw", IMG_SIZE) + " Draw\n"
    label.text += ControllerHelper.get_button_glyph_img_embed("combat_move", IMG_SIZE) + " Move\n"

func update_ground() -> void:
    print("Hello ground update!")

func update_enemy(character: BattleCharacter) -> void:
    print("Hello enemy update!")
func update_ally(character: BattleCharacter) -> void:
    print("Hello ally update!")
func update_self() -> void:
    print("Hello self update!")