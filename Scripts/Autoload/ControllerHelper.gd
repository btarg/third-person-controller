extends Node

enum ControllerLayout {
    XBOX,
    PS5,
    PS4,
    NINTENDO_PRO,
    NINTENDO_JOYCON
}

const JOYSTICK_DEADZONE := 0.25

var current_controller_layout := ControllerLayout.XBOX
var player1_device := 0

var last_input_event: InputEvent = null

var test_action := "move_right"

## This signal is listened to by UI elements so they can call `get_button_glyph` to display the correct button
signal OnInputDeviceChanged()

@export var is_using_controller := false:
    get:
        return is_using_controller
    set(value):
        # if the device has changed, update the controller layout
        if last_input_event:
            if player1_device != last_input_event.device:
                player1_device = last_input_event.device
                _update_controller_layout()
            # only emit signal if the value has changed
            elif value == is_using_controller:
                return

        is_using_controller = value
        OnInputDeviceChanged.emit()

func _ready() -> void:
    Console.pause_enabled = true
    _update_controller_layout()
    if Input.get_connected_joypads().size() > 0:
        is_using_controller = true

## Returns the path to the button glyph texture for the current input device based on the action name
func get_button_glyph(action_name: String, horizontal_decoration: bool = false, vertical_decoration: bool = false) -> String:
    var events := InputMap.action_get_events(action_name)
    var path := "res://Assets/GUI/Icons/ControllerGlyphs/"
    var extension := ".svg"

    for event in events:
        if is_using_controller:
            var controller_prefix := ""
            match current_controller_layout:
                ControllerLayout.XBOX:
                    controller_prefix = "xbox/"
                ControllerLayout.PS4,\
                ControllerLayout.PS5:
                    controller_prefix = "playstation/"
                ControllerLayout.NINTENDO_PRO,\
                ControllerLayout.NINTENDO_JOYCON:
                    controller_prefix = "switch/"

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
                    
                    return path + controller_prefix + "dpad_" + dpad_direction.to_lower() + extension

                match event.button_index:
                    8:
                        return path + "stick/stick_r_press" + extension
                    7:
                        return path + "stick/stick_l_press" + extension
                    _:
                        var button_name: String = "BUTTON_" + str(event.button_index)
                        return path + controller_prefix + button_name + extension

            elif event is InputEventJoypadMotion:
                var joystick_path := path

                # Stick output: ["Left", "Stick", "Y-Axis,", "Joystick", "0", "Y-Axis)", "with", "Value", "-1.00"]
                # Trigger output: ["Joystick", "2", "Y-Axis,", "Right", "Trigger,", "Sony", "R2,", "Xbox", "RT)", "with", "Value", "1.00"]
                var split_info := event.as_text().split("(")[1].split(" ")
                var axis_value := split_info[split_info.size() - 1].to_float()
                
                print("Split info: " + str(split_info))
                print("Axis direction: " + str(axis_value))

                if split_info[1] == "Stick":
                    # sticks don't have a controller-specific prefix, since they look the same
                    # the "stick" folder has both left and right stick glyphs
                    if split_info[0] == "Left":
                        joystick_path += "stick/stick_l"
                    else:
                        joystick_path += "stick/stick_r"
                else:
                    # triggers have a controller-specific prefix
                    if split_info.has("Right"):
                        joystick_path += controller_prefix + "right_trigger"
                    else:
                        joystick_path += controller_prefix + "left_trigger"

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

                return joystick_path + extension
        
        elif event is InputEventKey:
            var keyboard_prefix := "keyboard_mouse/keyboard_"
            var key_name := event.as_text().split(" ")[0].to_lower()

            if (key_name == "down" or key_name == "up") and vertical_decoration:
                key_name = ("arrows_all" if horizontal_decoration else "arrows_vertical")
            elif (key_name == "left" or key_name == "right") and horizontal_decoration:
                key_name = ("arrows_all" if vertical_decoration else "arrows_horizontal")
        
            return path + keyboard_prefix + key_name + extension

        elif event is InputEventMouseButton:
            var mouse_split := event.as_text().split(" ")
            if mouse_split.has("Wheel"):
                return path + "keyboard_mouse/mouse_scroll_" + mouse_split[2].to_lower() + extension
            elif mouse_split.has("Thumb"):
                # the sprite pack doesn't have mouse4/mouse5, so we use a normal mouse image
                return path + "keyboard_mouse/mouse" + extension
            else:
                return path + "keyboard_mouse/mouse_" + mouse_split[0].to_lower() + extension

    return "NONE"

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