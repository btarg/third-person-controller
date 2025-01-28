extends HBoxContainer
class_name TurnOrderContainer

var turn_order_entry := preload("res://Assets/GUI/Battle/turn_order_entry.tscn") as PackedScene

@onready var battle_state := get_node("/root/GameModeStateMachine/BattleState") as BattleState

var entries: Array[ClickableControl] = []

## Key: BattleCharacter, value: TurnOrderEntry instance
var character_by_entry: Dictionary = {}

const max_size := 5

var current_index := 0
var _last_selected_entry: ClickableControl

var is_ui_active : bool = false:
    get:
        return is_ui_active
    set(value):
        is_ui_active = value
        if is_ui_active:
            print("UI is active")
            focus_last_selected()
            show()
        else:
            hide()
            print("UI is not active")

func _ready() -> void:
    BattleSignalBus.OnCharacterJoinedBattle.connect(add_entry)
    BattleSignalBus.OnRevive.connect(add_entry)
    BattleSignalBus.OnCharacterSelected.connect(_on_character_selected)
    BattleSignalBus.OnBattleEnded.connect(clear_entries)
    BattleSignalBus.OnDeath.connect(remove_entry)
    hide()

func _on_character_selected(character: BattleCharacter) -> void:
    for entry in entries:
        if character_by_entry.get(entry) == character:
            _handle_character_selection(entry)
            break


func _unhandled_input(event: InputEvent) -> void:
    if entries.is_empty():
        return

    if event.is_action_pressed("ui_focus_next"):
        is_ui_active = !is_ui_active
    
    if not is_ui_active:
        return

    if event.is_action_pressed("ui_left"):
        current_index = (current_index - 1) if current_index > 0 else entries.size() - 1
        _handle_character_selection(entries[current_index])
    elif event.is_action_pressed("ui_right"):  
        current_index = (current_index + 1) % entries.size()
        _handle_character_selection(entries[current_index])


func focus_last_selected() -> void:
    if entries.size() <= 0:
        return
    _handle_character_selection(entries[current_index])

func _handle_character_selection(entry: Control, focus_character: bool = false) -> void:
    if not is_ui_active:
        return

    var character: BattleCharacter
    for b in entries:
        character = character_by_entry.get(b) as BattleCharacter
        if b != entry:
            b.get_node("Label").text = character.character_name

    character = character_by_entry.get(entry) as BattleCharacter
    if not character:
        return

    entry.get_node("Label").text = "*" + character.character_name
    
    battle_state.select_character(character, focus_character)
    _last_selected_entry = entry
    current_index = entries.find(entry)

func add_entry(entry_character: BattleCharacter) -> void:
    if entries.size() >= max_size:
        print("Max size reached")
        return

    entry_character.OnLeaveBattle.connect(remove_entry.bind(entry_character))
    var entry_instance := turn_order_entry.instantiate() as ClickableControl
    
    entries.append(entry_instance)
    character_by_entry[entry_instance] = entry_character
    add_child(entry_instance)
    
    entry_instance.OnClicked.connect(_handle_character_selection.bind(entry_instance, true))
    entry_instance.get_node("Label").text = entry_character.character_name

    if entries.size() == 1:
        _handle_character_selection(entry_instance, false)

func clear_entries() -> void:
    for entry in entries:
        entry.queue_free()
    entries.clear()
    character_by_entry.clear()
    current_index = 0


func remove_entry(entry_character: BattleCharacter) -> void:
    var entries_to_remove: Array[ClickableControl] = []
    for entry in entries:
        if character_by_entry.get(entry) == entry_character:
            entries_to_remove.append(entry)
            entry.OnClicked.disconnect(_handle_character_selection.bind(entry, true))
    
    for entry in entries_to_remove:
        entry.queue_free()
        entries.erase(entry)
        character_by_entry.erase(entry)

        if _last_selected_entry == entry:
            _last_selected_entry = null
