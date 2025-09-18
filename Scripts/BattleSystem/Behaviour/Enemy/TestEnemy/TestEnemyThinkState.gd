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
    super.enter()
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
        match best_item_to_use.element:
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
    if (best_item_to_use and best_item_to_use.element == BattleEnums.EAffinityElement.HEAL and
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
    if best_item_to_use and best_item_to_use.element == BattleEnums.EAffinityElement.HEAL:
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
    elif best_item_to_use.element == BattleEnums.EAffinityElement.HEAL:
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
    
    # Determine target based on item type and spawn projectile
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
            print("Enemy spawning revive projectile for: " + closest_dead_ally.character_name)
            var target_pos: Vector3 = closest_dead_ally.get_parent().global_position
            _spawn_ai_projectile(best_item_to_use, target_pos, closest_dead_ally)
            status = Item.UseStatus.SUCCESS
        else:
            print("ERROR: No dead ally found for revive item!")
            battle_character.spend_actions(best_item_to_use.actions_cost)
            return Item.UseStatus.CANNOT_USE
            
    elif best_item_to_use.element == BattleEnums.EAffinityElement.HEAL:
        # Use SpellHelper's intelligent healing target determination
        var context := get_context()
        var healing_decision := SpellHelper.determine_healing_target(battle_character, context, best_item_to_use)
        var heal_target: BattleCharacter = healing_decision["target"]
        var heal_reason: String = healing_decision["reason"]
        
        if heal_target:
            print("[%s AI] %s - %s" % [battle_character.character_name, heal_reason, heal_target.character_name])
            var target_pos: Vector3 = heal_target.get_parent().global_position
            _spawn_ai_projectile(best_item_to_use, target_pos, heal_target)
            status = Item.UseStatus.SUCCESS
        else:
            print("ERROR: No valid heal target determined!")
            battle_character.spend_actions(best_item_to_use.actions_cost)
            return Item.UseStatus.CANNOT_USE
    else:
        print("Enemy using damage/field item for target")
        if target_character:
            # Check for instant cast first
            if best_item_to_use.should_use_instant_cast():
                print("[AI] Applying %s instantly to %s" % [best_item_to_use.item_name, target_character.character_name])
                
                # For FIELD items that are AOE_FROM_PLAYER with cone/line, apply at AI position with direction
                if (best_item_to_use.item_type == Item.ItemType.FIELD_ITEM and 
                    best_item_to_use.target_type == Item.TargetType.AOE_FROM_PLAYER and 
                    best_item_to_use.area_type in [AreaUtils.SpellAreaType.CONE, AreaUtils.SpellAreaType.LINE]):
                    
                    # Use AI's position as spawn position
                    var spawn_position := Util.project_to_ground(battle_character.get_parent(), 1, 0.002)
                    
                    # Calculate aim direction toward target
                    var target_pos: Vector3 = target_character.get_parent().global_position
                    var aim_direction: Vector3 = (target_pos - spawn_position).normalized()
                    aim_direction.y = 0  # Keep it horizontal
                    
                    # Apply the spell effect directly without projectile
                    var spawned := SpellHelper.create_area_of_effect(best_item_to_use, battle_character, spawn_position, aim_direction)
                    
                    if spawned:
                        print("[AI] Successfully applied %s at AI position" % best_item_to_use.item_name)
                        # Spend resources
                        status = best_item_to_use.activate(battle_character, battle_character, true, true)
                        print("[AI] Activation status: %s" % Util.get_enum_name(Item.UseStatus, status))
                    else:
                        printerr("[AI] Failed to apply %s" % best_item_to_use.item_name)
                        battle_character.spend_actions(best_item_to_use.actions_cost)
                        return Item.UseStatus.CANNOT_USE
                else:
                    # For other instant cast items (BATTLE items), apply directly to target
                    status = best_item_to_use.activate(battle_character, target_character, true, true)
                    print("[AI] Instant cast activation status: %s" % Util.get_enum_name(Item.UseStatus, status))
                    
            elif best_item_to_use.item_type == Item.ItemType.FIELD_ITEM:
                # For other field items, target ground near the player with projectile
                var target_pos: Vector3 = target_character.get_parent().global_position
                _spawn_ai_projectile(best_item_to_use, target_pos, null)
                status = Item.UseStatus.SUCCESS
            else:
                # For battle items, target the character directly with projectile
                var target_pos: Vector3 = target_character.get_parent().global_position
                _spawn_ai_projectile(best_item_to_use, target_pos, target_character)
                status = Item.UseStatus.SUCCESS
        else:
            print("ERROR: No target character available for damage item!")
            # Spend actions even if item fails to prevent infinite loops
            battle_character.spend_actions(best_item_to_use.actions_cost)
            return Item.UseStatus.CANNOT_USE

    print("[%s AI] Item use status: %s" % [battle_character.character_name, str(status)])

    return status

func _spawn_ai_projectile(item: Item, target_pos: Vector3, target_char: BattleCharacter = null) -> void:
    """Spawn a projectile for AI item usage"""
    
    # Create projectile instance
    var projectile_scene := load("res://Scenes/BattleSystem/ItemProjectile.tscn") as PackedScene
    var projectile := projectile_scene.instantiate()
    
    if not projectile:
        printerr("[AI] Failed to create projectile!")
        battle_character.spend_actions(item.actions_cost)
        return
    
    # Position projectile at caster's position (slightly elevated) BEFORE initialization
    var spawn_position: Vector3 = battle_character.get_parent().global_position
    spawn_position.y += 1.5  # Spawn above character
    
    # Add to scene tree first
    get_tree().get_root().add_child(projectile)
    projectile.global_position = spawn_position
    
    # Initialize the projectile AFTER positioning
    projectile.initialize(item, battle_character, target_pos, target_char)
    
    # Configure projectile physics based on item properties
    _configure_ai_projectile_physics(projectile, item)
    
    # Connect projectile signals
    _connect_ai_projectile_signals(projectile, item)
    
    print("[AI] Spawned %s projectile from %s" % [item.item_name, battle_character.character_name])

func _configure_ai_projectile_physics(projectile, item: Item) -> void:
    """Configure projectile physics based on item properties for AI"""
    # Use item's projectile settings directly
    projectile.speed = item.projectile_speed
    projectile.arc_height = item.projectile_arc_height
    projectile.projectile_gravity = item.projectile_gravity
    
    # Apply element-based overrides for special visual effects
    match item.element:
        BattleEnums.EAffinityElement.FIRE:
            # Fire rises slightly - reduce gravity
            projectile.projectile_gravity = item.projectile_gravity * 0.8
        BattleEnums.EAffinityElement.ICE:
            # Ice falls faster - increase gravity
            projectile.projectile_gravity = item.projectile_gravity * 1.2
        BattleEnums.EAffinityElement.ELEC:
            # Lightning is much faster and straighter
            projectile.speed = item.projectile_speed * 2.0
            projectile.arc_height = item.projectile_arc_height * 0.3
        BattleEnums.EAffinityElement.WIND:
            # Wind is faster and has higher arc
            projectile.speed = item.projectile_speed * 1.3
            projectile.arc_height = item.projectile_arc_height * 1.2
    
    # Set travel time based on effective range, speed, and timeout multiplier for guaranteed hit
    var distance: float = Vector2(projectile.start_position.x, projectile.start_position.z).distance_to(Vector2(projectile.target_position.x, projectile.target_position.z))
    var calculated_time: float = max(1.0, distance / projectile.speed * item.projectile_timeout_multiplier)
    projectile.set_travel_time(calculated_time)

func _connect_ai_projectile_signals(projectile, item: Item) -> void:
    """Connect projectile signals for AI usage"""
    # Handle character hits (BATTLE items)
    projectile.OnHitCharacter.connect(_on_ai_projectile_hit_character.bind(item))
    
    # Handle ground hits (FIELD items)
    projectile.OnHitGround.connect(_on_ai_projectile_hit_ground.bind(item))
    
    # Handle projectile cleanup
    projectile.OnProjectileDestroyed.connect(_on_ai_projectile_destroyed)

func _on_ai_projectile_hit_character(character: BattleCharacter, _projectile, item: Item) -> void:
    """Handle AI projectile hitting a character"""
    print("[AI] %s projectile hit %s" % [item.item_name, character.character_name])
    
    # Apply the item effect directly to the character
    var status := item.activate(battle_character, character, true, true)  # Consume item and spend actions
    
    print("[AI] Item activation status: %s" % Util.get_enum_name(Item.UseStatus, status))

func _on_ai_projectile_hit_ground(position: Vector3, _projectile, item: Item) -> void:
    """Handle AI projectile hitting the ground"""
    print("[AI] %s projectile hit ground at %s" % [item.item_name, str(position)])
    
    # For FIELD items, spawn the area of effect at the impact position
    if item.item_type == Item.ItemType.FIELD_ITEM:
        # Create the AOE effect at impact position
        var spawned := SpellHelper.create_area_of_effect(item, battle_character, position, Vector3.FORWARD)
        
        if spawned:
            print("[AI] Successfully spawned AOE effect at impact")
            # Spend the action cost - this will trigger battle callbacks
            battle_character.spend_actions(item.actions_cost)
        else:
            printerr("[AI] Failed to spawn AOE effect at impact")

func _on_ai_projectile_destroyed(_projectile) -> void:
    """Handle AI projectile destruction cleanup"""
    print("[AI] Projectile destroyed")

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
