extends State
class_name BattleState


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


## The BattleCharacter which the player has targeted
## This is used for attacking enemies etc
var player_selected_character = null

@onready var turn_order_ui := get_node_or_null("ChooseTargetUI/ItemList") as ItemList
@onready var selected_target_label := get_node_or_null("ChooseTargetUI/SelectedEnemyLabel") as Label

func _ready() -> void:
    turn_order_ui.hide()
    selected_target_label.hide()

    Console.add_command("exit_battle", force_exit_battle)
    Console.add_command("spawn_enemy", spawn_enemy)
    Console.add_command("print_turn_order", print_turn_order)

    Console.add_command("damage", _command_damage, 2)
    Console.add_command("remove", _command_remove_selected)

    Console.add_command("set_dmg_element", _command_set_dmg_element, 1)
    
func force_exit_battle() -> void:
    Transitioned.emit(self, "ExplorationState")

func _command_remove_selected() -> void:
    if player_selected_character:
        print("Removing selected character from battle...")
        leave_battle(player_selected_character)

func _command_damage(amount, type) -> void:
    amount = float(amount)
    type = int(type)
    # get enum from int
    var damage_type := type as BattleEnums.EAffinityElement

    if player_selected_character and amount:
        Console.print_line("Attempting to deal %s %s damage to %s" % [amount, Util.get_enum_name(BattleEnums.EAffinityElement, damage_type), player_selected_character.character_name])
        var result : BattleEnums.ESkillResult = player_selected_character.take_damage(null, amount, damage_type)
        Console.print_line("Result: " + Util.get_enum_name(BattleEnums.ESkillResult, result))
        
    else:
        Console.print_line("No target selected")

func _command_set_dmg_element(type) -> void:
    type = int(type)
    # get enum from int
    var damage_type := type as BattleEnums.EAffinityElement

    if current_character:
        Console.print_line("Setting damage element to %s for %s" % [Util.get_enum_name(BattleEnums.EAffinityElement, damage_type), current_character.character_name])
        current_character.basic_attack_element = damage_type

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
    turn_order_ui.clear()
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
            

    if character.character_type == BattleEnums.CharacterType.ENEMY:
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
    elif character.character_type == BattleEnums.CharacterType.ENEMY:
        enemy_units.append(character)

    # add the sorted turn order to the UI
    for c: BattleCharacter in turn_order:
        _add_to_turn_order_ui(c)

    print(character_name + " entered the battle with initiative " + str(character.initiative))

    character.OnJoinBattle.emit()

func _add_to_turn_order_ui(character: BattleCharacter) -> void:
    turn_order_ui.add_item(character.character_name + " - " + str(character.initiative), null, true)

func _remove_from_turn_order_ui(character: BattleCharacter) -> void:
    for i in range(turn_order_ui.get_item_count()):
        if turn_order_ui.get_item_text(i) == character.character_name + " - " + str(character.initiative):
            turn_order_ui.remove_item(i)
            break
            

func leave_battle(character: BattleCharacter, do_result_check: bool = true) -> void:
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

    print(character.character_name + " left the battle")

    if do_result_check:
        if player_units.is_empty():
            Transitioned.emit(self, "BattleLostState")
        elif enemy_units.is_empty():
            Transitioned.emit(self, "BattleVictoryState")


func enter() -> void:
    for child in get_tree().get_nodes_in_group("BattleCharacter"):
        if child is BattleCharacter:
            add_to_battle(child as BattleCharacter)
        else:
            printerr(child.name + " should not be tagged as a BattleCharacter!!")
            printerr(child)

    Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
    top_down_player.enabled = true

    if turn_order.size() < 2 or enemy_units.is_empty():
        print("Cannot enter battle: invalid turn order (are there enough enemies?)")
        Transitioned.emit(self, "ExplorationState")
        return

    # Start the first character's turn
    current_character_index = -1
    ready_next_turn()

func ready_next_turn() -> void:
    if not active:
        return

    player_selected_character = null

    if turn_order.size() < 2:
        # end battle
        printerr("Invalid turn order! How did we get here?")
        Transitioned.emit(self, "ExplorationState")

    if current_character:
        current_character.turns_left -= 1
        if current_character.turns_left > 0:
            print("[ONE MORE] %s gets %s more turns!" % [current_character.character_name, current_character.turns_left])
        else:
            current_character.turns_left = 0 # cap at 0 minimum
            current_character_index += 1

    # Prevent overflow
    if current_character_index >= turn_order.size():
        current_character_index = 0

    current_character = turn_order[current_character_index]
    # 0 turns left means the character is a new character
    if current_character.turns_left == 0:
        current_character.turns_left = 1

    top_down_player.focused_node = current_character.get_parent()
    BattleSignalBus.TurnStarted.emit(current_character)

func exit() -> void:
    for character in turn_order:
        # clean up the character without checking win condition again
        leave_battle(character, false)
    turn_order.clear()
    current_character_index = 0

    turn_order_ui.clear()

    player_units.clear()
    enemy_units.clear()
    character_counts.clear()

    top_down_player.enabled = false

    BattleSignalBus.BattleEnded.emit()
    print("Battle State left")

func _state_process(_delta) -> void:
    pass

func _state_physics_process(delta: float) -> void:
    top_down_player.player_process(delta)
    # Update navigation for active character
    if current_character:
        current_character.character_controller.nav_update(delta)

func print_turn_order() -> void:
    if not turn_order.is_empty():
        # Construct the string in the desired format
        var output := "["
        for i in range(turn_order.size()):
            var char_name := turn_order[i].character_name
            var initiative := str(turn_order[i].initiative)
            output += char_name + ": " + initiative
            if i < turn_order.size() - 1:
                output += ", "
        output += "]"

        # Print the constructed string
        Console.print_line(output, true)

        # Print the entity with the highest initiative
        Console.print_line(turn_order.front().character_name + " has the highest initiative", true)
        
func spawn_enemy() -> void:
    if not player:
        return

    var enemy_instance := test_enemy.instantiate()
    add_child(enemy_instance)
    enemy_instance.global_position = player.global_position + Vector3(0, 0, 5)
    var enemy_battle_character := enemy_instance.get_node("BattleCharacter") as BattleCharacter
    add_to_battle(enemy_battle_character)

func _state_unhandled_input(event) -> void:
    top_down_player.unhandled_input_update(event)
