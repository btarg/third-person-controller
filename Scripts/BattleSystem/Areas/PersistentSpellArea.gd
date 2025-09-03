class_name PersistentSpellArea extends SpellArea

var m_spell_item: Item = null
var m_ttl_turns: int   = -1 # -1 means sustained spell, 0 means we do the effect once and then remove the spell
var m_turns_left: int   = 0
var m_target_spawn_position: Vector3 = Vector3.ZERO

# Track characters currently in the area to handle proper enter/exit logic
var _characters_in_area: Array[BattleCharacter] = []

# Track characters who have spent actions while in this area (prevents re-triggering on movement cancel)
var _has_been_affected: Array[BattleCharacter] = []

var _times_triggered: int = 0

@onready var battle_state := GameModeStateMachine.get_node("BattleState") as BattleState

func _init(spell_item: Item, p_caster: BattleCharacter, spawn_position: Vector3, p_aim_direction: Vector3 = Vector3.FORWARD) -> void:
    super._init(p_caster, spell_item.area_type, spell_item.area_of_effect_radius, spell_item.cone_angle_degrees, spell_item.line_width, p_aim_direction)
    
    m_spell_item = spell_item
    m_ttl_turns = spell_item.ttl_turns
    m_turns_left = m_ttl_turns if m_ttl_turns > 0 else -1
    
    # Store spawn position for later use in direction calculation
    m_target_spawn_position = spawn_position


func _ready() -> void:
    # Call parent _ready first to set up mesh and visuals
    super._ready()
    
    # Debug: Check if mesh was created properly
    if not mesh:
        print("[PERSISTENT SPELL AREA] ERROR: Mesh not created!")
        return
    
    if not mesh.material:
        print("[PERSISTENT SPELL AREA] ERROR: Material not created!")
        return
      # Connect to battle signals
    BattleSignalBus.OnTurnStarted.connect(_on_turn_started)
    
    # Set up area positioning and direction based on area type
    _setup_area_positioning()
    
    # Set visual properties for AOE spell after parent setup
    set_area_colors(Color.RED * 0.3, Color.RED, Color.RED)
    visible = true
    

func _physics_process(_delta: float) -> void:
    var current_nodes: Array[Node3D] = get_nodes_in_area()
    var current_characters: Array[BattleCharacter] = []
    
    # Convert nodes to BattleCharacters for easier tracking
    for node in current_nodes:
        var battle_character := node.get_node_or_null("BattleCharacter") as BattleCharacter
        if battle_character:
            current_characters.append(battle_character)

    # Find newly entered and exited characters
    var newly_entered: Array[BattleCharacter] = current_characters.filter(func(c): return not _characters_in_area.has(c))
    var exited: Array[BattleCharacter] = _characters_in_area.filter(func(c): return not current_characters.has(c))
    
    # Handle newly entered characters
    for character in newly_entered:
        _on_character_entered(character)
    
    # Handle exited characters
    for character in exited:
        _on_character_exited(character)
    
    # Update our tracking array
    _characters_in_area = current_characters

    # Update the parent's selection tracking for UI purposes
    if current_nodes != last_selected_nodes:
        var newly_selected: Array[Node3D] = current_nodes.filter(func(n): return not last_selected_nodes.has(n))
        var deselected: Array[Node3D] = last_selected_nodes.filter(func(n): return not current_nodes.has(n))
        
        if newly_selected.size() > 0:
            for ns_node in newly_selected:
                for child_node in ns_node.get_children():
                    if child_node is SpellAreaNotifier:
                        child_node.OnEntered.emit(self, SpellAreaNotifier.NotificationType.EFFECT_TRIGGER)
                    
        if deselected.size() > 0:
            for ds_node in deselected:
                for child_node in ds_node.get_children():
                    if child_node is SpellAreaNotifier:
                        child_node.OnExited.emit(self, SpellAreaNotifier.NotificationType.EFFECT_TRIGGER)

        last_selected_nodes = current_nodes

func _on_character_entered(battle_character: BattleCharacter) -> void:
    print("[AOE TRIGGER] %s entered AOE area: %s" % [battle_character.character_name, m_spell_item.item_name])
    
    # Check if the character was already affected at their current position (prevents re-triggering on movement cancel)
    if battle_character in _has_been_affected:
        print("[AOE TRIGGER] %s already affected at this position, skipping" % battle_character.character_name)
        return
    
    if _times_triggered == 0:
        # For cone and line spells, exclude the caster since they emanate from the caster
        if (area_type in [AreaUtils.SpellAreaType.CONE, AreaUtils.SpellAreaType.LINE] 
        and caster and battle_character == caster):
            return

    # Check if the character is currently moving (in PlayerMoveState)
    var character_controller := battle_character.character_controller
    if character_controller and character_controller.free_movement:
        # Character is in movement mode - connect to spend actions signal to apply effect when movement is locked in
        print("[AOE TRIGGER] %s entered AOE area while moving" % battle_character.character_name)
        _disconnect_actions_signal(battle_character)
        battle_character.OnSpendActions.connect(_on_spend_actions)
    else:
        # Character is not moving, apply effect immediately
        _apply_effect_to_character(battle_character)

func _on_character_exited(battle_character: BattleCharacter) -> void:
    print("[PERSISTENT SPELL AREA] %s exited AOE area" % battle_character.character_name)
    
    # Disconnect signal when character exits the area
    _disconnect_actions_signal(battle_character)
    
    # Don't clear from _has_been_affected here - only clear when movement is locked in
    # This prevents re-triggering if they exit and re-enter during the same movement

func _on_spend_actions(character: BattleCharacter) -> void:
    print("[PERSISTENT SPELL AREA] %s spent actions" % character.character_name)
    
    # Check if character is still in the area when they spend actions
    if character in _characters_in_area:
        # Character locked in movement while inside area - apply effect
        _apply_effect_to_character(character)
    else:
        # Character locked in movement while outside area - clear from tracking
        # This allows them to be affected again if they re-enter later
        _has_been_affected.erase(character)
        print("[PERSISTENT SPELL AREA] %s cleared from tracking (locked in outside area)" % character.character_name)
    
    # Disconnect the signal after handling the action spend
    _disconnect_actions_signal(character)

func _disconnect_actions_signal(battle_character: BattleCharacter) -> void:
    if battle_character.OnSpendActions.is_connected(_on_spend_actions):
        battle_character.OnSpendActions.disconnect(_on_spend_actions)

func _setup_area_positioning() -> void:
    match m_spell_item.area_type:
        AreaUtils.SpellAreaType.CIRCLE:
            # Position circle at the target spawn position
            global_position = m_target_spawn_position
            print("[PERSISTENT SPELL AREA] Circle positioned at: %s" % global_position)
        AreaUtils.SpellAreaType.CONE:
            # Position cone based on target type
            if m_spell_item.target_type == Item.TargetType.AOE_FROM_TARGET:
                # For AOE_FROM_TARGET, position at the target spawn position
                global_position = m_target_spawn_position
                print("[PERSISTENT SPELL AREA] Cone positioned at target: %s with direction: %s" % [global_position, aim_direction])
            else:
                # For other types (AOE_FROM_PLAYER), position at caster's ground level
                var caster_ground_pos := Util.project_to_ground(caster.get_parent(), 1, 0.002)
                global_position = caster_ground_pos
                
                # Calculate direction from caster to target spawn position for AOE_FROM_PLAYER directional spells
                var direction_to_target := (m_target_spawn_position - caster_ground_pos).normalized()
                if direction_to_target.length() < 0.001:
                    # If spawn position is at caster position, use forward direction
                    direction_to_target = Vector3.FORWARD
                
                aim_direction = Vector3(direction_to_target.x, 0.0, direction_to_target.z).normalized()
                print("[PERSISTENT SPELL AREA] Cone positioned at caster: %s, direction: %s" % [global_position, aim_direction])
            
            update_shader_params()
            
        AreaUtils.SpellAreaType.LINE:
            # Position line based on target type
            if m_spell_item.target_type == Item.TargetType.AOE_FROM_TARGET:
                # For AOE_FROM_TARGET, position at the target spawn position
                global_position = m_target_spawn_position
                print("[PERSISTENT SPELL AREA] Line positioned at target: %s with direction: %s" % [global_position, aim_direction])
            else:
                # For other types (AOE_FROM_PLAYER), position at caster's ground level
                var caster_ground_pos := Util.project_to_ground(caster.get_parent(), 1, 0.002)
                global_position = caster_ground_pos
                
                # Calculate direction from caster to target spawn position for AOE_FROM_PLAYER directional spells
                var direction_to_target := (m_target_spawn_position - caster_ground_pos).normalized()
                if direction_to_target.length() < 0.001:
                    # If spawn position is at caster position, use forward direction
                    direction_to_target = Vector3.FORWARD
                
                aim_direction = Vector3(direction_to_target.x, 0.0, direction_to_target.z).normalized()
                print("[PERSISTENT SPELL AREA] Line positioned at caster: %s, direction: %s" % [global_position, aim_direction])
            
            update_shader_params()

func _apply_effect_to_character(character: BattleCharacter) -> void:
    if not caster:
        print("[PERSISTENT SPELL AREA] ERROR: Caster is null when trying to apply effect!")
        return
    
    if not m_spell_item:
        print("[PERSISTENT SPELL AREA] ERROR: Spell item is null when trying to apply effect!")
        return
    
    print("[AOE DEBUG] Checking if %s can use %s on %s" % [caster.character_name, m_spell_item.item_name, character.character_name])
    print("[AOE DEBUG] Caster type: %s, Target type: %s" % [BattleEnums.ECharacterType.keys()[caster.character_type], BattleEnums.ECharacterType.keys()[character.character_type]])
    print("[AOE DEBUG] Can use on allies: %s, Can use on enemies: %s" % [m_spell_item.can_use_on_allies, m_spell_item.can_use_on_enemies])
    
    if m_spell_item.can_use_on(caster, character, true): # Ignore costs for AOE
        m_spell_item.activate(caster, character, false, false)  # Don't consume item for AOE, and don't use actions for every application of the effect
        print("[AOE TRIGGER] %s used %s on %s" % [caster.character_name, m_spell_item.item_name, character.character_name])
        _has_been_affected.append(character)

        _times_triggered += 1

    else:
        print("[PERSISTENT SPELL AREA] %s cannot use %s on %s" % [caster.character_name, m_spell_item.item_name, character.character_name])


func _apply_effect_to_nodes_in_area() -> void:
    var nodes_in_area: Array[Node3D] = get_nodes_in_area()
    print("[AOE DEBUG] Found %d nodes in area" % nodes_in_area.size())
    for node in nodes_in_area:
        var battle_character := node.get_node_or_null("BattleCharacter") as BattleCharacter
        if battle_character:
            print("[AOE DEBUG] Found character: %s" % battle_character.character_name)
            # Only apply effect to characters not currently moving
            var character_controller := battle_character.character_controller
            if character_controller and character_controller.is_moving():
                print("[AOE DEBUG] %s is moving, skipping" % battle_character.character_name)
                continue

            print("[AOE TRIGGER] %s is in AOE area, applying effect" % battle_character.character_name)
            _apply_effect_to_character(battle_character)
        else:
            print("[AOE DEBUG] Node %s has no BattleCharacter" % node.name)

func _on_turn_started(_turn_character: BattleCharacter = null) -> void:
    if m_turns_left != -1:
        m_turns_left -= 1
        if m_turns_left <= 0:
            print("[AOE TRIGGER] %s has expired after %d turns" % [m_spell_item.item_name, m_ttl_turns])
            queue_free()  # Remove the AOE spell effect after its duration
            return
    
    # Clear tracking at the start of each turn so characters can be affected again
    _has_been_affected.clear()
    
    # Apply effect to all characters currently in the area at the start of each turn
    _apply_effect_to_nodes_in_area()

func _exit_tree() -> void:
    # Clean up any connections when the spell is destroyed
    if BattleSignalBus.OnTurnStarted.is_connected(_on_turn_started):
        BattleSignalBus.OnTurnStarted.disconnect(_on_turn_started)
