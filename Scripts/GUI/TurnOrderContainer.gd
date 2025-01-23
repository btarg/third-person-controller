extends HBoxContainer
class_name TurnOrderContainer

var turn_order_entry := preload("res://Assets/GUI/Battle/turn_order_entry.tscn") as PackedScene

@onready var battle_state := get_node("/root/GameModeStateMachine/BattleState") as BattleState

var entries: Array[ClickableControl] = []

## Key: BattleCharacter, value: TurnOrderEntry instance
var character_by_entry: Dictionary = {}

const max_size := 5

var _last_selected_entry: ClickableControl

func _ready() -> void:
    BattleSignalBus.OnCharacterJoinedBattle.connect(add_entry)
    BattleSignalBus.OnRevive.connect(add_entry)
    BattleSignalBus.OnCharacterSelected.connect(_on_character_selected)
    BattleSignalBus.OnBattleEnded.connect(clear_entries)
    BattleSignalBus.OnDeath.connect(remove_entry)

func focus_last_selected() -> void:
    if entries.size() <= 0 or not _last_selected_entry:
        return
    if (battle_state.player_selected_character == null
    or not character_by_entry.get(_last_selected_entry)):
        entries[0].grab_focus()
        return

    _last_selected_entry.grab_focus()


func _on_character_selected(character: BattleCharacter) -> void:
    for entry in entries:
        if character_by_entry.get(entry) == character:
            _handle_character_selection(entry, false)
            break

func clear_entries() -> void:
    for entry in entries:
        entry.queue_free()
    entries.clear()
    character_by_entry.clear()

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

func add_entry(entry_character: BattleCharacter) -> void:
    if entries.size() >= max_size:
        print("Max size reached")
        return

    # Remove when leaving
    entry_character.OnLeaveBattle.connect(remove_entry)

    var entry_instance := turn_order_entry.instantiate() as ClickableControl

    entries.append(entry_instance)
    character_by_entry[entry_instance] = entry_character

    add_child(entry_instance)
    
    entry_instance.OnClicked.connect(_handle_character_selection.bind(entry_instance, true))
    entry_instance.focus_entered.connect(_handle_character_selection.bind(entry_instance, false))

    entry_instance.get_node("Label").text = entry_character.character_name


    if entries.size() == 1:
        entry_instance.grab_focus()

    if entries.size() > 1:
        var previous := entries[entries.size()-2].get_path()
        entry_instance.focus_neighbor_top = previous
        entry_instance.focus_neighbor_left = previous

        for i in range(0, entries.size()):
            var next := entries[(i + 1) % entries.size()].get_path()
            entries[i].focus_neighbor_bottom = next
            entries[i].focus_neighbor_right = next

        var last_item := entries[entries.size()-1].get_path()
        entries[0].focus_neighbor_top = last_item
        entries[0].focus_neighbor_left = last_item


func _handle_character_selection(entry: Control, focus_character: bool = false) -> void:
    var character: BattleCharacter
    for b in entries:
        character = character_by_entry.get(b) as BattleCharacter
        if b != entry:
            b.release_focus()
            b.get_node("Label").text = character.character_name

    character = character_by_entry.get(entry) as BattleCharacter    
    entry.get_node("Label").text = "*" + character.character_name

    battle_state.select_character(character, focus_character)
    entry.grab_focus()
    _last_selected_entry = entry