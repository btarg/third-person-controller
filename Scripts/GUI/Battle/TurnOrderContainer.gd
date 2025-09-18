extends VBoxContainer
class_name TurnOrderContainer

var turn_order_entry := preload("res://Assets/GUI/Battle/turn_order_entry.tscn") as PackedScene

@onready var battle_state := GameModeStateMachine.get_node("BattleState") as BattleState

var entries: Array[ClickableControl] = []

var character_by_entry: Dictionary[ClickableControl, BattleCharacter] = {}

const max_size := 5

# Animation constants
const SELECTION_OFFSET := Vector2(-20.0, 0.0)  # How far to move selected item
const SELECTION_SCALE := 1.05  # Slight scale increase for selected item
const ANIMATION_DURATION := 0.2  # Animation duration in seconds

var current_index := 0
var _last_selected_entry: ClickableControl
var _last_selected_character: BattleCharacter
var _selection_tween: Tween  # Tween for animating selection

var is_player_turn: bool = false:
    get:
        return (battle_state.current_character 
        and battle_state.current_character.character_type in [BattleEnums.ECharacterType.PLAYER,
        BattleEnums.ECharacterType.FRIENDLY])
    set(value):
        is_player_turn = value

var input_allowed: bool = false

func _ready() -> void:
    BattleSignalBus.OnCharacterJoinedBattle.connect(add_entry)
    BattleSignalBus.OnRevive.connect(add_entry)
    BattleSignalBus.OnCharacterSelected.connect(_on_character_selected)
    BattleSignalBus.OnBattleEnded.connect(clear_entries)
    BattleSignalBus.OnDeath.connect(remove_entry)
    BattleSignalBus.OnTurnStarted.connect(_on_turn_started)
    BattleSignalBus.OnBattleStarted.connect(_on_battle_started)
    BattleSignalBus.OnActionsUpdated.connect(_on_actions_updated)
    Console.add_command("print_turn_order_ui", _print_turn_order_ui)
    hide()

func _on_actions_updated(character: BattleCharacter, actions_left: int) -> void:
    # When actions are updated, update the display more efficiently
    if not visible or not battle_state or not battle_state.is_in_battle:
        return
    
    # Debug: Print when actions are updated
    print("[TURN ORDER UI] Actions updated for %s: %d actions left" % [character.character_name, actions_left])
    
    # If the updated character is the current character (should be at index 0), update just that entry
    if character == battle_state.current_character and entries.size() > 0:
        _update_current_character_display(character, actions_left)
    else:
        # If it's a different character (rare case), do a full rebuild
        _rebuild_turn_order_ui()

func _update_current_character_display(character: BattleCharacter, actions_left: int) -> void:
    if entries.is_empty():
        return
    
    # The current character is always at index 0 in our dynamic display
    var current_entry := entries[0]
    var entry_character := character_by_entry.get(current_entry) as BattleCharacter
    
    if entry_character != character:
        # Something is out of sync, do a full rebuild
        _rebuild_turn_order_ui()
        return
    
    # Update the text for the current character entry efficiently
    # We'll trigger a full visual update to maintain consistency with selection indicators
    if _last_selected_entry and character_by_entry.has(_last_selected_entry):
        _update_visual_selection(_last_selected_entry, character_by_entry[_last_selected_entry])
    else:
        # No character selected, just update the current character text
        var display_text := character.character_name
        var actions_text := " (%d)" % actions_left if actions_left > 0 else " (Done)"
        display_text = "★ " + display_text + actions_text
        current_entry.get_node("Label").text = display_text

func _print_turn_order_ui() -> void:
    if entries.is_empty():
        Console.print_line("Turn order UI is empty", true)
        return
    
    Console.print_line("Dynamic Turn Order UI (current character at top):", true)
    for i in range(entries.size()):
        var entry := entries[i]
        var character := character_by_entry.get(entry) as BattleCharacter
        if character:
            var status := "(Current - %d actions)" % character.actions_left if i == 0 else "(Up in %d turns)" % i
            Console.print_line("%d. %s %s (Initiative: %d)" % [i + 1, character.character_name, status, character.initiative], true)
        else:
            Console.print_line("%d. [Unknown character]" % [i + 1], true)
    
    # Also show current battle state info
    if battle_state and battle_state.current_character:
        Console.print_line("Battle State - Current: %s (%d actions)" % [battle_state.current_character.character_name, battle_state.current_character.actions_left], true)

func _on_turn_started(_character: BattleCharacter) -> void:
    # Rebuild the turn order UI to show the new current character at the top
    _rebuild_turn_order_ui()

func _on_battle_started() -> void:
    # Build the turn order UI showing current character at top
    _rebuild_turn_order_ui()
    show()

func _rebuild_turn_order_ui() -> void:
    if not battle_state or not battle_state.turn_order:
        return
    
    # Disconnect OnLeaveBattle signals before clearing entries
    for entry in entries:
        var character := character_by_entry.get(entry) as BattleCharacter
        if character and character.OnLeaveBattle.is_connected(remove_entry):
            character.OnLeaveBattle.disconnect(remove_entry)
    
    # Clear all existing UI entries
    for entry in entries:
        entry.queue_free()
    entries.clear()
    character_by_entry.clear()
    
    # Build the display order: current character at top, then upcoming characters
    var display_order := _get_dynamic_turn_order()
    
    # Create entries in display order
    for character in display_order:
        if entries.size() >= max_size:
            break
        _create_entry_for_character(character)
    
    # Select the first character (current active character) if we have any entries
    if entries.size() > 0:
        _select_character_at_index(0, false)

func _get_dynamic_turn_order() -> Array[BattleCharacter]:
    var display_order: Array[BattleCharacter] = []
    
    if not battle_state.current_character:
        return display_order
    
    # Start with current character at the top
    display_order.append(battle_state.current_character)
    
    # Add remaining characters in turn order, wrapping around if necessary
    var battle_current_index := battle_state.current_character_index
    var turn_order := battle_state.turn_order
    
    # Add characters after current character
    for i in range(battle_current_index + 1, turn_order.size()):
        if display_order.size() >= max_size:
            break
        display_order.append(turn_order[i])
    
    # Wrap around to beginning if we still have room and characters
    if display_order.size() < max_size:
        for i in range(0, battle_current_index):
            if display_order.size() >= max_size:
                break
            display_order.append(turn_order[i])
    
    return display_order

func _create_entry_for_character(entry_character: BattleCharacter) -> void:
    # Only connect the signal if it's not already connected
    if not entry_character.OnLeaveBattle.is_connected(remove_entry):
        entry_character.OnLeaveBattle.connect(remove_entry.bind(entry_character))
    
    var entry_instance := turn_order_entry.instantiate() as ClickableControl
    
    entries.append(entry_instance)
    character_by_entry[entry_instance] = entry_character
    add_child(entry_instance)
    
    entry_instance.OnClicked.connect(_select_character_at_index.bind(entries.size() - 1, true))
    entry_instance.get_node("Label").text = entry_character.character_name

func _on_character_selected(character: BattleCharacter) -> void:
    for entry in entries:
        if character_by_entry.get(entry) == character:
            _select_character_at_index(entries.find(entry), false)
            break

func _input(event: InputEvent) -> void:
    if entries.is_empty() or not visible or not is_player_turn or not input_allowed:
        return

    if event.is_action_pressed("arrow_up"):
        current_index = (current_index - 1) if current_index > 0 else entries.size() - 1
        _select_character_at_index(current_index, true)
        get_viewport().set_input_as_handled()
    elif event.is_action_pressed("arrow_down"):  
        current_index = (current_index + 1) % entries.size()
        _select_character_at_index(current_index, true)
        get_viewport().set_input_as_handled()


func _select_character_at_index(index: int, focus_camera: bool = false) -> void:
    if index < 0 or index >= entries.size():
        return
        
    var entry := entries[index]
    var character := character_by_entry.get(entry) as BattleCharacter
    if not character:
        return
    
    # Update visual indicators
    _update_visual_selection(entry, character)
    
    # Select character and optionally focus camera
    battle_state.select_character(character, focus_camera)
    
    _last_selected_entry = entry
    _last_selected_character = character

func _update_visual_selection(selected_entry: Control, _selected_character: BattleCharacter) -> void:
    # Stop any existing animation
    if _selection_tween:
        _selection_tween.kill()
    
    _selection_tween = create_tween()
    _selection_tween.set_parallel(true)  # Allow multiple animations to run in parallel
    
    # Animate all entries
    for i in range(entries.size()):
        var entry := entries[i]
        var character := character_by_entry.get(entry) as BattleCharacter
        if character:
            var is_selected := entry == selected_entry
            var is_current_turn := i == 0  # First entry is always the current character
            
            # Build the display text with appropriate indicators
            var display_text := character.character_name
            if is_current_turn:
                # Show actions left for current character
                var actions_text := " (%d)" % character.actions_left if character.actions_left > 0 else " (Done)"
                display_text = "★ " + display_text + actions_text  # Star for current turn
            if is_selected:
                display_text = "► " + display_text  # Arrow for selected
            
            entry.get_node("Label").text = display_text
            
            # Apply visual effects
            if is_selected:
                # Selected entry: move out and scale up
                _selection_tween.tween_property(entry, "position:x", SELECTION_OFFSET.x, ANIMATION_DURATION).set_ease(Tween.EASE_OUT)
                _selection_tween.tween_property(entry, "scale", Vector2.ONE * SELECTION_SCALE, ANIMATION_DURATION).set_ease(Tween.EASE_OUT)
            else:
                # Non-selected entry: return to original position and scale
                _selection_tween.tween_property(entry, "position:x", 0.0, ANIMATION_DURATION).set_ease(Tween.EASE_OUT)
                _selection_tween.tween_property(entry, "scale", Vector2.ONE, ANIMATION_DURATION).set_ease(Tween.EASE_OUT)

func add_entry(_entry_character: BattleCharacter) -> void:
    # For dynamic turn order, we rebuild the entire UI when characters are added
    # This ensures the new character appears in the correct position relative to current turn
    if not battle_state or not battle_state.is_in_battle:
        return
    
    # Simply rebuild the entire turn order UI to accommodate the new character
    _rebuild_turn_order_ui()

func clear_entries() -> void:
    # Stop any running animations
    if _selection_tween:
        _selection_tween.kill()
    
    # Disconnect OnLeaveBattle signals before clearing entries
    for entry in entries:
        var character := character_by_entry.get(entry) as BattleCharacter
        if character and character.OnLeaveBattle.is_connected(remove_entry):
            character.OnLeaveBattle.disconnect(remove_entry)
        entry.queue_free()
    
    entries.clear()
    character_by_entry.clear()
    current_index = 0
    input_allowed = false
    hide()  # Hide when clearing entries (battle ended)


func remove_entry(_entry_character: BattleCharacter) -> void:
    # For dynamic turn order, we rebuild the entire UI when characters are removed
    # This ensures the display reflects the current turn order state
    if not battle_state or not battle_state.is_in_battle:
        return
    
    # Simply rebuild the entire turn order UI
    _rebuild_turn_order_ui()
