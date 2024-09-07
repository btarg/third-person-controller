extends State
class_name BattleState

signal EndedBattle
var turn_order: Array[BattleCharacter] = []

# get player from group
@onready var player := get_tree().get_nodes_in_group("Player").front() as PlayerController
# top down player is used for the camera in battle
@onready var top_down_player := get_tree().get_nodes_in_group("TopDownPlayer").front() as TopDownPlayerController
var test_enemy := preload("res://Scenes/Characters/Enemies/test_enemy.tscn") as PackedScene

var enemy_units: Array[BattleCharacter] = []
var player_units: Array[BattleCharacter] = []

# String : int
var character_counts: Dictionary = {}

var current_character_index: int = 0
var current_character: BattleCharacter

## our best guess at the input method based on the last input update
var is_using_controller: bool = false

signal TurnStarted(character: BattleCharacter)

## The BattleCharacter which the player has targeted
## This is used for attacking enemies etc
var player_selected_character = null

var turn_order_to_ui_dict: Dictionary = {}  # key = UI index, value = turn order index
@onready var turn_order_ui := player.get_node("BattleDebugUI/ItemList") as ItemList


func _ready() -> void:
    turn_order_ui.hide()

@export var is_in_battle : bool = false:
    get:
        return not turn_order.is_empty()

func add_to_battle(character: BattleCharacter) -> void:
    if not active:
        print("Inactive")
        return

    var character_name := character.character_name

    if turn_order.has(character):
        print(character_name + " already in turn order")
        return

    var initiative := character.roll_initiative()
    var inserted_at := -1

    if turn_order.size() == 0:
        # First character entering the battle, just append
        turn_order.append(character)
        inserted_at = 0
    else:
        # Insert character into the correct position based on initiative
        var inserted := false
        for i in range(turn_order.size()):
            if character.initiative > turn_order[i].initiative:
                turn_order.insert(i, character)
                inserted = true
                inserted_at = i
                break
        if not inserted:
            turn_order.append(character)
            inserted_at = turn_order.size() - 1

    if character.character_type == BattleEnums.CharacterType.ENEMY:
        
        enemy_units.append(character)

        # Give the enemy a unique name if there are multiple enemies with the same name
        character_counts.get_or_add(character_name, 0)
        # We don't use the get_or_add return value because we want to increment the count
        # get_letter is 0-indexed so we add 1 after getting the letter
        var name_suffix := " " + Util.get_letter(character_counts[character_name])
        character_counts[character_name] += 1
        # Don't add A to the name if it's the first enemy
        if character_counts[character_name] > 1:
            character_name += name_suffix
   
    # set the name in the script so the character instance knows its proper name in battle
    character.character_name = character_name

    if character.character_type == BattleEnums.CharacterType.PLAYER:
        player_units.append(character)
        
    _add_to_turn_order_ui(character, inserted_at)
    print(character_name + " entered the battle with initiative " + str(initiative))
    

func _add_to_turn_order_ui(character: BattleCharacter, index_in_turn_order: int) -> void:
    if index_in_turn_order == -1:
        printerr("Invalid index in turn order")
        return

    var ui_index := turn_order_ui.add_item(character.character_name + " - " + str(character.initiative), null, true)
    turn_order_to_ui_dict.get_or_add(ui_index, index_in_turn_order)

func _remove_from_turn_order_ui(character: BattleCharacter) -> void:
    for i in range(turn_order_ui.get_item_count()):
        if turn_order_ui.get_item_text(i) == character.character_name + " - " + str(character.initiative):
            turn_order_ui.remove_item(i)
            break

func leave_battle(character: BattleCharacter) -> void:
    if not active or not turn_order.has(character):
        return


    if character.character_type == BattleEnums.CharacterType.ENEMY:
        enemy_units.erase(character)
    elif character.character_type == BattleEnums.CharacterType.PLAYER:
        player_units.erase(character)

    turn_order.erase(character)
    _remove_from_turn_order_ui(character)

    character_counts.erase(character.character_name)

    character.on_leave_battle()

    # if the current turn order index is out of bounds, reset it
    if current_character_index >= turn_order.size():
        current_character_index = 0

    print(character.get_parent().name + " left the battle")

    # TODO: victory/defeat conditions

func enter() -> void:
    
    Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

    top_down_player.enabled = true
    print("Battle state entered")
    
    var added: int = 0
    for child in get_tree().get_nodes_in_group("BattleCharacter"):
        if child is BattleCharacter:
            add_to_battle(child as BattleCharacter)
            added += 1
        else:
            printerr(child.name + " should not be tagged as a BattleCharacter!!")
            printerr(child)

    if turn_order.is_empty():
        return
    elif turn_order.size() == 1:
        spawn_enemy()

    # Start the first character's turn
    current_character_index = -1
    print("added: " + str(added))
    ready_next_turn()

func ready_next_turn() -> void:
    player_selected_character = null

    if turn_order.is_empty():
        # end battle
        printerr("Empty turn order!")
        Transitioned.emit(self, "ExplorationState")

    current_character_index += 1
    if current_character_index >= turn_order.size():
        current_character_index = 0

    current_character = turn_order[current_character_index]
    top_down_player.focused_node = current_character.get_parent()
    TurnStarted.emit(current_character)

func exit() -> void:
    for character in turn_order:
        # make sure we clean up the character
        leave_battle(character)

    EndedBattle.emit()
    turn_order.clear()
    current_character_index = 0

    turn_order_ui.clear()
    turn_order_to_ui_dict.clear()

    player_units.clear()
    enemy_units.clear()
    character_counts.clear()

    top_down_player.enabled = false

    print("Battle State left")

func update(_delta) -> void:
    pass

func physics_update(delta) -> void:
    top_down_player.player_process(delta)

func print_turn_order() -> void:
    if not turn_order.is_empty():
        # Construct the string in the desired format
        var output := "["
        for i in range(turn_order.size()):
            var char_name := turn_order[i].get_parent().name
            var initiative := str(turn_order[i].initiative)
            output += char_name + ": " + initiative
            if i < turn_order.size() - 1:
                output += ", "
        output += "]"

        # Print the constructed string
        print(output)

        # Print the entity with the highest initiative
        print(turn_order[0].get_parent().name + " has the highest initiative")

func input_update(event) -> void:
    if not active or event.is_echo():
        return

    if event is InputEventKey:
        if current_character != null:
            current_character.battle_input(event)

        if event.is_pressed() and event.keycode == KEY_R:
            Transitioned.emit(self, "ExplorationState")
        elif event.is_pressed() and event.keycode == KEY_P:
            print_turn_order()
        elif event.is_pressed() and event.keycode == KEY_1:
            spawn_enemy()
        is_using_controller = false

    # TODO: do this in an autoload
    # if the input event is a controller input event, we can assume the player is using a controller
    elif event is InputEventJoypadMotion or event is InputEventJoypadButton:
        is_using_controller = true
    elif event is InputEventMouseMotion or event is InputEventMouseButton:
        is_using_controller = false

func spawn_enemy() -> void:
    var enemy_instance := test_enemy.instantiate()
    add_child(enemy_instance)
    enemy_instance.global_position = player.global_position + Vector3(0, 4, 5)
    var enemy_battle_character := enemy_instance.get_node("BattleCharacter") as BattleCharacter
    add_to_battle(enemy_battle_character)

func unhandled_input_update(event) -> void:
    top_down_player.unhandled_input_update(event)
