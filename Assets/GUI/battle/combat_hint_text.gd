extends RichTextLabel

const IMG_SIZE: int = 48

func _ready() -> void:
    ControllerHelper.OnInputDeviceChanged.connect(_set_text)
    _set_text()

func _set_text() -> void:
    bbcode_enabled = true
    text = ""
    text += ControllerHelper.get_button_glyph_img_embed("combat_attack", IMG_SIZE) + " Attack\n"
    text += ControllerHelper.get_button_glyph_img_embed("combat_spellitem", IMG_SIZE) + " Cast spell / use item\n"
    text += ControllerHelper.get_button_glyph_img_embed("combat_draw", IMG_SIZE) + " Draw\n"
    text += ControllerHelper.get_button_glyph_img_embed("combat_move", IMG_SIZE) + " Move\n"