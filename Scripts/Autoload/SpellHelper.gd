extends Node

var tracked_spell_aoe_nodes: Array = []
@onready var battle_state := GameModeStateMachine.get_node("BattleState") as BattleState

const MASTERY_DRAW_ROLLS := 2

func _ready() -> void:
    Console.add_command("add_item", _add_item_command, ["item_id", "amount"], 2, "Adds an item to the current character's inventory. Usage: add_item <item_id> <amount>")

func _add_item_command(item_id:String, amount:String) -> void:
    print("[ADD_ITEM] Adding item %s with amount %s" % [item_id, amount])
    if not battle_state.current_character:
        return
    
    var item: Item = load("res://Scripts/Data/Items/%s.tres" % item_id)
    if not item:
        print("[ADD_ITEM] Item %s not found!" % item_id)
        return
    battle_state.current_character.inventory.add_item(item, int(amount))

func process_basic_attack(attacker: BattleCharacter, target: BattleCharacter) -> BattleEnums.ESkillResult:
    var attacker_position: Vector3 = attacker.get_parent().global_position
    var target_position: Vector3 = target.get_parent().global_position

    var distance: float = attacker_position.distance_to(target_position)
    var attack_range := attacker.stats.get_stat(CharacterStatEntry.ECharacterStat.AttackRange)
    if distance > attack_range:
        print("[ATTACK] Target out of range!")
        return BattleEnums.ESkillResult.SR_OUT_OF_RANGE

    await battle_state.message_ui.show_messages(["Attack"])

    print("[ATTACK] %s attacks %s with %s (RNG:%d DST:%d)!" % [attacker.character_name, target.character_name, 
        Util.get_enum_name(BattleEnums.EAffinityElement, attacker.basic_attack_element),
        attack_range, distance])
    
    var AC := ceili(target.stats.get_stat(CharacterStatEntry.ECharacterStat.ArmourClass))
    var luck := ceili(attacker.stats.get_stat(CharacterStatEntry.ECharacterStat.Luck))

    # TODO: the basic attack roll should be exposed to the editor
    var attack_roll := DiceRoll.roll(20, 1, AC, luck) # use luck as bonus
    var phys_str := ceili(attacker.stats.get_stat(CharacterStatEntry.ECharacterStat.PhysicalStrength))
    var damage_roll := DiceRoll.roll(20, 1, phys_str)

    var result := target.take_damage(attacker, [damage_roll], attack_roll, attacker.basic_attack_element)
    print("[ATTACK] Result: " + Util.get_enum_name(BattleEnums.ESkillResult, result))
    return result

## This function should be used for spawning radius AOE spells without requiring a BattleCharacter (spawn at position)
func create_area_of_effect(spell: Item, caster: BattleCharacter, spawn_position: Vector3, aim_direction: Vector3 = Vector3.FORWARD) -> bool:
    if spell.area_of_effect_radius == 0 or spell.item_type != Item.ItemType.FIELD_ITEM:
        print("[AOE] Invalid spell for AOE: radius=%.1f, type=%s" % [spell.area_of_effect_radius, Item.ItemType.keys()[spell.item_type]])
        return false

    # Create a persistent SpellArea with trigger behavior, passing the aim direction
    var aoe_area = PersistentSpellArea.new(spell, caster, spawn_position, aim_direction)
    
    print("[AOE] Created spell area with aim direction: %s" % aim_direction)
    
    get_tree().get_root().add_child(aoe_area)

    # we only need to track Sustain spells, so we can remove the spell when a condition is met
    # TODO: spend one action to sustain the spell every turn (optionally) - we need a UI for this
    if spell.ttl_turns == -1:
        tracked_spell_aoe_nodes.push_back(aoe_area)

    print("[AOE] Spawned AOE spell effect at %s" % spawn_position)
    return true

func draw_spell(target_character: BattleCharacter, current_character: BattleCharacter, selected_spell_index: int = 0, cast_immediately: bool = false) -> void:

    if selected_spell_index < 0 or selected_spell_index >= target_character.draw_list.size():
        return

    var drawn_spell := target_character.draw_list[selected_spell_index] as Item

    print("[DRAW] Drawn spell: " + drawn_spell.item_name)

    var draw_bonus_d4s := ceili(current_character.stats.get_stat(CharacterStatEntry.ECharacterStat.Luck))
    var draw_bonus := DiceRoll.roll(4, draw_bonus_d4s).total()

    # Mastery gives 2 d6 rolls for drawing instead of 1, but does not affect the draw_spell bonus
    var rolls := 1
    if drawn_spell.spell_element in current_character.mastery_elements:
        print("[DRAW] Character has mastery for %s" % [Util.get_enum_name(BattleEnums.EAffinityElement, drawn_spell.spell_element)])
        rolls = MASTERY_DRAW_ROLLS

    print("[DRAW] Draw bonus: " + str(draw_bonus))
    var drawn_amount := DiceRoll.roll(6, rolls, draw_bonus).total()
    print("[DRAW] Drawn amount: " + str(drawn_amount))
    

    if cast_immediately:
        await battle_state.message_ui.show_messages([drawn_spell.item_name])
        var status: Item.UseStatus = drawn_spell.activate(current_character, target_character, false)
        print("[DRAW] Final use status: " + Util.get_enum_name(Item.UseStatus, status))
    else:
        
        if current_character.inventory:
            current_character.inventory.add_item(drawn_spell, drawn_amount)
            print("[DRAW] Received %s %s!" % [str(drawn_amount), drawn_spell.item_name])
            var draw_display_string := "%s drew %s %ss"
            if current_character.mastery_elements.has(drawn_spell.spell_element):
                draw_display_string += " (Mastery)"

            await battle_state.message_ui.show_messages([draw_display_string % [current_character.character_name, str(drawn_amount), drawn_spell.item_name]])
        else:
            print("[DRAW] Character has no inventory")

    if not current_character.is_spell_familiar(drawn_spell):
        current_character.add_familiar_spell(drawn_spell)


# Sort based on available actions. Used in the inventory UI to prioritize items that the player probably wants to use based on current context.
func sort_items_by_usefulness(a: Item, b: Item) -> bool:
    var ally_actions := [BattleEnums.EAvailableCombatActions.ALLY, BattleEnums.EAvailableCombatActions.SELF]
    var a_useful := (a.can_use_on_allies and battle_state.available_actions in ally_actions) or (a.can_use_on_enemies and battle_state.available_actions == BattleEnums.EAvailableCombatActions.ENEMY)
    var b_useful := (b.can_use_on_allies and battle_state.available_actions in ally_actions) or (b.can_use_on_enemies and battle_state.available_actions == BattleEnums.EAvailableCombatActions.ENEMY)
    
    if battle_state.available_actions == BattleEnums.EAvailableCombatActions.GROUND:
        var a_cast_anywhere := a.item_type == Item.ItemType.FIELD_ITEM
        var b_cast_anywhere := b.item_type == Item.ItemType.FIELD_ITEM
        if a_cast_anywhere != b_cast_anywhere: return a_cast_anywhere
    
    if a_useful != b_useful: return a_useful
    
    # Prioritize spells based on target's known weaknesses when targeting enemies
    if (battle_state.available_actions == BattleEnums.EAvailableCombatActions.ENEMY 
        and battle_state.player_selected_character 
        and a.item_type in [Item.ItemType.BATTLE_ITEM, Item.ItemType.FIELD_ITEM] and b.item_type in [Item.ItemType.BATTLE_ITEM, Item.ItemType.FIELD_ITEM]):
        
        var a_spell := a
        var b_spell := b
        var target_internal_name := battle_state.player_selected_character.character_internal_name
        
        # Get affinity priorities (WEAK=0, NEUTRAL=1, RESIST=2, IMMUNE=3, REFLECT=4, ABSORB=5)
        var a_affinity_priority := 1
        var b_affinity_priority := 1
        
        if AffinityLog.is_affinity_logged(target_internal_name, a_spell.spell_element):
            var a_affinity := AffinityLog.get_affinity(target_internal_name, a_spell.spell_element)
            a_affinity_priority = a_affinity as int
        
        if AffinityLog.is_affinity_logged(target_internal_name, b_spell.spell_element):
            var b_affinity := AffinityLog.get_affinity(target_internal_name, b_spell.spell_element)
            b_affinity_priority = b_affinity as int
        
        # Prioritize lower priority values (WEAK first, then NEUTRAL, etc.)
        if a_affinity_priority != b_affinity_priority: 
            return a_affinity_priority < b_affinity_priority
    
    if a.item_type in [Item.ItemType.BATTLE_ITEM, Item.ItemType.FIELD_ITEM] and b.item_type in [Item.ItemType.BATTLE_ITEM, Item.ItemType.FIELD_ITEM]:
        var a_spell := a
        var b_spell := b
        if battle_state.available_actions in ally_actions:
            var priority_elements := [BattleEnums.EAffinityElement.HEAL, BattleEnums.EAffinityElement.BUFF]
            var a_priority := a_spell.spell_element in priority_elements
            var b_priority := b_spell.spell_element in priority_elements
            if a_priority != b_priority: return a_priority
        return a_spell.spell_element < b_spell.spell_element
    
    return false

# Enhanced item selection system for AI and other systems
# Returns a dictionary with keys: "damage", "heal", "best" with corresponding Item or null
func select_best_items_for_context(character: BattleCharacter, context: AIDecisionContext) -> Dictionary[String, Item]:
    """
    Select the best items from a character's inventory based on context and effectiveness.
    Returns a dictionary with 'damage', 'heal', and 'best' keys.
    """
    if not character or not character.inventory:
        return {"damage": null, "heal": null, "best": null}
    
    var available_items: Array[Item] = []
    for item in character.inventory.get_items():
        var res_item := item as Item
        if res_item and res_item.actions_cost <= character.actions_left:
            if res_item.mp_cost <= character.current_mp:
                # Filter revive items based on whether there are dead allies
                if res_item.only_on_dead_characters:
                    # Only include revive items if there are dead allies
                    if context.has_dead_allies:
                        available_items.append(res_item)
                else:
                    # Include non-revive items normally
                    available_items.append(res_item)
    
    if available_items.is_empty():
        return {"damage": null, "heal": null, "best": null}
    
    # Sort items by general usefulness first
    available_items.sort_custom(sort_items_by_usefulness)
    
    # Separate items by type and calculate effectiveness scores
    var damage_items: Array[Item] = []
    var heal_items: Array[Item] = []
    var revive_items: Array[Item] = []
    
    for item in available_items:
        if item.only_on_dead_characters:
            revive_items.append(item)
        elif item.spell_element == BattleEnums.EAffinityElement.HEAL:
            heal_items.append(item)
        elif item.spell_element not in [BattleEnums.EAffinityElement.BUFF, BattleEnums.EAffinityElement.DEBUFF]:
            damage_items.append(item)
    
    # Calculate effectiveness scores and find best items
    var best_damage_item: Item = null
    var best_heal_item: Item = null
    var best_revive_item: Item = null
    var best_damage_score := 0.0
    var best_heal_score := 0.0
    var best_revive_score := 0.0
    
    for item in damage_items:
        var score := calculate_item_effectiveness_score(item, character, context)
        if score > best_damage_score:
            best_damage_score = score
            best_damage_item = item
    
    for item in heal_items:
        var score := calculate_item_effectiveness_score(item, character, context)
        if score > best_heal_score:
            best_heal_score = score
            best_heal_item = item
    
    for item in revive_items:
        var score := calculate_item_effectiveness_score(item, character, context)
        if score > best_revive_score:
            best_revive_score = score
            best_revive_item = item
    
    # Determine which item to use based on context
    var best_item: Item = null
    # Use a reasonable default for low_health_threshold if not available
    var low_health_threshold: float = 0.4
    
    # Priority 1: Revive dead allies (highest priority)
    if context.has_dead_allies and best_revive_item:
        best_item = best_revive_item
    # Priority 2: Heal critically injured allies (aggression-based)
    elif (context.critically_injured_ally_count > 0 and best_heal_item and 
          context.aggression < 0.7):  # Low to medium aggression prioritizes healing
        best_item = best_heal_item
    # Priority 3: Heal self when critically low (even at high aggression)
    elif (context.health_ratio < low_health_threshold and best_heal_item):
        best_item = best_heal_item
    # Priority 4: Damage items (high aggression or no healing needed)
    elif best_damage_item:
        best_item = best_damage_item
    # Priority 5: Heal injured allies when no better options (low aggression only)
    elif (context.injured_ally_count > 0 and best_heal_item and 
          context.aggression < 0.4):  # Only very low aggression uses healing for minor injuries
        best_item = best_heal_item
    # Priority 6: Regular healing as fallback
    elif best_heal_item:
        best_item = best_heal_item
    
    return {
        "damage": best_damage_item,
        "heal": best_heal_item,
        "revive": best_revive_item,
        "best": best_item
    }

func determine_healing_target(character: BattleCharacter, context: AIDecisionContext, heal_item: Item) -> Dictionary:
    """
    Determines the best healing target based on selfishness (aggression), distance, and need.
    
    Selfishness System:
    - Low aggression (0.0-0.3): Highly altruistic, prioritizes allies over self
    - Medium aggression (0.3-0.7): Balanced, considers both self and allies
    - High aggression (0.7-1.0): Selfish, prioritizes self-preservation
    
    Distance Factor:
    - Closer allies are more likely to be healed
    - Out-of-range allies are never targeted
    
    Emergency Override:
    - Critical health always takes priority regardless of aggression
    
    Returns a dictionary with 'target' (BattleCharacter) and 'reason' (String) keys.
    """
    if not heal_item or not character:
        return {"target": null, "reason": "No character or heal item"}
    
    var my_health_ratio := context.health_ratio
    var my_position: Vector3 = character.get_parent().global_position
    
    # Calculate selfishness factor based on aggression (higher aggression = more selfish)
    # 0.0 aggression = 100% altruistic, 1.0 aggression = 100% selfish
    var selfishness: float = context.aggression
    
    # If we have no injured allies, heal self
    if context.injured_ally_count == 0 or not context.most_injured_ally:
        return {"target": character, "reason": "No injured allies available"}
    
    var ally_health_ratio := context.lowest_ally_health_ratio
    var ally_distance: float = my_position.distance_to(context.most_injured_ally.get_parent().global_position)
    
    # Check if ally is in range
    var ally_in_range := ally_distance <= heal_item.effective_range
    
    if not ally_in_range:
        return {"target": character, "reason": "Most injured ally out of range (%.1f > %.1f)" % [ally_distance, heal_item.effective_range]}
    
    # Critical thresholds
    var critical_threshold := 0.25
    
    # Emergency cases - always prioritize the most critical
    if ally_health_ratio < critical_threshold and my_health_ratio >= critical_threshold:
        return {"target": context.most_injured_ally, "reason": "Ally critically injured (%.1f%% HP)" % (ally_health_ratio * 100)}
    
    if my_health_ratio < critical_threshold and ally_health_ratio >= critical_threshold:
        return {"target": character, "reason": "Self critically injured (%.1f%% HP)" % (my_health_ratio * 100)}
    
    # Both are critical - choose based on who's worse
    if ally_health_ratio <= critical_threshold and my_health_ratio <= critical_threshold:
        if ally_health_ratio <= my_health_ratio:
            return {"target": context.most_injured_ally, "reason": "Ally more critical than self"}
        else:
            return {"target": character, "reason": "Self more critical than ally"}
    
    # Standard healing decision based on selfishness
    # Calculate "need difference" - how much worse off the ally is compared to us
    var need_difference: float = my_health_ratio - ally_health_ratio
    
    # Distance penalty factor (closer allies are more likely to be healed)
    var max_heal_range: float = heal_item.effective_range
    var distance_factor: float = 1.0 - (ally_distance / max_heal_range)  # 1.0 at distance 0, 0.0 at max range
    
    # Selfishness threshold calculation
    # Lower aggression = more willing to heal allies
    # Higher need difference = more willing to heal allies
    # Closer allies = more willing to heal allies
    var heal_ally_threshold: float = selfishness - (need_difference * 2.0) - (distance_factor * 0.3)
    
    # Debug information
    var debug_info := "Selfishness: %.2f, Need diff: %.2f, Distance factor: %.2f, Threshold: %.2f" % [
        selfishness, need_difference, distance_factor, heal_ally_threshold
    ]
    
    print("[HEAL TARGET] %s considering: Self(%.1f%% HP) vs %s(%.1f%% HP, %.1f units away)" % [
        character.character_name,
        my_health_ratio * 100,
        context.most_injured_ally.character_name,
        ally_health_ratio * 100,
        ally_distance
    ])
    
    if heal_ally_threshold < 0.5:  # Threshold for choosing ally over self
        return {"target": context.most_injured_ally, "reason": "Altruistic healing - " + debug_info}
    else:
        return {"target": character, "reason": "Selfish healing - " + debug_info}

func calculate_item_effectiveness_score(item: Item, character: BattleCharacter, context: AIDecisionContext) -> float:
    """
    Calculate how effective an item is considering power, efficiency, and stack count.
    Returns a score that balances raw effectiveness with resource management.
    """
    if not item or not character.inventory:
        return 0.0
    
    var stack_count := character.inventory.get_item_count(item.item_id)
    if stack_count <= 0:
        return 0.0
    
    # Calculate base power/effectiveness
    var max_power := DiceRoll.max_possible_all(item.spell_power_rolls)
    if max_power <= 0:
        max_power = 1  # Fallback for utility items
    
    # Base efficiency calculation
    var action_efficiency: float = float(max_power) / max(1, item.actions_cost)
    var mp_efficiency: float = float(max_power) / max(1, item.mp_cost) if item.mp_cost > 0 else action_efficiency
    
    # Stack count factor - more items = more willing to use
    var stack_factor: float
    if stack_count >= 10:
        stack_factor = 1.5  # Plenty of this item, use freely
    elif stack_count >= 5:
        stack_factor = 1.2  # Good amount, comfortable using
    elif stack_count >= 3:
        stack_factor = 1.0  # Moderate amount, neutral
    elif stack_count == 2:
        stack_factor = 0.7  # Low count, more conservative
    else:  # stack_count == 1
        stack_factor = 0.4  # Last item, very conservative
    
    # Aggression affects resource conservation vs raw power preference
    var aggression_power_weight: float = lerp(0.3, 0.7, context.aggression)  # High aggression = prefer raw power
    var aggression_efficiency_weight: float = lerp(0.7, 0.3, context.aggression)  # Low aggression = prefer efficiency
    var aggression_conservation_weight: float = lerp(0.8, 0.2, context.aggression)  # Low aggression = more conservative
    
    # Target weakness bonus (if targeting enemies)
    var weakness_bonus := 1.0
    # For enemy AI, we can look up the target from the battle_state or pass it through context
    var target_character: BattleCharacter = null
    
    # Try to get target from battle state for enemy AI
    if battle_state and battle_state.current_character and battle_state.current_character.character_type == BattleEnums.ECharacterType.ENEMY:
        # For enemy AI, target players
        var players := get_tree().get_nodes_in_group("Player")
        if not players.is_empty():
            var closest_player := players.front() as Node3D
            target_character = closest_player.get_node("BattleCharacter") as BattleCharacter
    elif battle_state and battle_state.player_selected_character:
        # For player AI/assistance, use selected target
        target_character = battle_state.player_selected_character
    
    if target_character and target_character.character_type == BattleEnums.ECharacterType.ENEMY:
        if item.item_type in [Item.ItemType.BATTLE_ITEM, Item.ItemType.FIELD_ITEM]:
            var target_internal_name := target_character.character_internal_name
            if AffinityLog.is_affinity_logged(target_internal_name, item.spell_element):
                var affinity := AffinityLog.get_affinity(target_internal_name, item.spell_element)
                match affinity:
                    BattleEnums.EAffinityType.WEAK:
                        weakness_bonus = 2.0  # Double effectiveness against weak targets
                    BattleEnums.EAffinityType.RESIST:
                        weakness_bonus = 0.5  # Half effectiveness against resistant targets
                    BattleEnums.EAffinityType.IMMUNE, BattleEnums.EAffinityType.ABSORB, BattleEnums.EAffinityType.REFLECT:
                        weakness_bonus = 0.1  # Very low score for ineffective attacks
    
    # Combined score
    var base_score: float = (max_power * aggression_power_weight) + \
                          (action_efficiency * aggression_efficiency_weight) + \
                          (mp_efficiency * aggression_efficiency_weight)
    
    # Apply stack factor with aggression consideration and weakness bonus
    var final_score: float = base_score * lerp(stack_factor, 1.0, 1.0 - aggression_conservation_weight) * weakness_bonus

    print("[ITEM SCORE] %s: Power=%d, Stack=%d, Weakness=%.1fx, Score=%.2f (base=%.2f, factor=%.2f)" % [
        item.item_name, max_power, stack_count, weakness_bonus, final_score, base_score, stack_factor])
    
    return final_score
