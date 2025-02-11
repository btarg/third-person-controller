extends Node

enum ControllerLayout {
    XBOX,
    PS5,
    PS4,
    NINTENDO_PRO,
    NINTENDO_JOYCON
}

const EXTENSION := ".svg"
const PATH := "res://Assets/GUI/Icons/ControllerGlyphs/"

var current_controller_layout := ControllerLayout.XBOX
var player1_device := 0

var last_input_event: InputEvent = null
const JOYSTICK_DEADZONE := 0.25

## Key: action name, Value: path to the glyph texture
var glyph_cache_keyboard_mouse := {}
var glyph_cache_controller := {}

## This signal is listened to by UI elements so they can call `get_button_glyph` to display the correct button
signal OnInputDeviceChanged()
var _last_device_change_time := 0

var is_using_controller := false:
    get:
        return is_using_controller
    set(value):
        if Time.get_ticks_msec() - _last_device_change_time < 250:
            # print("[Input] Device changed too quickly, ignoring")
            return
        # if the device has changed, update the controller layout
        if last_input_event:
            if player1_device != last_input_event.device:
                player1_device = last_input_event.device
                _update_controller_layout()
            # only emit signal if the value has changed
            elif value == is_using_controller:
                return

        is_using_controller = value
        _last_device_change_time = Time.get_ticks_msec()
        OnInputDeviceChanged.emit()


func _ready() -> void:
    Console.pause_enabled = true
    _update_controller_layout()
    if Input.get_connected_joypads().size() > 0:
        is_using_controller = true

## Gets the embed for the button glyph texture for the current input device based on the action name
func get_button_glyph_img_embed(action: String, size: int = 48, horizontal_decoration: bool = false, vertical_decoration: bool = false) -> String:
    var glyph_path := get_button_glyph(action)
    if glyph_path == "NONE":
        return "[color=red]NO GLYPH FOUND[/color]"
    return "[img=%s]%s[/img]" % [str(size), get_button_glyph(action, horizontal_decoration, vertical_decoration)]

## Gets multiple embeds for the button glyph texture for the current input device based on the action name
func get_button_glyph_img_embeds(action: String, size: int = 48, horizontal_decoration: bool = false, vertical_decoration: bool = false) -> String:
    var glyph_paths := get_button_glyphs(action, horizontal_decoration, vertical_decoration)
    if glyph_paths.is_empty():
        return "[color=red]NO GLYPH FOUND[/color]"

    var result := ""
    for glyph_path in glyph_paths:
        result += "[img=%s]%s[/img] " % [str(size), glyph_path]
    return result.strip_edges()

## Gets a single embed for the button glyph texture by its file name (not the input action)
func get_button_glyph_img_embed_by_name(path: String, size: int = 48) -> String:
    return "[img=%s]%s[/img]" % [str(size), get_button_glyph_by_name(path)]

## Return the full path to the button glyph texture, e.g.
## "keyboard_mouse/mouse_scroll_vertical" -> "res://Assets/GUI/Icons/ControllerGlyphs/keyboard_mouse/mouse_scroll_vertical"
func get_button_glyph_by_name(path: String) -> String:
    return PATH + path + EXTENSION

func get_layout_prefix(layout: ControllerLayout) -> String:
    match layout:
        ControllerLayout.XBOX:
            return "xbox/"
        ControllerLayout.PS4,\
        ControllerLayout.PS5:
            return "playstation/"
        ControllerLayout.NINTENDO_PRO,\
        ControllerLayout.NINTENDO_JOYCON:
            return "switch/"
        _:
            return "xbox/"

## Returns the path to the first button glyph texture for the current input device based on the action name[br]
## [param action_name] Needs to be the name of an action in the InputMap
func get_button_glyph(action_name: String, horizontal_decoration: bool = false, vertical_decoration: bool = false) -> String:
    var all := get_button_glyphs(action_name, horizontal_decoration, vertical_decoration)
    if all.is_empty():
        return "NONE"
    return all.front()

## Returns an array of button glyph texture paths for the current input device based on the action name[br]
## [param action_name] Needs to be the name of an action in the InputMap
func get_button_glyphs(action_name: String, horizontal_decoration: bool = false, vertical_decoration: bool = false) -> Array[String]:
    var action_cache_key := "%s|%s|%s" % [action_name, horizontal_decoration, vertical_decoration]

    if is_using_controller:
        if action_cache_key in glyph_cache_controller:
            return glyph_cache_controller.get(action_cache_key)
    else:
        if action_cache_key in glyph_cache_keyboard_mouse:
            return glyph_cache_keyboard_mouse.get(action_cache_key)


    var events := InputMap.action_get_events(action_name)
    var to_return: Array[String] = []

    for event in events:
        # ==============================================================================
        # GAMEPAD
        # ==============================================================================
        if is_using_controller:
            var controller_prefix := get_layout_prefix(current_controller_layout)
            
            if event is InputEventJoypadButton:
                
                if event.as_text().contains("D-pad"):
                    var dpad_direction := event.as_text().split("(")[1].split(" ")[1]
                    # cut off ending bracket
                    dpad_direction = dpad_direction.left(dpad_direction.length() - 1)
                    if vertical_decoration and horizontal_decoration:
                        dpad_direction = "all"
                    elif vertical_decoration:
                        dpad_direction = "vertical"
                    elif horizontal_decoration:
                        dpad_direction = "horizontal"
                    
                    to_return.append(PATH + controller_prefix + "dpad_" + dpad_direction.to_lower() + EXTENSION)
                    glyph_cache_controller.get_or_add(action_cache_key, to_return)
                    continue

                match event.button_index:
                    8:
                        to_return.append(PATH + "stick/stick_r_press" + EXTENSION)
                    7:
                        to_return.append(PATH + "stick/stick_l_press" + EXTENSION)
                    _:
                        var button_name: String = "BUTTON_" + str(event.button_index)
                        to_return.append(PATH + controller_prefix + button_name + EXTENSION)
                
                glyph_cache_controller.get_or_add(action_cache_key, to_return)

            elif event is InputEventJoypadMotion:
                var joystick_path := PATH

                # Stick output: ["Left", "Stick", "Y-Axis,", "Joystick", "0", "Y-Axis)", "with", "Value", "-1.00"]
                # Trigger output: ["Joystick", "2", "Y-Axis,", "Right", "Trigger,", "Sony", "R2,", "Xbox", "RT)", "with", "Value", "1.00"]
                var split_info := event.as_text().split("(")[1].split(" ")
                var axis_value := split_info[split_info.size() - 1].to_float()
                
                # print("Split info: " + str(split_info))
                # print("Axis direction: " + str(axis_value))

                if split_info[1] == "Stick":
                    # sticks don't have a controller-specific prefix, since they look the same
                    # the "stick" folder has both left and right stick glyphs
                    if split_info[0] == "Left":
                        joystick_path += "stick/stick_l"
                    else:
                        joystick_path += "stick/stick_r"

                    # FIX: only apply decoration to the stick and not triggers
                    if vertical_decoration and horizontal_decoration:
                        pass # don't add any suffix 
                    elif vertical_decoration:
                        joystick_path += "_vertical"
                    elif horizontal_decoration:
                        joystick_path += "_horizontal"
                    else:
                        if split_info[2].begins_with("X"):
                            if axis_value < 0:
                                joystick_path += "_left"
                            elif axis_value > 0:
                                joystick_path += "_right"
                        elif split_info[2].begins_with("Y"):  
                            if axis_value < 0:
                                joystick_path += "_up"
                            elif axis_value > 0:
                                joystick_path += "_down"

                else:
                    # triggers have a controller-specific prefix
                    if split_info.has("Right"):
                        joystick_path += controller_prefix + "right_trigger"
                    else:
                        joystick_path += controller_prefix + "left_trigger"

                

                to_return.append(joystick_path + EXTENSION)
                glyph_cache_controller.get_or_add(action_cache_key, to_return)

        # ==============================================================================
        # KEYBOARD AND MOUSE
        # ==============================================================================
        else:
            if event is InputEventKey:
                var keyboard_prefix := "keyboard_mouse/keyboard_"
                var key_name := event.as_text().split(" ")[0].to_lower()

                if (key_name == "down" or key_name == "up") and vertical_decoration:
                    key_name = ("arrows_all" if horizontal_decoration else "arrows_vertical")
                elif (key_name == "left" or key_name == "right") and horizontal_decoration:
                    key_name = ("arrows_all" if vertical_decoration else "arrows_horizontal")
            
                to_return.append(PATH + keyboard_prefix + key_name + EXTENSION)
                glyph_cache_keyboard_mouse.get_or_add(action_cache_key, to_return)

            elif event is InputEventMouseButton:
                var mouse_split := event.as_text().split(" ")
                if mouse_split.has("Wheel"):
                    to_return.append(PATH + "keyboard_mouse/mouse_scroll_" + mouse_split[2].to_lower() + EXTENSION)
                elif mouse_split.has("Thumb"):
                    # the sprite pack doesn't have mouse4/mouse5, so we use a normal mouse image
                    to_return.append(PATH + "keyboard_mouse/mouse" + EXTENSION)
                else:
                    to_return.append(PATH + "keyboard_mouse/mouse_" + mouse_split[0].to_lower() + EXTENSION)
                
                glyph_cache_keyboard_mouse.get_or_add(action_cache_key, to_return)

    return to_return

func _update_controller_layout() -> void:
    var player1_name := Input.get_joy_name(player1_device)

    if player1_name.is_empty():
        print("No controller detected")
        is_using_controller = false
        return
    print("Joy info: " + player1_name)

    if (Util.string_contains_any(player1_name, ["Xbox", "XInput", "Steam"])): # steam controller and deck are xbox layout
        current_controller_layout = ControllerLayout.XBOX
    # Use the ps4 controller layout for older playstation controllers
    elif (Util.string_contains_any(player1_name,
    ["DualShock", "PlayStation", "PS1", "PS2", "PS3", "PS4"])):
        current_controller_layout = ControllerLayout.PS4
    elif player1_name.contains("PS5"):
        current_controller_layout = ControllerLayout.PS5
    elif player1_name.contains("Nintendo"):
        if player1_name.contains("Pro"):
            # wii u or switch pro controller
            current_controller_layout = ControllerLayout.NINTENDO_PRO
        else:
            # assume joy-cons; other nintendo controllers are not supported
            # joy-cons don't use different glyphs for now
            current_controller_layout = ControllerLayout.NINTENDO_JOYCON

func _check_event_repeated(event: InputEvent) -> bool:
    if not last_input_event:
        return false

    var last_event_text := last_input_event.as_text().split(" ")
    var current_event_text := event.as_text().split(" ")

    if last_event_text.slice(0, 4) == current_event_text.slice(0, 4):
        return true
        
    return false

func _input(event: InputEvent) -> void:
    var checked_joystick := false

    ## Joystick is checked first because the event is fired for every small movement
    ## If we checked for repeated events beforehand, we would not be able to detect the
    ## player moving the stick further than the initial deadzone
    if event is InputEventJoypadMotion:
        # deadzone to avoid drift detecting as input
        if abs(event.axis_value) > JOYSTICK_DEADZONE:
            last_input_event = event
            is_using_controller = true
            checked_joystick = true

    if _check_event_repeated(event) and not checked_joystick:
        return
    last_input_event = event

    if not checked_joystick:
        if (event is InputEventJoypadButton
        and event.is_pressed()):
            is_using_controller = true
            return

        if ((event is InputEventKey
        or event is InputEventMouseButton)
        and event.is_pressed()):
            is_using_controller = false