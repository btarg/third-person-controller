class_name TestEnemyThinkState extends State

class DecisionContext:
    var health_ratio: float
    var mana_ratio: float
    var player_health_ratio: float
    var distance: float
    var in_attack_range: bool
    var in_spell_range: bool
    var aggression: float
    
    func _init(p_health_ratio: float, p_mana_ratio: float, p_player_health_ratio: float, 
               p_distance: float, p_in_attack_range: bool, p_in_spell_range: bool, p_aggression: float):
        health_ratio = p_health_ratio
        mana_ratio = p_mana_ratio
        player_health_ratio = p_player_health_ratio
        distance = p_distance
        in_attack_range = p_in_attack_range
        in_spell_range = p_in_spell_range
        aggression = p_aggression

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

var best_damage_spell: SpellItem = null
var best_heal_spell: SpellItem = null
var best_spell_to_cast: SpellItem = null

@onready var battle_character := get_owner().get_node("BattleCharacter") as BattleCharacter
var last_decision_time: float = 0.0
var current_action: String = ""

var available_actions: Array[ActionData] = []

# TODO: replace this with an array so we can have multiple targets (e.g. for AOE spells)
var target_character: BattleCharacter = null

func _ready() -> void:
    _initialize_actions()
    _select_best_spells()

func enter() -> void:
    _make_decision()

# TODO: multi-targeting logic for spells and items
# Before we can make decisions, we need to pick player(s) as target(s).
# We will only be able to select multiple targets with a skill which has AOE
# So this logic will need to be implemented much later on, once I have
# moved SpellItem logic to the new Skill system. // 17/06/2025

# IMPORTANT:
# I will need to make sure that the enemy has enough Actions left to execute
# as part of choosing the action.

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
    var context := _get_context()
    _precalculate_best_spell_to_cast(context)
    var chosen_action := _select_best_action(context)
    
    if not chosen_action:
        print("Something went VERY wrong, no action selected!")
        return

    chosen_action.execute()
    current_action = chosen_action.name
    print("%s executed action: %s" % [battle_character.character_name, chosen_action.name])
    
    await get_tree().create_timer(1.0).timeout
    battle_character.spend_actions(3)


func _get_context() -> DecisionContext:
    var current_hp := battle_character.current_hp
    var max_hp: float = max(0.0, battle_character.stats.get_stat(CharacterStatEntry.ECharacterStat.MaxHP))
    var current_mp := battle_character.current_mp
    var max_mp: float = max(0.0, battle_character.stats.get_stat(CharacterStatEntry.ECharacterStat.MaxMP))
    
    var attack_range: float = battle_character.stats.get_stat(CharacterStatEntry.ECharacterStat.AttackRange)
    var spell_range: float = _get_best_spell_range()

    # TODO: choose a player to attack before grabbing their HP
    var current_player_hp := battle_character.battle_state.current_character.current_hp
    var current_player_max_hp: float = max(0.0,
    battle_character.battle_state.current_character.stats.get_stat(CharacterStatEntry.ECharacterStat.MaxHP))

    # find closest player to our node
    var players := get_tree().get_nodes_in_group("Player")

    assert(players.size() > 0, "No players found in the scene!")

    players.sort_custom(
        func(a, b):
            return a.global_position.distance_to(b.global_position)
    )
    
    target_character = players[0].get_node("BattleCharacter") as BattleCharacter

    
    var health_ratio := current_hp / max_hp
    var mana_ratio := current_mp / max_mp
    var player_health_ratio := current_player_hp / current_player_max_hp
    
    var distance: float = battle_character.get_parent().global_position.distance_to(
        target_character.get_parent().global_position)

    var in_attack_range: bool = distance <= attack_range
    var in_spell_range: bool = distance <= spell_range

    print("=== %s Decision Context ===" % battle_character.character_name)
    print("HP: %d/%d (%.1f%%)" % [current_hp, max_hp, current_hp / max_hp * 100])
    print("MP: %d/%d (%.1f%%)" % [current_mp, max_mp, current_mp / max_mp * 100])
    print("Actions Left: %d" % battle_character.actions_left)
    
    
    if best_damage_spell:
        print("Best damage spell: %s (MP: %d, Range: %.1f)" % [best_damage_spell.item_name, best_damage_spell.mp_cost, best_damage_spell.effective_range])
    if best_heal_spell:
        print("Best heal spell: %s (MP: %d, Range: %.1f)" % [best_heal_spell.item_name, best_heal_spell.mp_cost, best_heal_spell.effective_range])
    

    print("Distance to target: %.1f" % distance)
    print("In attack range: %s | In spell range: %s" % [in_attack_range, in_spell_range])

    return DecisionContext.new(
        health_ratio,
        mana_ratio,
        player_health_ratio,
        distance,
        distance <= attack_range,
        distance <= spell_range,
        1.0
    )

func _precalculate_best_spell_to_cast(context: DecisionContext) -> void:
    # Reset the best spell to cast
    best_spell_to_cast = null
    
    # If no spells are available, return early
    if not best_damage_spell and not best_heal_spell:
        return
    
    # Choose damage spell if targeting enemy, heal spell if low health
    if context.health_ratio < low_health_threshold and best_heal_spell:
        best_spell_to_cast = best_heal_spell
    elif best_damage_spell:
        best_spell_to_cast = best_damage_spell
    elif best_heal_spell:
        best_spell_to_cast = best_heal_spell

func _select_best_action(context: DecisionContext) -> ActionData:
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
func _calculate_attack_weight(context: DecisionContext) -> float:
    var weight := base_attack_weight
    weight *= context.aggression
    
    if context.player_health_ratio < low_health_threshold:
        weight *= 1.5
    
    if context.health_ratio < low_health_threshold and context.player_health_ratio > critical_health_threshold:
        weight *= 0.5
    
    return weight

func _calculate_spell_weight(context: DecisionContext) -> float:
    # If no spells are available, return 0 to disable spell casting
    if not best_damage_spell and not best_heal_spell:
        return 0.0
    
    var weight := base_spell_weight
    weight *= context.aggression
    
    if not context.in_attack_range:
        weight *= 1.2
    
    if context.player_health_ratio < low_health_threshold:
        weight *= 1.3
    
    return weight

func _calculate_defend_weight(context: DecisionContext) -> float:
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

func _calculate_heal_weight(context: DecisionContext) -> float:
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


## Move weight should be calculated based on distance to player
## and whether the enemy is in attack range or not.
# We should check if the enemy doesn't have any viable actions other than moving:
# 1. No spell in the inventory could hit the player
# 2. No items that could be used (based on range as well as can_use_on)
# 3. The player is not in attack range
# 4. The player is not in draw range
# 5. All other actions require too much MP or Actions to execute

func _calculate_move_weight(context: DecisionContext) -> float:
    var weight := base_move_weight
    
    # High priority to move if we're not in any useful range
    if not context.in_attack_range and not context.in_spell_range:
        weight *= 2.0
    
    # Lower priority if we can already do useful actions
    if context.in_attack_range or context.in_spell_range:
        weight *= 0.3
    
    # Check if we have no other viable actions
    var has_viable_actions := false
    
    # Can we attack?
    if context.in_attack_range:
        has_viable_actions = true
    
    # Can we cast spells? (Only if we actually have spells available)
    if (battle_character.can_use_spells 
        and context.in_spell_range
        and (best_damage_spell or best_heal_spell)):
        has_viable_actions = true
    
    # If no spells are available at all, increase movement priority
    if not best_damage_spell and not best_heal_spell:
        weight *= 1.5
    
    # If no viable actions, moving becomes essential
    if not has_viable_actions:
        weight *= 3.0
    
    if context.health_ratio > good_health_threshold:
        weight *= context.aggression
    
    return weight

func _calculate_draw_spell_weight(_context: DecisionContext) -> float:
    return 0.1 # TODO: implement draw spell weight calculation :
        # If we don't have any appropriate spells and the player is in draw range,
        # we should consider drawing a spell.
        # We should also consider this as a neutral option for when the player is less of a threat.
        # Higher aggression means we are more likely to Cast instead of Stock once we have drawn a spell,
        # But we will still prefer a regular attack if we are in attack range.

func _calculate_item_weight(context: DecisionContext) -> float:
    var weight := 0.3
    
    # Prioritize items when low on health (for healing items)
    if context.health_ratio < low_health_threshold:
        weight *= 2.0
    elif context.health_ratio > good_health_threshold:
        weight *= 0.5
    
    # Increase weight if we have low mana (for MP items)
    if context.mana_ratio < 0.3:
        weight *= 1.5
    
    return weight

# Can execute functions
func _can_execute_attack(context: DecisionContext) -> bool:
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
func _can_execute_cast_spell(context: DecisionContext) -> bool:
    if not battle_character.can_use_spells:
        return false
    
    if not context.in_spell_range:
        return false
    
    # Check if we have any spell to cast (precalculated)
    if not best_spell_to_cast:
        return false
    
    # Final check: can we afford this spell?
    return (battle_character.current_mp >= best_spell_to_cast.mp_cost 
            and battle_character.actions_left >= best_spell_to_cast.actions_cost)

func _can_execute_defend(_context: DecisionContext) -> bool:
    return true

func _can_execute_heal(_context: DecisionContext) -> bool:
    return true  # Could add checks for healing items/abilities

func _can_execute_move_towards_player(context: DecisionContext) -> bool:
    return not (context.in_attack_range or context.in_spell_range)

func _can_execute_draw_spell(context: DecisionContext) -> bool:
    return context.mana_ratio < 0.8  # Don't draw spells if mana is high

func _can_execute_use_item(_context: DecisionContext) -> bool:
    return true  # Could add inventory checks

# Execution functions
func _execute_attack() -> void:
    print("Executing attack!")
    # TODO: implement actual attack logic against selected target

func _execute_cast_spell() -> void:
    if not best_spell_to_cast:
        print("ERROR: No spell to cast was precalculated!")
        return
    
    print("Enemy casting spell: " + best_spell_to_cast.item_name)
    
    # Determine target based on spell type
    if best_spell_to_cast.spell_element == BattleEnums.EAffinityElement.HEAL:
        print("Enemy casting heal spell on self")
        # TODO: cast heal spell on self
    else:
        print("Enemy casting damage spell on player target")
        # TODO: cast damage spell on player target

func _execute_defend() -> void:
    print("Executing defend!")
    # TODO: implement defend logic (increase armor class or reduce incoming damage)


func _execute_move_towards_player() -> void:
    print("Executing move towards player!")
    # TODO: implement movement logic towards the closest player

func _execute_draw_spell() -> void:
    print("Executing draw spell!")
    # TODO: implement spell drawing logic from draw_list

func _execute_use_item() -> void:
    print("Executing use item!")
    # TODO: implement item usage logic from inventory

func exit() -> void:
    print("Enemy Think State Exited")
    current_action = ""

func _select_best_spells() -> void:
    # Select best damage and healing spells from available spells
    if not battle_character or not battle_character.inventory:
        return
        
    var available_spells: Array[SpellItem] = []
    for item in battle_character.inventory.get_all_items():
        if item is SpellItem:
            available_spells.append(item as SpellItem)
      # Reset previous selections
    best_damage_spell = null
    best_heal_spell = null
    
    # Find best damage spell (highest maximum potential damage)
    var best_damage_potential := 0.0
    for spell in available_spells:
        if spell.spell_element not in [BattleEnums.EAffinityElement.HEAL, BattleEnums.EAffinityElement.BUFF, BattleEnums.EAffinityElement.DEBUFF]:
            var max_damage := _get_max_dice_total(spell.spell_power_rolls)
            if max_damage > best_damage_potential:
                best_damage_potential = max_damage
                best_damage_spell = spell
    
    # Find best healing spell (highest maximum potential healing)
    var best_heal_potential := 0.0
    for spell in available_spells:
        if spell.spell_element == BattleEnums.EAffinityElement.HEAL:
            var max_heal := _get_max_dice_total(spell.spell_power_rolls)
            if max_heal > best_heal_potential:
                best_heal_potential = max_heal
                best_heal_spell = spell

func _get_best_spell_range() -> float:
    var max_range := 0.0
    
    if best_damage_spell:
        max_range = max(max_range, best_damage_spell.effective_range)
    if best_heal_spell:
        max_range = max(max_range, best_heal_spell.effective_range)
    
    # If no spells are available, return 0 so spell range checks will fail
    # This ensures the enemy will prioritize other actions like moving or defending
    return max_range

func _get_max_dice_total(dice_rolls: Array[DiceRoll]) -> int:
    var total_max := 0
    for dice_roll in dice_rolls:
        total_max += dice_roll.max_possible()
    return total_max