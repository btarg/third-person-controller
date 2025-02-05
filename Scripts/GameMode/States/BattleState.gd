extends State
class_name BattleState


var turn_order: Array[BattleCharacter] = []

# get exploration player
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
var _last_available_actions := BattleEnums.EAvailableCombatActions.NONE

var turns_played := -1

var movement_locked_in := false

var available_actions : BattleEnums.EAvailableCombatActions = BattleEnums.EAvailableCombatActions.SELF:
    get:
        return available_actions
    set(value):
        available_actions = value
        if value != _last_available_actions:
            # print("Available actions changed to " + Util.get_enum_name(BattleEnums.EAvailableCombatActions, value))
            BattleSignalBus.OnAvailableActionsChanged.emit()
            _last_available_actions = value

## The BattleCharacter which the player has targeted
## This is used for attacking enemies etc
var player_selected_character : BattleCharacter:
    get:
        return player_selected_character
    set(character):
        player_selected_character = character

        # Set available actions based on selected character
        if not character:
            available_actions = BattleEnums.EAvailableCombatActions.GROUND
            return

        if character.character_type == BattleEnums.ECharacterType.PLAYER:
            if character == current_character:
                available_actions = BattleEnums.EAvailableCombatActions.SELF
            else:
                available_actions = BattleEnums.EAvailableCombatActions.ALLY

        elif character.character_type == BattleEnums.ECharacterType.ENEMY:
            available_actions = BattleEnums.EAvailableCombatActions.ENEMY

@onready var turn_order_ui := get_node_or_null("ChooseTargetUI/TurnOrderContainer") as TurnOrderContainer
@onready var selected_target_label := get_node_or_null("ChooseTargetUI/SelectedEnemyLabel") as Label

func _ready() -> void:
    if not player:
        return

    selected_target_label.hide()

    Console.add_command("exit_battle", force_exit_battle)
    Console.add_command("spawn_enemy", spawn_enemy)
    Console.add_command("print_turn_order", print_turn_order)

    Console.add_command("damage", _command_damage, 2)
    Console.add_command("remove", _command_remove_selected)

    Console.add_command("set_dmg_element", _command_set_dmg_element, 1)

    Console.add_command("print_modifiers", _print_modifiers_command, 1)
    Console.add_command("print_stat", _print_stat_command, 1)
    Console.add_command("print_inventory", _print_inventory_command, 1)

    Console.add_command("add_modifier", _add_modifier_command, 2)

    current_character = player.battle_character
    player_selected_character = current_character

    # turn_order_ui.is_ui_active = false

func _print_inventory_command(character_name: String) -> void:
    Console.print_line("Inventory for %s\n====" % [character_name], true)
    for character: BattleCharacter in get_tree().get_nodes_in_group("BattleCharacter"):
        if character.character_internal_name.to_lower() == character_name.to_lower():
            character.inventory.print_inventory()
            Console.print_line("====", true)
            return
    Console.print_line("No character found with name %s" % [character_name])
    
func _add_modifier_command(char_name: String, modifier_name: String) -> void:
    var modifier_path := "res://Scripts/Data/StatModifiers/%s.tres" % modifier_name
    var resource = load(modifier_path)
    if not resource:
        Console.print_line("Modifier not found at path:")
        Console.print_line(modifier_path)
        return

    var target_char: BattleCharacter = null
    for c in turn_order:
        if c.character_internal_name.to_lower() == char_name.to_lower():
            target_char = c
            break
    if not target_char:
        Console.print_line("Character not found: %s" % char_name)
        return

    target_char.stats.add_modifier(resource as StatModifier)
    Console.print_line("Added %s to %s" % [modifier_name, target_char.character_name])

func _print_stat_command(stat_int_string: String) -> void:
    if player_selected_character:
        player_selected_character.print_stat(stat_int_string)

func _print_modifiers_command(char_name: String = "") -> void:
    if char_name.is_empty():
        if player_selected_character:
            Console.print_line("Modifiers for %s" % [player_selected_character.character_name], true)
            player_selected_character.print_modifiers()
        else:
            Console.print_line("No current character", true)
    else:
        for c: BattleCharacter in get_tree().get_nodes_in_group("BattleCharacter"):
            if c.character_internal_name.to_lower() == char_name.to_lower():
                Console.print_line("Modifiers for %s" % [c.character_name], true)
                c.print_modifiers()
                return
        Console.print_line("No character found with name %s" % [char_name], true)

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
        var result : BattleEnums.ESkillResult = player_selected_character.take_damage_flat(null, amount, damage_type)
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

var is_in_battle : bool = false:
    get:
        return not turn_order.is_empty()

func add_to_battle(character: BattleCharacter) -> void:
    if not active:
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
            

    if character.character_type == BattleEnums.ECharacterType.ENEMY:
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

    if character.character_type == BattleEnums.ECharacterType.PLAYER:
        player_units.append(character)
    elif character.character_type == BattleEnums.ECharacterType.ENEMY:
        enemy_units.append(character)

    print(character_name + " entered the battle with initiative " + str(character.initiative))

    character.on_join_battle()
            

func leave_battle(character: BattleCharacter, do_result_check: bool = true) -> void:
    if not active or not turn_order.has(character):
        return


    if character.character_type == BattleEnums.ECharacterType.ENEMY:
        enemy_units.erase(character)
    elif character.character_type == BattleEnums.ECharacterType.PLAYER:
        player_units.erase(character)

    turn_order.erase(character)

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
    # ready_next_turn() will increment this to 1
    turns_played = -1

    for child in get_tree().get_nodes_in_group("BattleCharacter"):
        if child is BattleCharacter:
            add_to_battle(child as BattleCharacter)
        else:
            printerr(child.name + " should not be tagged as a BattleCharacter!!")
            printerr(child)

    top_down_player.enabled = true

    if turn_order.size() < 2 or enemy_units.is_empty():
        print("Cannot enter battle: invalid turn order (are there enough enemies?)")
        Transitioned.emit(self, "ExplorationState")
        return

    # Start the first character's turn
    current_character_index = -1
    ready_next_turn()
    BattleSignalBus.OnBattleStarted.emit()

func ready_next_turn() -> void:
    if not active:
        return

    # player_selected_character = null
    available_actions = BattleEnums.EAvailableCombatActions.SELF

    if turn_order.size() < 2:
        # end battle
        printerr("Invalid turn order! How did we get here?")
        Transitioned.emit(self, "ExplorationState")

    if current_character:
        # End turn
        current_character.stats.active_modifiers_start_turn(false)

        current_character.turns_left -= 1
        if current_character.turns_left > 0:
            print("[ONE MORE] %s gets %s more turns!" % [current_character.character_name, current_character.turns_left])
            movement_locked_in = true
        else:
            current_character.turns_left = 0 # cap at 0 minimum
            current_character_index += 1
            current_character.behaviour_state_machine.set_state("IdleState")
            movement_locked_in = false

    # Prevent overflow
    if current_character_index >= turn_order.size():
        current_character_index = 0

    current_character = turn_order[current_character_index]
    _focus_character(current_character)

    # 0 turns left means the character is a new character
    if current_character.turns_left == 0:
        current_character.turns_left = 1

    # Select self at start of battle
    if (current_character.character_type == BattleEnums.ECharacterType.PLAYER
    and not player_selected_character):
        select_character(current_character)

    BattleSignalBus.OnTurnStarted.emit(current_character)
    turns_played += 1

    # turn_order_ui.is_ui_active = true

func select_character(character: BattleCharacter, focus_camera: bool = true) -> void:
    if not active or not current_character:
        return
    var last_selected := player_selected_character
    player_selected_character = character

    if focus_camera:
        _focus_character(player_selected_character)

    # If we're selecting the same character, don't fire the signal
    if character == last_selected:
        return

    BattleSignalBus.OnCharacterSelected.emit(character)

func _focus_character(focus_character: BattleCharacter) -> void:
    if not focus_character:
        return
    top_down_player.focused_node = focus_character.get_parent()
    if turns_played < 0:
        top_down_player.teleport_to_focused_node()

func exit() -> void:
    for character in turn_order:
        # clean up the character without checking win condition again
        leave_battle(character, false)
    turn_order.clear()
    current_character_index = 0

    player_units.clear()
    enemy_units.clear()
    character_counts.clear()

    top_down_player.enabled = false

    player_selected_character = null
    current_character = null

    BattleSignalBus.OnBattleEnded.emit()
    print("Battle State left")

func _state_process(_delta) -> void:
    pass

func _state_physics_process(delta: float) -> void:
    # Update navigation for active character
    if current_character:
        current_character.character_controller.nav_update(delta)
        if current_character.character_type == BattleEnums.ECharacterType.PLAYER:
            current_character.character_controller.player_process(delta)
    top_down_player.player_process(delta)

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

func selected_self() -> bool:
    return player_selected_character == current_character

func _state_unhandled_input(event: InputEvent) -> void:
    top_down_player.input_update_from_battle_state(event)
