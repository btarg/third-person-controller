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

signal TurnStarted(character: BattleCharacter)

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
    if turn_order.size() == 0:
        # First character entering the battle, just append
        turn_order.append(character)
    else:
        # Insert character into the correct position based on initiative
        var inserted := false
        for i in range(turn_order.size()):
            if character.initiative > turn_order[i].initiative:
                turn_order.insert(i, character)
                inserted = true
                break
        if not inserted:
            turn_order.append(character)

    if character.character_type == BattleCharacter.CharacterType.ENEMY:
        enemy_units.append(character)

        # initialise count for character name
        if not character_counts.has(character_name):
            character_counts.get_or_add(character_name, 0)

        # Give the enemy a unique name if there are multiple enemies with the same name
        character_counts[character_name] += 1
        var count: int = character_counts[character_name]
        character_name += " " + Util.get_letter(count)


    elif character.character_type == BattleCharacter.CharacterType.PLAYER:
        player_units.append(character)

    # set the name in the script so the character instance knows its proper name in battle
    character.character_name = character_name
    print(character_name + " entered the battle with initiative " + str(initiative))
    
    print_turn_order()

func leave_battle(character: BattleCharacter) -> void:
    if not active or not turn_order.has(character):
        return

    # remove character from turn order
    turn_order.erase(character)
    print(character.get_parent().name + " left the battle")
    print(turn_order)

    # disconnect signal
    character.disconnect_signals()

    # if the current turn order index is out of bounds, reset it
    if current_character_index >= turn_order.size():
        current_character_index = 0

    # TODO: victory/defeat conditions

func enter() -> void:
    
    Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

    top_down_player.enabled = true
    print("Battle state entered")
    for child in get_tree().get_nodes_in_group("BattleCharacter"):
        if child is BattleCharacter:
            add_to_battle(child as BattleCharacter)
        else:
            printerr(child.name + " should not be tagged as a BattleCharacter!!")
            printerr(child)

    if turn_order.is_empty():
        return

    # Start the first character's turn
    current_character_index = -1
    ready_next_turn()

func ready_next_turn() -> void:
    current_character_index += 1
    if current_character_index >= turn_order.size():
        current_character_index = 0
    current_character = turn_order[current_character_index % turn_order.size()]
    TurnStarted.emit(current_character)

func exit() -> void:
    EndedBattle.emit()
    turn_order.clear()
    player_units.clear()
    enemy_units.clear()
    character_counts.clear()

    top_down_player.enabled = false

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

    if event is InputEventKey and not event.is_echo() and active:

        if current_character != null:
            current_character.battle_input(event)

        if event.is_pressed() and event.keycode == KEY_R:
            Transitioned.emit(self, "ExplorationState")
        elif event.is_pressed() and event.keycode == KEY_P:
            print_turn_order()
        elif event.is_pressed() and event.keycode == KEY_1:
            var enemy_instance := test_enemy.instantiate()
            add_child(enemy_instance)
            enemy_instance.global_position = player.global_position
            var enemy_battle_character := enemy_instance.get_node("BattleCharacter") as BattleCharacter
            add_to_battle(enemy_battle_character)

func unhandled_input_update(event) -> void:
    top_down_player.unhandled_input_update(event)