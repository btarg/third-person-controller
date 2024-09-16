extends Sprite2D

# func _ready() -> void:
#     ControllerHelper.OnInputDeviceChanged.connect(_set_glyph)

func _input(event: InputEvent) -> void:
    for action in InputMap.get_actions():
        if event.is_action(action) and event.is_pressed():
            _set_glyph(action)

func _set_glyph(action_name: String) -> void:
    var glyph_path := ControllerHelper.get_button_glyph(action_name, false, true)
    if glyph_path == "NONE":
        return

    texture = load(glyph_path) as Texture
    print("Glyph path for %s: %s" % [action_name, glyph_path])