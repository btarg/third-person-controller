extends RichTextLabel

const IMG_SIZE: int = 48

func _ready() -> void:
    ControllerHelper.OnInputDeviceChanged.connect(_set_text)
    _set_text()

func _set_text() -> void:
    bbcode_enabled = true
    text = ""
    text += ControllerHelper.get_button_glyph_img_embed("combat_attack", IMG_SIZE) + " Confirm\n"
    text += ControllerHelper.get_button_glyph_img_embed("ui_cancel", IMG_SIZE) + " Cancel\n"