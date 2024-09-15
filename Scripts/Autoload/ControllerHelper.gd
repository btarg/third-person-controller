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
    Console.add_command("test_action", _set_test_action, 1)

    _update_controller_layout()
    OnInputDeviceChanged.connect(_test_glyph)

func _set_test_action(action: String) -> void:
    Console.print_line("Setting test action to: " + action)
    test_action = action

func _test_glyph() -> void:
    var debug_glyph := get_button_glyph(test_action)
    Console.print_line("Debug glyph %s: %s" % [test_action, debug_glyph], true)

## Returns the path to the button glyph texture for the current input device based on the action name
func get_button_glyph(action_name: String) -> String:
    var events := InputMap.action_get_events(action_name)

    for event in events:
        if is_using_controller:
            if event is InputEventJoypadButton:
                var button_name := "_BUTTON_" + event.as_text().split(" ")[2]
                return Util.get_enum_name(ControllerLayout, current_controller_layout) + button_name
            elif event is InputEventJoypadMotion:
                var joystick_text := Util.get_enum_name(ControllerLayout, current_controller_layout) + "_"

                # Stick output: ["Left", "Stick", "Y-Axis,", "Joystick", "0", "Y-Axis)", "with", "Value", "-1.00"]
                # Trigger output: ["Joystick", "2", "Y-Axis,", "Right", "Trigger,", "Sony", "R2,", "Xbox", "RT)", "with", "Value", "1.00"]
                var split_info := event.as_text().split("(")[1].split(" ")
                var axis_value := split_info[split_info.size() - 1].to_float()
                
                print("Split info: " + str(split_info))
                print("Axis direction: " + str(axis_value))

                if split_info[1] == "Stick":
                    if split_info[0] == "Left":
                        joystick_text += "LEFT_STICK"
                    else:
                        joystick_text += "RIGHT_STICK"
                else:
                    if split_info.has("Right"):
                        joystick_text += "RIGHT_TRIGGER"
                    else:
                        joystick_text += "LEFT_TRIGGER"

                if axis_value < 0:
                    joystick_text += "_UP"
                elif axis_value > 0:
                    joystick_text += "_DOWN"

                return joystick_text

        
        elif event is InputEventKey:
            return "KEYBOARD_" + event.as_text().split(" ")[0]
        elif event is InputEventMouseButton:
            var mouse_split := event.as_text().split(" ")
            if mouse_split.has("Wheel"):
                return "MOUSE_WHEEL_" + mouse_split[2].to_upper()
            else:
                return "MOUSE_" + mouse_split[0].to_upper()
        print(event.as_text())

    return "NONE"

func _update_controller_layout() -> void:
    var player1_name := Input.get_joy_name(player1_device)

    if player1_name.is_empty():
        print("No controller detected")
        is_using_controller = false
        return
    print("Joy info: " + player1_name)

    if (player1_name.contains("Xbox")
    or player1_name.contains("XInput")
    or player1_name.contains("Steam")): # steam controller and deck are xbox layout
        current_controller_layout = ControllerLayout.XBOX
    # Use the ps4 controller layout for older playstation controllers
    elif (player1_name.contains("PS4")
    or player1_name.contains("PS3")
    or player1_name.contains("PS2")
    or player1_name.contains("PS1")
    or player1_name.contains("DualShock")
    or player1_name.contains("PlayStation")):
        current_controller_layout = ControllerLayout.PS4
    elif player1_name.contains("PS5"):
        current_controller_layout = ControllerLayout.PS5
    elif player1_name.contains("Nintendo"):
        if player1_name.contains("Pro"):
            # wii u or switch pro controller
            current_controller_layout = ControllerLayout.NINTENDO_PRO
        else:
            # assume joy-cons - other nintendo controllers are not supported
            # joy-cons use different glyphs
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
        or event is InputEventMouseButton) and event.is_pressed()
        or event is InputEventMouseMotion):
            is_using_controller = false