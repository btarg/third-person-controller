class_name TestEnemyThinkState extends EnemyThinkState


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
    # Safety check to prevent infinite loops on state entry
    if not battle_character:
        print("[ERROR] ThinkState entered with no battle_character reference!")
        Transitioned.emit(self, "IdleState")
        return
        
    if battle_character.actions_left <= 0:
        print("[ERROR] %s entered ThinkState with %d actions left, this should not happen! Transitioning to idle" % [battle_character.character_name, battle_character.actions_left])
        print("[DEBUG] Character active: %s, Down turns: %d" % [battle_character.character_active, battle_character.down_turns])
        Transitioned.emit(self, "IdleState")
        return
    
    make_decision()
    _aggression_check()

# TODO: multi-targeting logic for spells and items
# Before we can make decisions, we need to pick player(s) as target(s).
# We will only be able to select multiple targets with a skill which has AOE

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
    # Cast spell/Use item action (unified since both are Item objects)
    available_actions.append(AIActionData.new(
        "use_item",
        _calculate_item_weight,
        _execute_use_item,
        _can_execute_use_item,
        -0.2 # Decrease aggression slightly after using items/spells
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


# Weight calculation functions
func _calculate_attack_weight(context: AIDecisionContext) -> float:
    var weight := base_attack_weight
    weight *= context.aggression
    
    if context.player_health_ratio < low_health_threshold:
        weight *= 1.5
    
    if context.health_ratio < low_health_threshold and context.player_health_ratio > critical_health_threshold:
        weight *= 0.5
    
    if debug_mode:
        print("[%s AI] ATTACK weight: %.3f" % [battle_character.character_name, weight])
    
    return weight

func _calculate_item_weight(context: AIDecisionContext) -> float:
    # If no items are available, return 0 to disable item/spell usage
    if not best_item_to_use:
        return 0.0
    
    var weight := base_spell_weight  # Use spell weight as base since most items are spells
    weight *= context.aggression
    
    # Special handling for revive items - they get extremely high priority
    if best_item_to_use.only_on_dead_characters:
        if context.has_dead_allies:
            weight *= 5.0  # Massive priority boost for revive items when allies are dead
            print("[AI] %s: Applying massive weight boost for revive item %s" % [battle_character.character_name, best_item_to_use.item_name])
        else:
            # This should not happen due to filtering, but safety check
            return 0.0
    else:
        # Trust SpellHelper's item selection and boost weight based on urgency
        match best_item_to_use.spell_element:
            BattleEnums.EAffinityElement.HEAL:
                # For healing items, check if we have a valid target and adjust weight accordingly
                var healing_decision := SpellHelper.determine_healing_target(battle_character, context, best_item_to_use)
                var heal_target: BattleCharacter = healing_decision["target"]
                
                if not heal_target:
                    # No valid healing target, significantly reduce weight
                    weight *= 0.1
                elif heal_target == battle_character:
                    # Self-healing - standard priority based on our health
                    if context.health_ratio < critical_health_threshold:
                        weight *= 5.0  # EMERGENCY self-healing - highest priority!
                    elif context.health_ratio < low_health_threshold:
                        weight *= 3.0  # Urgent self-healing
                    else:
                        weight *= 0.7  # Non-urgent self-healing
                else:
                    # Ally healing - adjust based on ally's condition and our selfishness
                    var ally_health_ratio := context.lowest_ally_health_ratio
                    var selfishness := context.aggression
                    
                    if ally_health_ratio < critical_health_threshold:
                        # Ally is critical - VERY high priority, but still affected by selfishness
                        weight *= (5.0 * (1.0 - selfishness * 0.3))  # Ranges from 5.0 (altruistic) to 3.5 (selfish)
                    elif ally_health_ratio < low_health_threshold:
                        # Ally needs healing - moderate priority, more affected by selfishness
                        weight *= (3.0 * (1.0 - selfishness * 0.6))  # Ranges from 3.0 (altruistic) to 1.2 (selfish)
                    else:
                        # Ally has minor injuries - low priority, heavily affected by selfishness
                        weight *= (1.0 * (1.0 - selfishness))  # Ranges from 1.0 (altruistic) to 0.0 (selfish)
                    
                    if debug_mode:
                        print("[%s AI] Heal weight for ally %s: %.2f (Ally HP: %.1f%%, Selfishness: %.2f)" % [
                            battle_character.character_name, 
                            heal_target.character_name,
                            weight,
                            ally_health_ratio * 100,
                            selfishness
                        ])
            
            BattleEnums.EAffinityElement.MANA:
                # MP items get priority based on how desperately we need mana
                if context.mana_ratio < 0.2:
                    weight *= 2.5  # Emergency MP
                elif context.mana_ratio < 0.4:
                    weight *= 1.5  # Urgent MP
                else:
                    weight *= 0.8  # Non-urgent MP
            
            _: # Damage spells and other items
                # Standard damage/utility items
                if context.player_health_ratio < low_health_threshold:
                    weight *= 1.5  # Target is vulnerable
                    
        # We should always prioritise using an item if we are not in attack range
        if (not context.in_attack_range) and context.in_spell_range:
            weight *= 1.25
    
    # CRITICAL SITUATION BOOST: If multiple characters are critically injured, healing becomes top priority
    if (best_item_to_use and best_item_to_use.spell_element == BattleEnums.EAffinityElement.HEAL and
        ((context.health_ratio < critical_health_threshold and context.critically_injured_ally_count > 0) or
         context.critically_injured_ally_count >= 2)):
        weight *= 2.0  # Extra boost when multiple critical injuries
        if debug_mode:
            print("[%s AI] CRITICAL SITUATION BOOST for healing! Multiple critical injuries detected" % battle_character.character_name)
    
    if debug_mode and best_item_to_use:
        print("[%s AI] ITEM weight: %.3f (Item: %s)" % [battle_character.character_name, weight, best_item_to_use.item_name])
    elif debug_mode:
        print("[%s AI] ITEM weight: 0.0 (No items available)" % battle_character.character_name)
    
    return weight

func _calculate_defend_weight(context: AIDecisionContext) -> float:
    """
    Calculate defend weight with HEALING PRIORITY SYSTEM:
    - If healing is available and needed, defending gets heavily penalized
    - Healing should ALWAYS be preferred over defending when characters are injured
    - Defending is a last resort when no better options exist
    """
    var weight := base_defend_weight
    
    # CRITICAL: If we have healing available and need it, heavily deprioritize defending
    if best_item_to_use and best_item_to_use.spell_element == BattleEnums.EAffinityElement.HEAL:
        # Check if we have a valid healing target
        var healing_decision := SpellHelper.determine_healing_target(battle_character, context, best_item_to_use)
        var heal_target: BattleCharacter = healing_decision["target"]
        
        if heal_target:
            # We can heal someone who needs it - defending is much less important
            if context.health_ratio < critical_health_threshold:
                weight *= 0.1  # Almost never defend when we're critical and can heal
            elif context.health_ratio < low_health_threshold:
                weight *= 0.2  # Rarely defend when we're low and can heal
            elif context.injured_ally_count > 0 and context.lowest_ally_health_ratio < critical_health_threshold:
                weight *= 0.3  # Reduce defending when ally is critical and we can heal
            else:
                weight *= 0.5  # General reduction when healing is available
            
            if debug_mode:
                print("[%s AI] DEFEND weight heavily reduced due to available healing: %.3f (can heal %s)" % [
                    battle_character.character_name, weight, heal_target.character_name
                ])
        else:
            # No valid healing target, normal defend logic
            weight = _apply_normal_defend_logic(context, weight)
    else:
        # No healing available, use normal defend logic
        weight = _apply_normal_defend_logic(context, weight)
    
    if debug_mode:
        print("[%s AI] DEFEND weight: %.3f" % [battle_character.character_name, weight])
    
    return weight

func _apply_normal_defend_logic(context: AIDecisionContext, weight: float) -> float:
    # Only defend when at low health and no better options
    if context.health_ratio < low_health_threshold:
        weight *= 1.2  # Reduced from 1.8 - healing should still be preferred
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

func _calculate_move_weight(context: AIDecisionContext) -> float:
    var weight := base_move_weight
    
    # High priority to move if we're not in any useful range
    if not context.in_attack_range and not context.in_spell_range:
        weight *= 3.0  # Increased multiplier since this means we have no other actions
    else:
        # Lower priority if we can already do useful actions
        weight *= 0.3
    
    # If no items are available at all, increase movement priority slightly
    if not best_damage_item and not best_heal_item:
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

# Can execute functions
func _can_execute_attack(context: AIDecisionContext) -> bool:
    # Check if we have at least 1 action (attacks cost 1 action)
    if battle_character.actions_left < 1:
        return false
    return context.in_attack_range

func _can_execute_use_item(context: AIDecisionContext) -> bool:
    if not battle_character.can_use_spells:
        return false
    
    # Check if we have any item to use (precalculated)
    if not best_item_to_use:
        return false
    
    # Check if we have enough resources
    if battle_character.current_mp < best_item_to_use.mp_cost:
        return false
    
    if battle_character.actions_left < best_item_to_use.actions_cost:
        return false
    
    # Determine target and range based on item type
    var target_distance: float
    
    if best_item_to_use.only_on_dead_characters:
        # Revive item - check distance to closest dead ally
        if not context.has_dead_allies or not context.closest_dead_ally:
            return false
        target_distance = battle_character.get_parent().global_position.distance_to(
            context.closest_dead_ally.get_parent().global_position)
    elif best_item_to_use.spell_element == BattleEnums.EAffinityElement.HEAL:
        # Use SpellHelper's intelligent healing target determination for range checking
        var healing_decision := SpellHelper.determine_healing_target(battle_character, context, best_item_to_use)
        var heal_target: BattleCharacter = healing_decision["target"]
        
        if not heal_target:
            return false
        
        if heal_target == battle_character:
            # Self-heal, always in range
            target_distance = 0.0
        else:
            # Ally heal, check distance
            target_distance = battle_character.get_parent().global_position.distance_to(
                heal_target.get_parent().global_position)
    else:
        # Damage item or self-heal targeting player or self
        target_distance = context.distance_to_target
    
    # Check if target is in range
    if target_distance > best_item_to_use.effective_range:
        return false
    
    return true

func _can_execute_defend(_context: AIDecisionContext) -> bool:
    # Defend costs 1 action
    return battle_character.actions_left >= 1

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


func _execute_attack() -> void:
    SpellHelper.process_basic_attack(battle_character, target_character)
    battle_character.spend_actions(1)

func _execute_use_item() -> Item.UseStatus:
    
    var status := Item.UseStatus.CANNOT_USE

    if not best_item_to_use:
        print("ERROR: No item to use was precalculated!")
        # Spend 1 action as failsafe to prevent infinite loops
        battle_character.spend_actions(1)
        return status
    
    print("Enemy using item: " + best_item_to_use.item_name)
    
    # Store the action cost before activation
    var item_actions_cost: int = best_item_to_use.actions_cost
    
    # Determine target based on item type
    if best_item_to_use.only_on_dead_characters:
        # Revive item - target closest dead ally
        var dead_allies := get_tree().get_nodes_in_group("BattleCharacter")
        var closest_dead_ally: BattleCharacter = null
        var closest_distance := INF
        var my_position: Vector3 = battle_character.get_parent().global_position
        
        for node in dead_allies:
            var battle_char := node as BattleCharacter
            if (battle_char and battle_char != battle_character 
                and battle_char.character_type == BattleEnums.ECharacterType.ENEMY 
                and battle_char.current_hp <= 0):
                var distance: float = my_position.distance_to(battle_char.get_parent().global_position)
                if distance < closest_distance:
                    closest_distance = distance
                    closest_dead_ally = battle_char
        
        if closest_dead_ally:
            print("Enemy using revive item on dead ally: " + closest_dead_ally.character_name)
            status = best_item_to_use.activate(battle_character, closest_dead_ally, false)
        else:
            print("ERROR: No dead ally found for revive item!")
            battle_character.spend_actions(item_actions_cost)
            return Item.UseStatus.CANNOT_USE
            
    elif best_item_to_use.spell_element == BattleEnums.EAffinityElement.HEAL:
        # Use SpellHelper's intelligent healing target determination
        var context := get_context()
        var healing_decision := SpellHelper.determine_healing_target(battle_character, context, best_item_to_use)
        var heal_target: BattleCharacter = healing_decision["target"]
        var heal_reason: String = healing_decision["reason"]
        
        if heal_target:
            print("[%s AI] %s - %s" % [battle_character.character_name, heal_reason, heal_target.character_name])
            status = best_item_to_use.activate(battle_character, heal_target)
        else:
            print("ERROR: No valid heal target determined!")
            battle_character.spend_actions(item_actions_cost)
            return Item.UseStatus.CANNOT_USE
    else:
        print("Enemy using damage item on player target")
        if target_character:
            status = best_item_to_use.activate(battle_character, target_character)
        else:
            print("ERROR: No target character available for damage item!")
            # Spend actions even if item fails to prevent infinite loops
            battle_character.spend_actions(item_actions_cost)
            return Item.UseStatus.CANNOT_USE
    
    # # Ensure actions are spent (defensive programming)
    # # The item's activate() method should handle this, but we add this as backup
    # # Note: We don't double-spend if the item already spent actions correctly
    # if battle_character.actions_left >= item_actions_cost:
    #     printerr("[ERROR] Item %s didn't spend the correct amount of actions! Expected: %d, Actual: %d" % [
    #         best_item_to_use.item_name, 
    #         item_actions_cost, 
    #         battle_character.actions_left
    #     ])
    #     # Force spending the correct amount of actions to prevent infinite loop
    #     battle_character.spend_actions(item_actions_cost)

    print("[%s AI] Item use status: %s" % [battle_character.character_name, str(status)])

    return status

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

func exit() -> void:
    print("[%s AI] Enemy Think State Exited" % battle_character.character_name)
    
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
    # Track damage dealt to friendly players to monitor effectiveness
    if character.character_type != BattleEnums.ECharacterType.ENEMY:
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
            _modify_aggression(0.1, "Player is critically injured and in range!")
    
    # Check if player health didn't decrease much despite our attacks
    var hp_change: float = last_player_hp_ratio - current_player_hp_ratio
    if last_damage_dealt > 0 and hp_change < 0.05:  # Less than 5% HP change despite dealing damage
        _modify_aggression(0.05, "Player is resilient to our attacks!")
    
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