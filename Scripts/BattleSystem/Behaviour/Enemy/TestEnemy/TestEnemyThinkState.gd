## TODO: Most of this class needs to be moved to a generic Enemy Think State,
# where only stuff specific to this enemy is here.
# Helper functions should be moved to separate utility classes where appropriate too.



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

@export_group("Aggression Settings")
@export var base_aggression: float = 0.5
@export var min_aggression: float = 0.1
@export var max_aggression: float = 1.0

var current_aggression: float = 0.5
var last_player_hp_ratio: float = 1.0
var last_damage_dealt: int = 0

var best_damage_spell: BaseInventoryItem = null
var best_heal_spell: BaseInventoryItem = null
var best_spell_to_cast: BaseInventoryItem = null

@onready var battle_character := state_machine.get_owner().get_node("BattleCharacter") as BattleCharacter

var available_actions: Array[AIActionData] = []

# TODO: replace this with an array so we can have multiple targets (e.g. for AOE spells)
var target_character: BattleCharacter = null
var ally_target_character: BattleCharacter = null

func _ready() -> void:
    battle_character.OnLeaveBattle.connect(_on_leave_battle)
    current_aggression = base_aggression
    _initialize_actions()
    _connect_aggression_signals()

func _on_leave_battle() -> void:
    if active:
        # stop thinking
        Transitioned.emit(self, "IdleState")

func enter() -> void:
    _make_decision()
    _aggression_check()

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
    available_actions.append(AIActionData.new(
        "attack",
        _calculate_attack_weight,
        _execute_attack,
        _can_execute_attack,
        -0.1 # decrease aggression slightly for attack action
    ))
    # Cast spell action
    available_actions.append(AIActionData.new(
        "cast_spell",
        _calculate_spell_weight,
        _execute_cast_spell,
        _can_execute_cast_spell,
        -0.2
    ))
    
    # Heal ally action
    # TODO: also allow buffing allies
    available_actions.append(AIActionData.new(
        "heal_ally",
        _calculate_heal_ally_weight,
        _execute_heal_ally,
        _can_execute_heal_ally,
        0.0
    ))
    
    # Defend action
    available_actions.append(AIActionData.new(
        "defend",
        _calculate_defend_weight,
        _execute_defend,
        _can_execute_defend,
        0.1
    ))
    
    # Move towards player action
    available_actions.append(AIActionData.new(
        "move_towards_player",
        _calculate_move_weight,
        _execute_move_towards_player,
        _can_execute_move_towards_player
    ))
    
    # Draw spell action
    available_actions.append(AIActionData.new(
        "draw_spell",
        _calculate_draw_spell_weight,
        _execute_draw_spell,
        _can_execute_draw_spell,
        -0.2
    ))
    
    # Use item action
    available_actions.append(AIActionData.new(
        "use_item",
        _calculate_item_weight,
        _execute_use_item,
        _can_execute_use_item,
        0.1
    ))

func _make_decision() -> void:
    # Safety check - ensure we have a valid battle character and actions left
    if not battle_character or not battle_character.character_active:
        print("[ERROR] %s trying to think when not active, transitioning to idle" % battle_character.character_name)
        Transitioned.emit(self, "IdleState")
        return
    
    if battle_character.actions_left <= 0:
        print("[ERROR] %s has no actions left, transitioning to idle" % battle_character.character_name)
        Transitioned.emit(self, "IdleState")
        return
    
    var context := _get_context()
    _update_spell_selection(context)
    var chosen_action := _select_best_action(context)
    
    if not chosen_action:
        print("[CRITICAL ERROR] %s failed to select any action!" % battle_character.character_name)
        _debug_action_selection_failure(context)
        
        # Fallback: spend one action and transition to idle to prevent infinite loops
        print("[FALLBACK] %s spending 1 action as emergency fallback" % battle_character.character_name)
        battle_character.spend_actions(1)
        return

    chosen_action.execute()
    print("%s executed action: %s" % [battle_character.character_name, chosen_action.name])

## TODO: this can be moved to a generic Enemy Think State
## as the context is not specific to any enemy.
func _get_context() -> AIDecisionContext:
    var current_hp := battle_character.current_hp
    var max_hp: float = max(0.0, battle_character.stats.get_stat(CharacterStatEntry.ECharacterStat.MaxHP))
    var current_mp := battle_character.current_mp
    var max_mp: float = max(0.0, battle_character.stats.get_stat(CharacterStatEntry.ECharacterStat.MaxMP))
    
    var attack_range: float = battle_character.stats.get_stat(CharacterStatEntry.ECharacterStat.AttackRange)
    var spell_range: float = _get_best_spell_range()

    # Find closest player as target
    # NOTE: this should never be null, since there will always be at least one player in the battle.
    target_character = _find_closest_player()

    # Find most injured ally for healing decisions
    ally_target_character = _find_most_injured_ally()

    var current_player_hp := target_character.current_hp
    var current_player_max_hp: float = max(0.0, target_character.stats.get_stat(CharacterStatEntry.ECharacterStat.MaxHP))

    var health_ratio := current_hp / max_hp
    var mana_ratio := current_mp / max_mp
    var player_health_ratio := current_player_hp / current_player_max_hp
    var distance_to_target: float = battle_character.get_parent().global_position.distance_to(
        target_character.get_parent().global_position)

    var in_attack_range: bool = distance_to_target <= attack_range
    var in_spell_range: bool = distance_to_target <= spell_range

    # Check if we can reach allies with heal spells
    var ally_in_heal_range := false
    if ally_target_character and best_heal_spell:
        var ally_distance: float = battle_character.get_parent().global_position.distance_to(
            ally_target_character.get_parent().global_position)
        ally_in_heal_range = ally_distance <= best_heal_spell.effective_range

    # Extend spell range check to include ally healing range
    in_spell_range = in_spell_range or ally_in_heal_range    # Ally healing context
    var ally_needs_healing := false
    var ally_health_ratio := 1.0
    
    if ally_target_character:
        var ally_current_hp := ally_target_character.current_hp
        var ally_max_hp: float = max(0.0, ally_target_character.stats.get_stat(CharacterStatEntry.ECharacterStat.MaxHP))
        ally_health_ratio = ally_current_hp / ally_max_hp
        ally_needs_healing = ally_health_ratio < low_health_threshold

    print("=== %s Decision Context ===" % battle_character.character_name)
    print("HP: %d/%d (%.1f%%)" % [current_hp, max_hp, current_hp / max_hp * 100])
    print("MP: %d/%d (%.1f%%)" % [current_mp, max_mp, current_mp / max_mp * 100])
    print("Actions Left: %d" % battle_character.actions_left)
    print("Aggression: %.2f" % current_aggression)
    
    if best_damage_spell:
        print("Best damage spell: %s (MP: %d, Range: %.1f, Actions: %d)" % [best_damage_spell.item_name, best_damage_spell.mp_cost, best_damage_spell.effective_range, best_damage_spell.actions_cost])
    if best_heal_spell:
        print("Best heal spell: %s (MP: %d, Range: %.1f, Actions: %d)" % [best_heal_spell.item_name, best_heal_spell.mp_cost, best_heal_spell.effective_range, best_heal_spell.actions_cost])

    print("Distance to target: %.1f" % distance_to_target)
    print("In attack range: %s | In spell range: %s" % [in_attack_range, in_spell_range])
    
    if ally_target_character:
        print("Most injured ally: %s (%.1f%% HP)" % [ally_target_character.character_name, ally_health_ratio * 100])

    print("=============================")

    return AIDecisionContext.new(
        health_ratio,
        mana_ratio,
        player_health_ratio,
        distance_to_target,
        in_attack_range,
        in_spell_range,
        current_aggression,
        ally_needs_healing,
        ally_target_character,
        ally_health_ratio
    )

func _update_spell_selection(context: AIDecisionContext) -> void:
    # First, select best available spells from inventory

    # TODO: items also have a count, which we should consider
    # when selecting spells. Higher aggression would mean the enemy is more likely to choose
    # a spell they have only a few charges of, while lower aggression prioritises spells with more charges. 
    if battle_character and battle_character.inventory:
        var available_spells: Array[BaseInventoryItem] = []
        for item in battle_character.inventory.get_items():
            var res_item := item as BaseInventoryItem
            if res_item:
                # Filter out spells that cost more actions than we have
                if res_item.actions_cost <= battle_character.actions_left:
                    available_spells.append(res_item)
                else:
                    print("[SPELL FILTER] %s costs %d actions but only have %d - skipping" % [
                        res_item.item_name, res_item.actions_cost, battle_character.actions_left])
        
        # Reset previous selections
        best_damage_spell = null
        best_heal_spell = null
        # Find best damage and heal spells based on efficiency, not just raw power
        var best_damage_efficiency := 0.0
        var best_heal_efficiency := 0.0
        
        for spell in available_spells:
            var max_power := DiceRoll.max_possible_all(spell.spell_power_rolls)
            var efficiency: float = _calculate_spell_efficiency(spell, max_power, context.aggression)
            
            if spell.spell_element == BattleEnums.EAffinityElement.HEAL:
                if efficiency > best_heal_efficiency:
                    best_heal_efficiency = efficiency
                    best_heal_spell = spell
            elif spell.spell_element not in [BattleEnums.EAffinityElement.BUFF, BattleEnums.EAffinityElement.DEBUFF]:
                if efficiency > best_damage_efficiency:
                    best_damage_efficiency = efficiency
                    best_damage_spell = spell
    
        # Then, choose which spell to cast based on context
        best_spell_to_cast = null
        if not best_damage_spell and not best_heal_spell:
            return
        
        # Choose heal spell if we or an ally need healing
        if (context.health_ratio < low_health_threshold or context.ally_needs_healing) and best_heal_spell:
            best_spell_to_cast = best_heal_spell
        elif best_damage_spell:
            best_spell_to_cast = best_damage_spell
        elif best_heal_spell:
            best_spell_to_cast = best_heal_spell

        if best_spell_to_cast:
            print("[%s AI] Best spell to cast: %s (MP: %d, Range: %.1f, Actions: %d)" % [
                battle_character.character_name,
                best_spell_to_cast.item_name,
                best_spell_to_cast.mp_cost,
                best_spell_to_cast.effective_range,
                best_spell_to_cast.actions_cost
            ])
        else:
            print("[%s AI] No spells available to cast!" % battle_character.character_name)

func _select_best_action(context: AIDecisionContext) -> AIActionData:
    var valid_actions: Array[AIActionData] = []
    
    # Filter actions that can be executed and calculate their weights
    for action in available_actions:
        if action.can_execute(context):
            action.calculate_weight(context)
            if action.current_weight > 0.0:
                valid_actions.append(action)
    
    if valid_actions.is_empty():
        print("[ERROR] No valid actions available!")
        return null
    
    # Weighted random selection
    var total_weight := 0.0
    for action in valid_actions:
        total_weight += action.current_weight
    
    if total_weight <= 0.0:
        print("[ERROR] Total weight is zero or negative: %.2f" % total_weight)
        # Fallback: just pick the first valid action
        return valid_actions[0]
    
    var random_value := randf() * total_weight
    var current_weight := 0.0
    
    for action in valid_actions:
        current_weight += action.current_weight
        if random_value <= current_weight:
            print("Selected action: %s (weight: %.2f)" % [action.name, action.current_weight])
            return action
    
    # Final fallback
    print("[WARNING] Weight selection failed, using first valid action")
    return valid_actions[0]

# Weight calculation functions
func _calculate_attack_weight(context: AIDecisionContext) -> float:
    var weight := base_attack_weight
    weight *= context.aggression
    
    if context.player_health_ratio < low_health_threshold:
        weight *= 1.5
    
    if context.health_ratio < low_health_threshold and context.player_health_ratio > critical_health_threshold:
        weight *= 0.5
    
    return weight

func _calculate_spell_weight(context: AIDecisionContext) -> float:
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

func _calculate_defend_weight(context: AIDecisionContext) -> float:
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

func _calculate_heal_weight(context: AIDecisionContext) -> float:
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

func _calculate_heal_ally_weight(context: AIDecisionContext) -> float:
    var weight := base_heal_weight
    
    # No ally to heal
    if not context.ally_needs_healing or not context.most_injured_ally:
        return 0.0
    
    # Prioritize ally healing based on how badly they need it
    if context.ally_health_ratio < critical_health_threshold:
        weight *= 4.0  # Very high priority
    elif context.ally_health_ratio < low_health_threshold:
        weight *= 2.5
    else:
        weight *= 0.1  # Low priority if ally is in good health
    
    # If we're also low on health, reduce ally healing priority slightly
    if context.health_ratio < low_health_threshold:
        weight *= 0.7
    
    # Don't heal allies when player is very vulnerable (finish them instead)
    if context.player_health_ratio < critical_health_threshold:
        weight *= 0.2
    
    return weight


## Move weight should be calculated based on distance to player
## and whether the enemy is in attack range or not.
# We should check if the enemy doesn't have any viable actions other than moving:
# 1. No spell in the inventory could hit the player
# 2. No items that could be used (based on range as well as can_use_on)
# 3. The player is not in attack range
# 4. The player is not in draw range
# 5. All other actions require too much MP or Actions to execute

func _calculate_move_weight(context: AIDecisionContext) -> float:
    var weight := base_move_weight
    
    # High priority to move if we're not in any useful range
    if not context.in_attack_range and not context.in_spell_range:
        weight *= 3.0  # Increased multiplier since this means we have no other actions
    else:
        # Lower priority if we can already do useful actions
        weight *= 0.3
    
    # If no spells are available at all, increase movement priority slightly
    if not best_damage_spell and not best_heal_spell:
        weight *= 1.2
    
    # Healthy enemies are more aggressive about moving
    if context.health_ratio > good_health_threshold:
        weight *= context.aggression
    
    return weight

func _calculate_draw_spell_weight(_context: AIDecisionContext) -> float:
    return 0.1 # TODO: implement draw spell weight calculation :
        # If we don't have any appropriate spells and the player is in draw range,
        # we should consider drawing a spell.
        # We should also consider this as a neutral option for when the player is less of a threat.
        # Higher aggression means we are more likely to Cast instead of Stock once we have drawn a spell,
        # But we will still prefer a regular attack if we are in attack range.

func _calculate_item_weight(context: AIDecisionContext) -> float:
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
func _can_execute_attack(context: AIDecisionContext) -> bool:
    # Check if we have at least 1 action (attacks cost 1 action)
    if battle_character.actions_left < 1:
        return false
    return context.in_attack_range

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
func _can_execute_cast_spell(context: AIDecisionContext) -> bool:
    if not battle_character.can_use_spells:
        return false
    
    # Check if we have any spell to cast (precalculated)
    if not best_spell_to_cast:
        return false
    
    # Determine target and range based on spell type
    var target_distance: float
    if best_spell_to_cast.spell_element == BattleEnums.EAffinityElement.HEAL and context.ally_needs_healing and context.most_injured_ally:
        # Healing spell targeting ally
        target_distance = battle_character.get_parent().global_position.distance_to(
            context.most_injured_ally.get_parent().global_position)
    else:
        # Damage spell or self-heal targeting player or self
        target_distance = context.distance_to_target
    
    # Check if target is in range
    if target_distance > best_spell_to_cast.effective_range:
        return false
    
    # Final check: can we afford this spell?
    return (battle_character.current_mp >= best_spell_to_cast.mp_cost 
            and battle_character.actions_left >= best_spell_to_cast.actions_cost)

func _can_execute_defend(_context: AIDecisionContext) -> bool:
    # Defend costs 1 action
    return battle_character.actions_left >= 1

func _can_execute_heal(_context: AIDecisionContext) -> bool:
    return true  # Could add checks for healing items/abilities

func _can_execute_heal_ally(context: AIDecisionContext) -> bool:
    # Must have a heal spell and valid ally target
    if not best_heal_spell:
        return false
    
    if not context.most_injured_ally or not context.ally_needs_healing:
        return false
    
    # Check if we have enough resources
    if not battle_character.can_use_spells:
        return false
    
    if battle_character.current_mp < best_heal_spell.mp_cost:
        return false
    
    if battle_character.actions_left < best_heal_spell.actions_cost:
        return false
      # Check if ally is in range
    var ally_distance: float = battle_character.get_parent().global_position.distance_to(
        context.most_injured_ally.get_parent().global_position)
    
    return ally_distance <= best_heal_spell.effective_range

func _can_execute_move_towards_player(context: AIDecisionContext) -> bool:
    # Check if we have at least 1 action (movement costs 1 action)
    if battle_character.actions_left < 1:
        return false
    return not (context.in_attack_range or context.in_spell_range)

func _can_execute_draw_spell(context: AIDecisionContext) -> bool:
    # Check if we have at least 1 action (drawing costs 1 action)
    if battle_character.actions_left < 1:
        return false
    return context.mana_ratio < 0.8  # Don't draw spells if mana is high

func _can_execute_use_item(_context: AIDecisionContext) -> bool:
    # Check if we have at least 1 action (item usage typically costs 1 action)
    if battle_character.actions_left < 1:
        return false
    return true  # Could add inventory checks


func _execute_attack() -> void:
    SpellHelper.process_basic_attack(battle_character, target_character)
    battle_character.spend_actions(1)

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

    # TODO: we should factor in the spell's action cost when picking it earlier on.
    battle_character.spend_actions(best_spell_to_cast.actions_cost)

func _execute_heal_ally() -> void:
    if not best_heal_spell or not ally_target_character:
        print("ERROR: No heal spell or ally target available!")
        return
    
    print("Enemy casting heal spell on ally: " + ally_target_character.character_name)
    # Cast heal spell on ally target (enemies don't have an inventory yet, this is TODO)
    SpellHelper.use_item_or_aoe(best_heal_spell, battle_character, ally_target_character, false)

func _execute_defend() -> void:
    print("Executing defend!")
    # TODO: implement defend logic (increase armor class or reduce incoming damage)
    battle_character.spend_actions(1)  # Example: just spend 1 action for now

func _execute_move_towards_player() -> void:
    print("Executing move towards player!")
    # TODO: implement movement logic towards the closest player
    battle_character.spend_actions(1)  # Example: just spend 1 action for now

func _execute_draw_spell() -> void:
    print("Executing draw spell!")
    # TODO: implement spell drawing logic from draw_list
    battle_character.spend_actions(1)  # Example: just spend 1 action for now

func _execute_use_item() -> void:
    print("Executing use item!")
    # TODO: implement item usage logic from inventory
    battle_character.spend_actions(1)  # Example: just spend 1 action for now

func exit() -> void:
    print("Enemy Think State Exited")

func _get_best_spell_range() -> float:
    var max_range := 0.0
    
    if best_damage_spell:
        max_range = max(max_range, best_damage_spell.effective_range)
    if best_heal_spell:
        max_range = max(max_range, best_heal_spell.effective_range)
    
    # If no spells are available, return 0 so spell range checks will fail
    # This ensures the enemy will prioritize other actions like moving or defending
    return max_range


func _calculate_spell_efficiency(spell: BaseInventoryItem, max_power: int, aggression: float) -> float:
    if max_power <= 0:
        return 0.0
    
    # Base efficiency is damage/healing per action point
    var action_efficiency: float = float(max_power) / max(1, spell.actions_cost)
    
    # MP efficiency - how much damage/healing per MP spent
    var mp_efficiency: float = float(max_power) / max(1, spell.mp_cost)
    
    # At low aggression, heavily weight resource conservation
    # At high aggression, prioritize raw power more
    var efficiency_weight_actions: float = lerp(0.7, 0.3, aggression)  # Low aggression = prioritize action conservation
    var efficiency_weight_mp: float = lerp(0.5, 0.2, aggression)      # Low aggression = prioritize MP conservation
    var efficiency_weight_power: float = lerp(0.3, 0.7, aggression)   # High aggression = prioritize raw power
    
    # Combined efficiency score
    var total_efficiency: float = (action_efficiency * efficiency_weight_actions) + \
                           (mp_efficiency * efficiency_weight_mp) + \
                           (max_power * efficiency_weight_power)
    
    print("[SPELL EFFICIENCY] %s: Power=%d, Actions=%d, MP=%d, Aggression=%.1f, Efficiency=%.2f" % [
        spell.item_name, max_power, spell.actions_cost, spell.mp_cost, aggression, total_efficiency])
    
    return total_efficiency

func _find_closest_player() -> BattleCharacter:
    var players := get_tree().get_nodes_in_group("Player")
    if players.is_empty():
        return battle_character.battle_state.current_character
    
    var enemy_pos: Vector3 = battle_character.get_parent().global_position
    var closest_player: Node = null
    var closest_distance := INF
    
    for player in players:
        var distance := enemy_pos.distance_to((player as Node3D).global_position)
        if distance < closest_distance:
            closest_distance = distance
            closest_player = player
    
    return closest_player.get_node("BattleCharacter") as BattleCharacter

func _find_most_injured_ally() -> BattleCharacter:
    var all_enemies := get_tree().get_nodes_in_group("BattleCharacter")
    var most_injured_ally: BattleCharacter = null
    var lowest_health_ratio := 1.0
    
    for node in all_enemies:
        var battle_char := node as BattleCharacter
        if not battle_char:
            continue
        
        # Skip ourselves and non-enemies
        if battle_char == battle_character or battle_char.character_type != BattleEnums.ECharacterType.ENEMY:
            continue
        
        var current_hp := battle_char.current_hp
        var max_hp := battle_char.stats.get_stat(CharacterStatEntry.ECharacterStat.MaxHP)
        
        if max_hp <= 0:
            continue
        
        var health_ratio := current_hp / max_hp
        
        if health_ratio < lowest_health_ratio:
            lowest_health_ratio = health_ratio
            most_injured_ally = battle_char
    
    return most_injured_ally

func _connect_aggression_signals() -> void:
    # Connect to battle signals to track events that affect aggression
    BattleSignalBus.OnDeath.connect(_on_character_death)
    BattleSignalBus.OnTakeDamage.connect(_on_character_take_damage)
    BattleSignalBus.OnSkillResult.connect(_on_skill_result)

func _on_character_death(character: BattleCharacter) -> void:
    # Significantly increase aggression when an ally dies
    if character.character_type == BattleEnums.ECharacterType.ENEMY and character != battle_character:
        _modify_aggression(0.4, "Ally %s was killed!" % character.character_name)

func _on_character_take_damage(character: BattleCharacter, damage: int) -> void:
    # Track damage dealt to players to monitor effectiveness
    if character.character_type == BattleEnums.ECharacterType.PLAYER:
        last_damage_dealt = damage

func _on_skill_result(attacker: BattleCharacter, target: BattleCharacter, result: BattleEnums.ESkillResult, _damage: int) -> void:
    # Only react to our own attacks
    if attacker != battle_character:
        return
    
    # Only care about player targets
    if target.character_type != BattleEnums.ECharacterType.PLAYER:
        return
    
    # Increase aggression when attacks are nullified, reflected, or absorbed
    match result:
        BattleEnums.ESkillResult.SR_REFLECTED:
            _modify_aggression(0.25, "Player reflected our attack!")
        BattleEnums.ESkillResult.SR_ABSORBED:
            _modify_aggression(0.2, "Player absorbed our attack!")
        BattleEnums.ESkillResult.SR_IMMUNE:
            _modify_aggression(0.15, "Player is immune to our damage!")
        BattleEnums.ESkillResult.SR_RESISTED:
            _modify_aggression(0.1, "Player resisted our attack!")
        BattleEnums.ESkillResult.SR_FAIL:
            _modify_aggression(0.05, "Our attack failed!")

func _aggression_check() -> void:
    # Get current player health ratio for comparison
    var current_player_hp := target_character.current_hp if target_character else 0
    var max_player_hp: float = target_character.stats.get_stat(CharacterStatEntry.ECharacterStat.MaxHP) if target_character else 1.0
    var current_player_hp_ratio: float = current_player_hp / max(1.0, max_player_hp)
    
    # Check if player is on low HP and we're close enough to kill
    if current_player_hp_ratio < critical_health_threshold:
        var distance: float = battle_character.get_parent().global_position.distance_to(target_character.get_parent().global_position)
        var attack_range := battle_character.stats.get_stat(CharacterStatEntry.ECharacterStat.AttackRange)
        if distance <= attack_range:
            _modify_aggression(0.15, "Player is critically injured and in range!")
    
    # Check if player health didn't decrease much despite our attacks
    var hp_change: float = last_player_hp_ratio - current_player_hp_ratio
    if last_damage_dealt > 0 and hp_change < 0.05:  # Less than 5% HP change despite dealing damage
        _modify_aggression(0.1, "Player is resilient to our attacks!")
    
    # Update tracking variables
    last_player_hp_ratio = current_player_hp_ratio
    last_damage_dealt = 0

func _modify_aggression(change: float, reason: String = "") -> void:
    var old_aggression := current_aggression
    current_aggression = clamp(current_aggression + change, min_aggression, max_aggression)
    
    if abs(change) > 0.001:  # Only log significant changes
        print("[AGGRESSION] %s: %.2f -> %.2f (%+.2f) - %s" % [
            battle_character.character_name, 
            old_aggression, 
            current_aggression, 
            change, 
            reason
        ])

func _debug_action_selection_failure(context: AIDecisionContext) -> void:
    print("=== DEBUG: Action Selection Failure ===")
    print("Available actions count: %d" % available_actions.size())
    print("Actions left: %d" % battle_character.actions_left)
    print("Current MP: %d" % battle_character.current_mp)
    print("Can use spells: %s" % battle_character.can_use_spells)
    
    print("\nAction evaluation breakdown:")
    for action in available_actions:
        var can_exec := action.can_execute(context)
        var weight := 0.0
        if can_exec:
            weight = action.calculate_weight(context)
        
        print("  %s: can_execute=%s, weight=%.2f" % [action.name, can_exec, weight])
        
        # Additional debug info for specific actions
        match action.name:
            "cast_spell":
                print("    - best_spell_to_cast: %s" % ("null" if not best_spell_to_cast else best_spell_to_cast.item_name))
                if best_spell_to_cast:
                    print("    - spell MP cost: %d (have: %d)" % [best_spell_to_cast.mp_cost, battle_character.current_mp])
                    print("    - spell action cost: %d (have: %d)" % [best_spell_to_cast.actions_cost, battle_character.actions_left])
            "attack":
                print("    - in_attack_range: %s" % context.in_attack_range)
                print("    - distance_to_target: %.1f" % context.distance_to_target)
            "move_towards_player":
                print("    - in_attack_range: %s, in_spell_range: %s" % [context.in_attack_range, context.in_spell_range])
    
    print("=======================================")
