# This class is extended by specific enemy AI implementations.
# Generic shared AI logic should go here.
# TODO: this should be refactored to also hold logic for ally AI as well at some point.

class_name EnemyThinkState extends State

@onready var battle_character := state_machine.get_owner().get_node("BattleCharacter") as BattleCharacter

@export_group("Behavior Weights")
@export var base_attack_weight: float = 1.0
@export var base_spell_weight: float = 0.9
@export var base_move_weight: float = 0.8
@export var base_heal_weight: float = 0.7
@export var base_draw_spell_weight: float = 0.6
@export var base_defend_weight: float = 0.5

@export_group("Health Thresholds")
@export var critical_health_threshold: float = 0.25
@export var low_health_threshold: float = 0.5 # below 50% is "low"
@export var good_health_threshold: float = 0.75

@export_group("Aggression Settings")
@export var base_aggression: float = 0.5
@export var min_aggression: float = 0.1
@export var max_aggression: float = 1.0

var current_aggression: float = 0.5
var last_player_hp_ratio: float = 1.0
var last_damage_dealt: int = 0

var best_damage_item: Item = null
var best_heal_item: Item = null
var best_revive_item: Item = null
var best_item_to_use: Item = null

# TODO: replace this with an array so we can have multiple targets (e.g. for AOE spells)
var target_character: BattleCharacter = null
var ally_target_character: BattleCharacter = null

var available_actions: Array[AIActionData] = []


var debug_mode := ProjectSettings.get_setting("global/print_ai_debug_messages") as bool


func _get_best_item_range() -> float:
    var max_range := 0.0

    if best_damage_item:
        max_range = max(max_range, best_damage_item.effective_range)
    if best_heal_item:
        max_range = max(max_range, best_heal_item.effective_range)
    if best_revive_item:
        max_range = max(max_range, best_revive_item.effective_range)

    # If no items are available, return 0 so spell range checks will fail
    # This ensures the enemy will prioritize other actions like moving or defending
    return max_range

# TODO: replace the dictionary with a custom data class for health assessments
func _assess_ally_health_state() -> Dictionary:
    """
    Comprehensive assessment of all ally health states.
    Returns a dictionary with health statistics and the most injured ally.
    
    This replaces the old single-ally approach with a full health assessment
    that considers all allies and categorizes them by injury severity.
    """
    var all_allies := get_tree().get_nodes_in_group("BattleCharacter")
    var injured_allies: Array[BattleCharacter] = []
    var critically_injured_allies: Array[BattleCharacter] = []
    var most_injured_ally: BattleCharacter = null
    var lowest_health_ratio := 1.0
    
    for node in all_allies:
        var battle_char := node as BattleCharacter
        if not battle_char:
            continue

        # Skip ourselves and non-allies
        if battle_char == battle_character or battle_char.character_type != battle_character.character_type:
            continue

        # Skip dead allies (they need reviving, not healing)
        if battle_char.current_hp <= 0:
            continue

        var current_hp := battle_char.current_hp
        var max_hp := battle_char.stats.get_stat(CharacterStatEntry.ECharacterStat.MaxHP)

        if max_hp <= 0:
            continue

        var health_ratio := current_hp / max_hp

        # Track the most injured ally
        if health_ratio < lowest_health_ratio:
            lowest_health_ratio = health_ratio
            most_injured_ally = battle_char

        # Categorize based on health thresholds
        if health_ratio <= critical_health_threshold:
            critically_injured_allies.append(battle_char)
            injured_allies.append(battle_char)
        elif health_ratio <= low_health_threshold:
            injured_allies.append(battle_char)

    return {
        "injured_ally_count": injured_allies.size(),
        "critically_injured_ally_count": critically_injured_allies.size(),
        "most_injured_ally": most_injured_ally,
        "lowest_ally_health_ratio": lowest_health_ratio,
        "injured_allies": injured_allies,
        "critically_injured_allies": critically_injured_allies
    }

func _find_dead_allies() -> Array[BattleCharacter]:
    var dead_allies: Array[BattleCharacter] = []

    for node in get_tree().get_nodes_in_group("BattleCharacter"):
        var other_character := node as BattleCharacter
        if not other_character:
            continue

        # Skip ourselves and non-enemies
        if other_character == battle_character or other_character.character_type != battle_character.character_type:
            continue

        # Check if ally is dead (HP <= 0)
        if other_character.current_hp <= 0:
            dead_allies.append(other_character)

    return dead_allies

func _find_closest_dead_ally() -> BattleCharacter:
    var dead_allies := _find_dead_allies()
    if dead_allies.is_empty():
        return null
    
    var closest_dead_ally: BattleCharacter = null
    var closest_distance := INF
    var my_position: Vector3 = battle_character.get_parent().global_position
    
    for dead_ally in dead_allies:
        var distance: float = my_position.distance_to(dead_ally.get_parent().global_position)
        if distance < closest_distance:
            closest_distance = distance
            closest_dead_ally = dead_ally
    
    return closest_dead_ally

func get_context() -> AIDecisionContext:
    var current_hp := battle_character.current_hp
    var max_hp: float = max(0.0, battle_character.stats.get_stat(CharacterStatEntry.ECharacterStat.MaxHP))
    var current_mp := battle_character.current_mp
    var max_mp: float = max(0.0, battle_character.stats.get_stat(CharacterStatEntry.ECharacterStat.MaxMP))

    var attack_range: float = battle_character.stats.get_stat(CharacterStatEntry.ECharacterStat.AttackRange)
    var best_item_range: float = _get_best_item_range()

    # Find closest player as target
    # NOTE: this should never be null, since there will always be at least one player in the battle.
    target_character = Util.find_closest_player(battle_character.get_parent())	

    # If null, we have no players to target, so select ourself as target to avoid crashes
    if not target_character:
        target_character = battle_character

    # Comprehensive ally health assessment
    var ally_health_assessment := _assess_ally_health_state()

    # Find dead allies for revive decisions
    var dead_allies := _find_dead_allies()
    var closest_dead_ally := _find_closest_dead_ally()
    var has_dead_allies := not dead_allies.is_empty()
    var dead_ally_count := dead_allies.size()

    var current_player_hp := target_character.current_hp
    var current_player_max_hp: float = max(0.0, target_character.stats.get_stat(CharacterStatEntry.ECharacterStat.MaxHP))

    var health_ratio := current_hp / max_hp
    var mana_ratio := current_mp / max_mp
    var player_health_ratio := current_player_hp / current_player_max_hp
    var distance_to_target: float = battle_character.get_parent().global_position.distance_to(
                            target_character.get_parent().global_position)

    var in_attack_range: bool = distance_to_target <= attack_range
    var in_spell_range: bool = distance_to_target <= best_item_range

    # Check if we can reach allies with heal spells
    var ally_in_heal_range := false
    if ally_target_character and best_heal_item:
        var ally_distance: float = battle_character.get_parent().global_position.distance_to(
                                       ally_target_character.get_parent().global_position)
        ally_in_heal_range = ally_distance <= best_heal_item.effective_range

    # Check if we can reach dead allies with revive spells
    var dead_ally_in_revive_range := false
    if closest_dead_ally and best_revive_item:
        var dead_ally_distance: float = battle_character.get_parent().global_position.distance_to(
                                            closest_dead_ally.get_parent().global_position)
        dead_ally_in_revive_range = dead_ally_distance <= best_revive_item.effective_range

    # Extend spell range check to include ally healing and revive ranges
    in_spell_range = in_spell_range or ally_in_heal_range or dead_ally_in_revive_range

    # Extract ally health information from assessment
    var injured_ally_count: int = ally_health_assessment["injured_ally_count"]
    var critically_injured_ally_count: int = ally_health_assessment["critically_injured_ally_count"] 
    var most_injured_ally_from_assessment: BattleCharacter = ally_health_assessment["most_injured_ally"]
    var lowest_ally_health_ratio: float = ally_health_assessment["lowest_ally_health_ratio"]

    # Update ally_target_character to use the assessment result
    ally_target_character = most_injured_ally_from_assessment

    
    if debug_mode:
    
        print("=== %s Decision Context ===" % battle_character.character_name)
        print("HP: %d/%d (%.1f%%)" % [current_hp, max_hp, current_hp / max_hp * 100])
        print("MP: %d/%d (%.1f%%)" % [current_mp, max_mp, current_mp / max_mp * 100])
        print("Actions Left: %d/%d" % [battle_character.actions_left, battle_character.battle_state.START_ACTIONS])
        print("Aggression: %.2f" % current_aggression)

        if best_damage_item:
            print("Best damage item: %s (MP: %d, Range: %.1f, Actions: %d)" % [best_damage_item.item_name, best_damage_item.mp_cost, best_damage_item.effective_range, best_damage_item.actions_cost])
        if best_heal_item:
            print("Best heal item: %s (MP: %d, Range: %.1f, Actions: %d)" % [best_heal_item.item_name, best_heal_item.mp_cost, best_heal_item.effective_range, best_heal_item.actions_cost])
        if best_revive_item:
            print("Best revive item: %s (MP: %d, Range: %.1f, Actions: %d)" % [best_revive_item.item_name, best_revive_item.mp_cost, best_revive_item.effective_range, best_revive_item.actions_cost])

        print("Distance to target: %.1f" % distance_to_target)
        print("In attack range: %s | In spell range: %s" % [in_attack_range, in_spell_range])

        print("Ally health status:")
        print("  Injured allies: %d | Critically injured: %d" % [injured_ally_count, critically_injured_ally_count])
        if ally_target_character:
            print("  Most injured ally: %s (%.1f%% HP)" % [ally_target_character.character_name, lowest_ally_health_ratio * 100])

        if dead_ally_count > 0:
            print("Dead allies: %d" % dead_ally_count)
            if closest_dead_ally:
                print("Closest dead ally: %s" % closest_dead_ally.character_name)

        print("=============================")

    return AIDecisionContext.new(
        health_ratio,
        mana_ratio,
        player_health_ratio,
        distance_to_target,
        in_attack_range,
        in_spell_range,
        current_aggression,
        injured_ally_count,
        critically_injured_ally_count,
        most_injured_ally_from_assessment,
        lowest_ally_health_ratio,
        false, # has_aoe_targets - placeholder for future AOE implementation
        0,     # aoe_target_count - placeholder for future AOE implementation
        has_dead_allies,
        closest_dead_ally,
        dead_ally_count
    )

func select_best_action(context: AIDecisionContext) -> AIActionData:
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
            
            if debug_mode:
                print("[%s AI] Selected action: %s (weight: %.2f)" % [battle_character.character_name, action.name, action.current_weight])
            
            return action
    
    # Final fallback
    if debug_mode:
        print("[%s AI WARN] Weight selection failed, using first valid action (%s)" % [battle_character.character_name, valid_actions[0].name])
    
    return valid_actions[0]

func make_decision() -> AIActionData:
    # Safety check - ensure we have a valid battle character and actions left
    if not battle_character or not battle_character.character_active:
        print("[ERROR] %s trying to think when not active, transitioning to idle" % battle_character.character_name)
        Transitioned.emit(self, "IdleState")
        return null
    
    if battle_character.actions_left <= 0:
        print("[ERROR] %s has no actions left, transitioning to idle" % battle_character.character_name)
        Transitioned.emit(self, "IdleState")
        return null
    
    var context := get_context()
    _update_item_selection(context)
    var chosen_action := select_best_action(context)
    
    if not chosen_action:
        if debug_mode:
            printerr("[CRITICAL ERROR] %s failed to select any action!" % battle_character.character_name)
            _debug_action_selection_failure(context)
            printerr("[FALLBACK] %s spending actions as emergency fallback and transitioning to idle" % battle_character.character_name)
        # Fallback: spend one action and transition to idle to prevent infinite loops
        battle_character.spend_actions(battle_character.actions_left)
        return null

    # Execute the chosen action
    print("[AI] %s executing action: %s" % [battle_character.character_name, chosen_action.name])
    
    # Store actions before execution for safety check
    var actions_before := battle_character.actions_left
    chosen_action.execute()
    
    # Safety check: ensure actions were actually spent
    if battle_character.actions_left >= actions_before:
        
        if debug_mode:
            printerr("[ERROR] Action %s didn't spend any actions! Force spending 1 action to prevent infinite loop." % chosen_action.name)
        
        battle_character.spend_actions(1)
    
    if debug_mode:
        # Check if we should continue thinking or transition to idle
        if battle_character.actions_left <= 0:
            print("[AI] %s has no more actions left, spend_actions() will handle transition to idle" % battle_character.character_name)
        else:
            # The BattleState will handle putting us back into ThinkState via ready_next_turn()
            print("[AI] %s has %d actions left, BattleState will handle continuation" % [battle_character.character_name, battle_character.actions_left])
    return chosen_action


func _update_item_selection(context: AIDecisionContext) -> void:
    """
    Select the best items from inventory using SpellHelper's enhanced selection system.
    """
    if not battle_character or not battle_character.inventory:
        return
    
    # Use SpellHelper's enhanced item selection with the AIDecisionContext directly
    var item_selection := SpellHelper.select_best_items_for_context(battle_character, context)
    
    # Update our tracking variables
    best_damage_item = item_selection.get("damage", null)
    best_heal_item = item_selection.get("heal", null)
    best_revive_item = item_selection.get("revive", null)
    best_item_to_use = item_selection.get("best", null)
    
    if best_item_to_use and debug_mode:
        print("[%s AI] Best item to use: %s" % [
            battle_character.character_name,
            best_item_to_use.item_name,
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
            "use_item":
                print("    - best_item_to_use: %s" % ("null" if not best_item_to_use else best_item_to_use.item_name))
                if best_item_to_use:
                    print("    - item MP cost: %d (have: %d)" % [best_item_to_use.mp_cost, battle_character.current_mp])
                    print("    - item action cost: %d (have: %d)" % [best_item_to_use.actions_cost, battle_character.actions_left])
            "attack":
                print("    - in_attack_range: %s" % context.in_attack_range)
                print("    - distance_to_target: %.1f" % context.distance_to_target)
            "move_towards_player":
                print("    - in_attack_range: %s, in_spell_range: %s" % [context.in_attack_range, context.in_spell_range])
    
    print("=======================================")
