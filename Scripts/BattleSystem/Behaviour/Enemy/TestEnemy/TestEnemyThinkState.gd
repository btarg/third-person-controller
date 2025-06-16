class_name TestEnemyThinkState extends State

# Configuration - expose these in editor for easy balancing
@export_group("Behavior Weights")
@export var base_attack_weight: float = 1.0
@export var base_spell_weight: float = 0.9
@export var base_move_weight: float = 0.8
@export var base_heal_weight: float = 0.7
@export var base_draw_spell_weight: float = 0.6
@export var base_defend_weight: float = 0.5

@export_group("Health Thresholds")
@export var critical_health_threshold: float = 0.25
@export var low_health_threshold: float = 0.4
@export var good_health_threshold: float = 0.6

# TODO: replace with the actual spell, since we will pre-choose the best one
var spell_range := 35.0
var min_mana_for_spell := 0.2

@onready var battle_character := get_owner().get_node("BattleCharacter") as BattleCharacter
var last_decision_time: float = 0.0
var current_action: String = ""

var available_actions: Array[ActionData] = []

func _ready() -> void:
    _initialize_actions()

func enter() -> void:
    print("Enemy Think State Entered")
    _make_decision()

# TODO: multi-targeting logic for spells and items
# Before we can make decisions, we need to pick player(s) as target(s).
# We will only be able to select multiple targets with a skill which has AOE
# So this logic will need to be implemented much later on, once I have
# moved SpellItem logic to the new Skill system. // 17/06/2025

# For spells, we pre-select the best possible one,
# and when we calculate the spell action weight,
# we use the same criteria for choosing the spell.
# E.g. if the player is weak to the spell, or it does
# enough damage to kill the player.
# This will mean that the enemy does not always cast the spell as
# a regular attack, move etc might still be more beneficial.
# We will also need to do the same for items

func _initialize_actions() -> void:
    available_actions.clear()
    
    # Attack action
    available_actions.append(ActionData.new(
        "attack",
        _calculate_attack_weight,
        _execute_attack,
        _can_execute_attack,
        -0.1 # decrease aggression slightly for attack action
    ))
    
    # Cast spell action
    available_actions.append(ActionData.new(
        "cast_spell",
        _calculate_spell_weight,
        _execute_cast_spell,
        _can_execute_cast_spell,
        -0.2
    ))
    
    # Defend action
    available_actions.append(ActionData.new(
        "defend",
        _calculate_defend_weight,
        _execute_defend,
        _can_execute_defend,
        0.1
    ))
    
    # Heal action
    available_actions.append(ActionData.new(
        "heal",
        _calculate_heal_weight,
        _execute_heal,
        _can_execute_heal,
        0.1
    ))
    
    # Move towards player action
    available_actions.append(ActionData.new(
        "move_towards_player",
        _calculate_move_weight,
        _execute_move_towards_player,
        _can_execute_move_towards_player
    ))
    
    # Draw spell action
    available_actions.append(ActionData.new(
        "draw_spell",
        _calculate_draw_spell_weight,
        _execute_draw_spell,
        _can_execute_draw_spell,
        -0.2
    ))
    
    # Use item action
    available_actions.append(ActionData.new(
        "use_item",
        _calculate_item_weight,
        _execute_use_item,
        _can_execute_use_item,
        0.1
    ))

func _make_decision() -> void:
    print("Making decision...")
    var context := _get_context()
    var chosen_action := _select_best_action(context)
    
    if not chosen_action:
        print("Something went VERY wrong, no action selected!")
        return

    chosen_action.execute()
    current_action = chosen_action.name
    # controller.aggression_system.change_aggression(chosen_action.aggression_change)
    battle_character.spend_actions(3)

func _get_context() -> Dictionary:

    var current_hp := battle_character.current_hp
    var max_hp: float = max(0.0, battle_character.stats.get_stat(CharacterStatEntry.ECharacterStat.MaxHP))

    var current_mp := battle_character.current_mp
    var max_mp: float = max(0.0, battle_character.stats.get_stat(CharacterStatEntry.ECharacterStat.MaxMP))

    var attack_range: float = battle_character.stats.get_stat(CharacterStatEntry.ECharacterStat.AttackRange)
    var draw_range: float = battle_character.stats.get_stat(CharacterStatEntry.ECharacterStat.DrawRange)


    # TODO: choose a player to attack before grabbing their HP
    var current_player_hp := 100.0

    # var aggression := controller.aggression_system.get_aggression_multiplier()
    var health_ratio := current_hp / max_hp
    var mana_ratio := current_mp / max_mp
    var player_health_ratio := current_player_hp / 100.0
    var distance := 10.0 # Placeholder for distance calculation
    return {
        "aggression": 1.0,
        "health_ratio": health_ratio,
        "mana_ratio": mana_ratio,
        "player_health_ratio": player_health_ratio,
        "distance": distance,
        "in_attack_range": distance <= attack_range,
        "in_spell_range": distance <= spell_range,
    }

func _select_best_action(context: Dictionary) -> ActionData:
    var valid_actions: Array[ActionData] = []
    
    # Filter actions that can be executed and calculate their weights
    for action in available_actions:
        if action.can_execute(context):
            action.calculate_weight(context)
            if action.current_weight > 0.0:
                valid_actions.append(action)
    
    if valid_actions.is_empty():
        print("No valid actions available!")
        return null
    
    # Weighted random selection
    var total_weight := 0.0
    for action in valid_actions:
        total_weight += action.current_weight
    
    var random_value := randf() * total_weight
    var current_weight := 0.0
    
    for action in valid_actions:
        current_weight += action.current_weight
        if random_value <= current_weight:
            print("Selected action: %s (weight: %.2f)" % [action.name, action.current_weight])
            return action
    
    return valid_actions[0]  # Fallback

# Weight calculation functions
func _calculate_attack_weight(context: Dictionary) -> float:
    var weight := base_attack_weight
    weight *= context.aggression
    
    if context.player_health_ratio < low_health_threshold:
        weight *= 1.5
    
    if context.health_ratio < low_health_threshold and context.player_health_ratio > critical_health_threshold:
        weight *= 0.5
    
    return weight

func _calculate_spell_weight(context: Dictionary) -> float:
    var weight := base_spell_weight
    weight *= context.aggression
    
    if not context.in_attack_range:
        weight *= 1.2
    
    if context.player_health_ratio < low_health_threshold:
        weight *= 1.3
    
    return weight

func _calculate_defend_weight(context: Dictionary) -> float:
    var weight := base_defend_weight
    
    # Only defend when at low health
    if context.health_ratio < low_health_threshold:
        weight *= 1.8
    elif context.health_ratio > good_health_threshold:
        # High health enemy should rarely defend
        weight *= 0.3
    
    # Don't defend when player is weak and enemy is strong
    if context.health_ratio > context.player_health_ratio + 0.2:
        weight *= 0.2
    
    # If player is very low and enemy is healthy, almost never defend
    if context.player_health_ratio < critical_health_threshold and context.health_ratio > low_health_threshold:
        weight *= 0.1
    
    weight /= context.aggression
    return weight

func _calculate_heal_weight(context: Dictionary) -> float:
    var weight := base_heal_weight
    
    if context.health_ratio < critical_health_threshold:
        weight *= 3.0
    elif context.health_ratio < low_health_threshold:
        weight *= 1.5
    else:
        weight *= 0.2
    
    if context.player_health_ratio < critical_health_threshold:
        weight *= 0.3
    
    return weight

func _calculate_move_weight(context: Dictionary) -> float:
    var weight := base_move_weight
    
    if context.health_ratio > good_health_threshold:
        weight *= context.aggression
    
    return weight

func _calculate_draw_spell_weight(context: Dictionary) -> float:
    return 0.1 if context.mana_ratio > min_mana_for_spell else 0.6

func _calculate_item_weight(context: Dictionary) -> float:
    return 0.3 if context.health_ratio < good_health_threshold else 0.1

# Can execute functions
func _can_execute_attack(context: Dictionary) -> bool:
    return context.in_attack_range


## TODO: can execute cast spell
# To check if we can cast a spell, we need to check:
# 1. If the enemy can use spells
# 2. If the enemy is in range to cast the spell
# 3. If the enemy has enough mana to cast the spell
# 4. If the enemy has enough actions left to cast the spell
#
# If the spell targets multiple enemies, we will need to find the optimal location
# on the map (within range) to cast the spell to hit multiple targets.
# i can probably cheat this by just selecting the location of the player with
# the lowest HP, as that is the most likely "primary" target for the spell.
func _can_execute_cast_spell(context: Dictionary) -> bool:
    return (battle_character.can_use_spells
    and (context.in_spell_range as bool)
    and (context.mana_ratio as float) > min_mana_for_spell)

func _can_execute_defend(context: Dictionary) -> bool:
    return true

func _can_execute_heal(context: Dictionary) -> bool:
    return true  # Could add checks for healing items/abilities

func _can_execute_move_towards_player(context: Dictionary) -> bool:
    return not (context.in_attack_range or context.in_spell_range)

func _can_execute_draw_spell(context: Dictionary) -> bool:
    return context.mana_ratio < 0.8  # Don't draw spells if mana is high

func _can_execute_use_item(context: Dictionary) -> bool:
    return true  # Could add inventory checks

# Execution functions
func _execute_attack() -> void:
    print("Executing attack!")

func _execute_cast_spell() -> void:
    print("Executing cast spell!")

func _execute_defend() -> void:
    print("Executing defend!")

func _execute_heal() -> void:
    print("Executing heal!")

func _execute_move_towards_player() -> void:
    print("Executing move towards player!")

func _execute_draw_spell() -> void:
    print("Executing draw spell!")

func _execute_use_item() -> void:
    print("Executing use item!")

func exit() -> void:
    print("Enemy Think State Exited")
    current_action = ""