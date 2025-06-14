extends HBoxContainer
class_name TurnOrderContainer

var turn_order_entry := preload("res://Assets/GUI/Battle/turn_order_entry.tscn") as PackedScene

@onready var battle_state := GameModeStateMachine.get_node("BattleState") as BattleState

var entries: Array[ClickableControl] = []

var character_by_entry: Dictionary[ClickableControl, BattleCharacter] = {}

const max_size := 5

var current_index := 0
var _last_selected_entry: ClickableControl
var _last_selected_character: BattleCharacter

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
    BattleSignalBus.OnBattleStarted.connect(show)
    hide()

func _on_turn_started(_character: BattleCharacter) -> void:
    # Turn order UI stays visible throughout battle
    # Input allowance is controlled by individual states
    pass

func _on_character_selected(character: BattleCharacter) -> void:
    for entry in entries:
        if character_by_entry.get(entry) == character:
            _select_character_at_index(entries.find(entry), false)
            break

func _input(event: InputEvent) -> void:
    if entries.is_empty() or not visible or not is_player_turn or not input_allowed:
        return

    if event.is_action_pressed("arrow_left"):
        current_index = (current_index - 1) if current_index > 0 else entries.size() - 1
        _select_character_at_index(current_index, true)
        get_viewport().set_input_as_handled()
    elif event.is_action_pressed("arrow_right"):  
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

func _update_visual_selection(selected_entry: Control, selected_character: BattleCharacter) -> void:
    # Clear all selection indicators
    for entry in entries:
        var character := character_by_entry.get(entry) as BattleCharacter
        if character:
            entry.get_node("Label").text = character.character_name
    
    # Show selection indicator for current entry
    selected_entry.get_node("Label").text = "*" + selected_character.character_name

func add_entry(entry_character: BattleCharacter) -> void:
    if entries.size() >= max_size:
        return

    entry_character.OnLeaveBattle.connect(remove_entry.bind(entry_character))
    var entry_instance := turn_order_entry.instantiate() as ClickableControl
    
    entries.append(entry_instance)
    character_by_entry[entry_instance] = entry_character
    add_child(entry_instance)
    
    entry_instance.OnClicked.connect(_select_character_at_index.bind(entries.size() - 1, true))
    entry_instance.get_node("Label").text = entry_character.character_name

    if entries.size() == 1:
        _select_character_at_index(0, false)

func clear_entries() -> void:
    for entry in entries:
        entry.queue_free()
    entries.clear()
    character_by_entry.clear()
    current_index = 0
    input_allowed = false
    hide()  # Hide when clearing entries (battle ended)


func remove_entry(entry_character: BattleCharacter) -> void:
    var entries_to_remove: Array[ClickableControl] = []
    for entry in entries:
        if character_by_entry.get(entry) == entry_character:
            entries_to_remove.append(entry)
            entry.OnClicked.disconnect(_select_character_at_index.bind(entries.find(entry), true))
    
    for entry in entries_to_remove:
        entry.queue_free()
        entries.erase(entry)
        character_by_entry.erase(entry)

        if _last_selected_entry == entry:
            _last_selected_entry = null
