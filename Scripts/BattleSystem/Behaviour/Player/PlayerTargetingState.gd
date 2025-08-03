class_name PlayerTargetingState extends State

@onready var battle_state := GameModeStateMachine.get_node("BattleState") as BattleState
@onready var battle_character := state_machine.get_parent() as BattleCharacter

# Camera used for raycasts
@onready var top_down_camera := battle_state.top_down_player.get_node("TopDownPlayerPivot/SpringArm3D/TopDownCamera") as Camera3D

# Get the selected spell from PlayerChooseSpellItemState
@onready var spell_selection_state := get_node("../ChooseSpellItemState") as PlayerChooseSpellItemState

var selected_spell_item: Item = null
var _last_raycast_selected_character: BattleCharacter
var _spell_used: bool = false  # Flag to prevent spam clicking

# Ground position capture for "use anywhere" spells
var captured_ground_position := Vector3.ZERO

@onready var player_think_ui := battle_state.get_node("PlayerThinkUI") as PlayerThinkUI

# autoload a spell area indicator so we use the same one everywhere for indicators
@onready var spell_area_indicator: Node3D

# Line rendering constants and variables
const CURVE_SEGMENTS := 20
const CURVE_HEIGHT_OFFSET := 5.0
const CURVE_TARGET_HEIGHT_OFFSET := 0.1

var line_current_character: BattleCharacter
var line_target_character: BattleCharacter
var _current_line_renderer: LineRenderer3D
var material_override := preload("res://addons/LineRenderer/demo/target_line_renderer.tres") as Material
var should_render_line: bool = false
var _current_segment := 0

func _ready() -> void:

    spell_area_indicator = SpellArea.new(
        battle_character, 
        AreaUtils.SpellAreaType.CIRCLE, 
        5.0, 
        60.0, 
        2.0, 
        Vector3.FORWARD
    )
    add_child(spell_area_indicator)
    spell_area_indicator.visible = false

    battle_character.OnLeaveBattle.connect(_on_leave_battle)
    # Connect to character selection signal
    BattleSignalBus.OnCharacterSelected.connect(_on_character_selected)
    

func _on_leave_battle() -> void:
    if active:
        # Hide spell area indicator when leaving battle
        spell_area_indicator.visible = false
        Transitioned.emit(self, "IdleState")

func _on_character_selected(character: BattleCharacter) -> void:
    if not active:
        return
        
    # Only show line for direct targeting spells (not AOE field spells)
    var is_direct_targeting := not (selected_spell_item.item_type in [Item.ItemType.BATTLE_SPELL, Item.ItemType.FIELD_SPELL] 
        and selected_spell_item.item_type == Item.ItemType.FIELD_SPELL)
    
    if is_direct_targeting and selected_spell_item and is_valid_target(character):
        _setup_line_rendering(character)
    else:
        _clear_line_rendering()

func _setup_line_rendering(target_character: BattleCharacter) -> void:
    _clear_line_rendering()
    
    line_current_character = battle_character
    line_target_character = target_character
    
    # Get line renderer from current character
    var renderer := line_current_character.get_node_or_null("../LineRenderer3D") as LineRenderer3D
    if renderer:
        renderer.material_override = material_override
        _current_line_renderer = renderer
        _current_segment = 0
        should_render_line = true
    else:
        print("No line renderer found on current character")

func _clear_line_rendering() -> void:
    should_render_line = false
    _current_segment = 0
    line_current_character = null
    line_target_character = null

    if _current_line_renderer:
        _current_line_renderer.remove_line()
        _current_line_renderer = null

func cleanup_line_renderers() -> void:
    _clear_line_rendering()

func _update_line_rendering() -> void:
    if not should_render_line:
        return
    if not line_current_character or not line_target_character:
        return

    # draw a line between the player and the selected character
    # the line renderer is placed on top of the player character
    var current_character_pos := _current_line_renderer.global_position
    current_character_pos.y += CURVE_TARGET_HEIGHT_OFFSET
    # if the target has a line renderer use that as the end pos since it will also be on their head
    var target_line_renderer := line_target_character.get_parent().get_node_or_null("LineRenderer3D")
    var target_character_pos: Vector3 = target_line_renderer.global_position if target_line_renderer\
    else line_target_character.get_parent().global_position

    # place end of the line on top of target's head
    target_character_pos.y += CURVE_TARGET_HEIGHT_OFFSET
    
    var middle := current_character_pos.lerp(target_character_pos, 0.5)
    middle.y += CURVE_HEIGHT_OFFSET

    # use quadratic bezier to create a curve and add the curve to the line renderer
    var segments := CURVE_SEGMENTS
    var points: Array[Vector3] = []
    for i in range(_current_segment + 1):
        var t := float(i) / float(segments)
        points.append(Util._quadratic_bezier(current_character_pos, middle, target_character_pos, t))

    _current_line_renderer.points = points

    # Increment the current segment to animate the line building
    if _current_segment < segments:
        _current_segment += 1
    # Don't set should_render_line to false when animation completes
    # Let the targeting state control when to hide the line

func enter() -> void:
    print("[TARGETING] Entering targeting state")
    
    # Reset spell used flag
    _spell_used = false
    
    # Hide spell area indicator initially
    spell_area_indicator.visible = false
    
    # Get the selected spell from the previous state
    selected_spell_item = spell_selection_state.selected_spell_item
    if not selected_spell_item:
        print("[TARGETING] No spell selected! Returning to think state")
        _back_to_think()
        return
    
    print("[TARGETING] Targeting for: " + selected_spell_item.item_name)
    
    # Show the UI for targeting mode
    player_think_ui.show()


    # Check spell type and set up targeting accordingly
    if selected_spell_item:
        if selected_spell_item.item_type == Item.ItemType.FIELD_SPELL:
            # Ground targeting spell - start in ground mode
            battle_state.available_actions = BattleEnums.EAvailableCombatActions.GROUND
            _setup_aoe_indicator()
            _capture_ground_position()
        else:
            # Character targeting spell - determine valid targets
            _setup_character_targeting()
    else:
        # Regular item - determine valid targets
        _setup_character_targeting()
    
    # Update the UI after setting available actions
    player_think_ui.set_text()
    
    # Enable camera movement for targeting
    battle_state.top_down_player.allow_moving_focus = true
    
    # Enable input for turn order UI when in targeting state
    if battle_state.turn_order_ui:
        battle_state.turn_order_ui.input_allowed = true

func _setup_character_targeting() -> void:
    # Default to self-targeting if the item can be used on allies
    if selected_spell_item.can_use_on_allies:
        battle_state.available_actions = BattleEnums.EAvailableCombatActions.SELF
        battle_state.select_character(battle_character)
    elif selected_spell_item.can_use_on_enemies:
        battle_state.available_actions = BattleEnums.EAvailableCombatActions.ENEMY
        # Try to find an enemy to target
        var enemies := battle_state.enemy_units
        if not enemies.is_empty():
            battle_state.select_character(enemies[0])
        else:
            print("[TARGETING] No enemies available to target!")
    else:
        # Item can't target anyone - this shouldn't happen
        print("[TARGETING] Item can't target anyone!")
        _back_to_think()

func _setup_aoe_indicator() -> void:
    # Set up the spell area indicator for AOE spells
    if not spell_area_indicator:
        return
    
    # Configure the spell area indicator based on the spell
    spell_area_indicator.caster = battle_character
    
    # Check target type to determine positioning behavior
    match selected_spell_item.target_type:
        Item.TargetType.FIXED_AIM_FROM_CHAR:
            # Fixed position at character location - no mouse tracking
            _setup_fixed_aoe_at_character()
        Item.TargetType.FREE_SELECT:
            # Free selection - follows mouse cursor
            _setup_free_select_aoe()
        _:
            # Default to free select for backwards compatibility
            _setup_free_select_aoe()
    
    print("[TARGETING] AOE indicator set up for %s with target type: %s" % [selected_spell_item.item_name, Item.TargetType.keys()[selected_spell_item.target_type]])

func _start_circle_cast() -> void:
    spell_area_indicator.area_type = AreaUtils.SpellAreaType.CIRCLE
    spell_area_indicator.radius = selected_spell_item.area_of_effect_radius
    spell_area_indicator.caster = battle_character
    
    # Set appropriate colors for targeting
    spell_area_indicator.set_area_colors(Color.GREEN * 0.3, Color.WHITE, Color.GREEN)
    
    # Update shader parameters and show
    spell_area_indicator.update_shader_params()
    spell_area_indicator.visible = true
    
    print("[CIRCLE CAST] Started circle casting with radius: %s" % selected_spell_item.area_of_effect_radius)

func _start_cone_cast() -> void:
    spell_area_indicator.area_type = AreaUtils.SpellAreaType.CONE
    spell_area_indicator.radius = selected_spell_item.area_of_effect_radius
    spell_area_indicator.cone_angle_degrees = selected_spell_item.cone_angle_degrees
    spell_area_indicator.caster = battle_character
    
    # Position at caster's ground level
    var ground_pos := Util.project_to_ground(battle_character.get_parent(), 1, 0.002)
    spell_area_indicator.global_position = ground_pos
    
    # Set appropriate colors for targeting
    spell_area_indicator.set_area_colors(Color.GREEN * 0.3, Color.WHITE, Color.GREEN)
    
    # Update shader parameters and show
    spell_area_indicator.update_shader_params()
    spell_area_indicator.visible = true
    
    print("[CONE CAST] Started cone casting with radius: %s, angle: %s" % [selected_spell_item.area_of_effect_radius, selected_spell_item.cone_angle_degrees])

func _start_line_cast() -> void:
    spell_area_indicator.area_type = AreaUtils.SpellAreaType.LINE
    spell_area_indicator.radius = selected_spell_item.area_of_effect_radius  # radius represents length for lines
    spell_area_indicator.line_width = selected_spell_item.line_width
    spell_area_indicator.caster = battle_character
    
    # Position at caster's ground level
    var ground_pos := Util.project_to_ground(battle_character.get_parent(), 1, 0.002)
    spell_area_indicator.global_position = ground_pos
    
    # Set appropriate colors for targeting
    spell_area_indicator.set_area_colors(Color.GREEN * 0.3, Color.WHITE, Color.GREEN)
    
    # Update shader parameters and show
    spell_area_indicator.update_shader_params()
    spell_area_indicator.visible = true
    
    print("[LINE CAST] Started line casting with length: %s, width: %s" % [selected_spell_item.area_of_effect_radius, selected_spell_item.line_width])

func _capture_ground_position() -> void:
    # For fixed position spells, use character position
    if selected_spell_item.target_type == Item.TargetType.FIXED_AIM_FROM_CHAR:
        captured_ground_position = Util.project_to_ground(battle_character.get_parent(), 1, 0.002)
        print("[GROUND CAPTURE] Fixed position at character: " + str(captured_ground_position))
        return
    
    # For free select spells, get the ground position from the current raycast when entering the state
    var result := Util.raycast_from_center_or_mouse(top_down_camera)
    
    if result and result.has("position"):
        captured_ground_position = (result.position as Vector3) + Vector3(0.0, 0.0025, 0.0)  # add an offset to prevent z-fighting
        print("[GROUND CAPTURE] Captured ground position: " + str(captured_ground_position))
    else:
        # Fallback to a position in front of the caster
        captured_ground_position = battle_character.get_parent().global_position + Vector3.FORWARD * 5.0
        print("[GROUND CAPTURE] Used fallback position: " + str(captured_ground_position))

func _state_physics_process(_delta: float) -> void:
    # Handle line rendering animation
    _update_line_rendering()
    
    # Don't process anything if spell has been used
    if _spell_used:
        return
        
    # Perform main raycast and handle targeting
    var ray_result := _perform_raycast()
    
    # Check if this is a place anywhere spell
    var is_place_anywhere := (selected_spell_item.item_type in [Item.ItemType.BATTLE_SPELL, Item.ItemType.FIELD_SPELL] 
        and selected_spell_item.item_type == Item.ItemType.FIELD_SPELL)

    if is_place_anywhere:
        # Update spell area indicator if it's visible and using free select
        if selected_spell_item.target_type == Item.TargetType.FREE_SELECT:
            _update_spell_targeting()
            
            # Update ground position for free select spells
            if ray_result.has("position"):
                captured_ground_position = ray_result.position
                # Update AOE indicator position if it's visible and it's a circle type
                if (spell_area_indicator and spell_area_indicator.visible 
                and spell_area_indicator.area_type == AreaUtils.SpellAreaType.CIRCLE):
                    spell_area_indicator.global_position = captured_ground_position
        # For fixed position spells, captured_ground_position is already set and doesn't change
        
        battle_state.select_character(null, false)
    else:
        # Handle character targeting
        _handle_character_raycast(ray_result)



func _perform_raycast() -> Dictionary:
    return Util.raycast_from_center_or_mouse(top_down_camera, [battle_state.top_down_player.get_rid()])

func _handle_character_raycast(ray_result: Dictionary) -> void:
    if not ray_result.has("collider"):
        # Don't clear line rendering when hovering over ground - keep last valid target
        _last_raycast_selected_character = null
        return

    var collider := ray_result.collider as Node3D
    var children := collider.find_children("BattleCharacter")
    
    if children.is_empty():
        # Don't clear line rendering when hovering over ground - keep last valid target
        _last_raycast_selected_character = null
        return

    var character := children.front() as BattleCharacter
    if not character or not is_valid_target(character):
        # Only update last raycast character for invalid characters
        if character != _last_raycast_selected_character:
            _last_raycast_selected_character = null
        return
    
    if character == _last_raycast_selected_character:
        return
    
    print("[TARGETING] Selecting character: " + character.character_name)
    battle_state.select_character(character, false)
    _last_raycast_selected_character = character

func is_valid_target(character: BattleCharacter) -> bool:
    return selected_spell_item.can_use_on(battle_character, character)

func _state_unhandled_input(event: InputEvent) -> void:
    # Don't process any input if spell has been used
    if _spell_used:
        return
        
    if event.is_action_pressed("ui_cancel"):
        # go back to spell selection
        print("[TARGETING] Cancelled targeting, going back to spell selection")
        _back_to_choosing()
        return
    
    # Handle character selection with mouse clicks
    if event.is_action_pressed("combat_select_target"):
        _use_selected_spell_item()
    

func _use_selected_spell_item() -> void:
    if not selected_spell_item or _spell_used:
        print("[TARGETING] No spell selected or spell already used!")
        return
    
    # Set the flag immediately to prevent spam clicking
    _spell_used = true
    
    # Hide UI to indicate spell is being cast
    player_think_ui.hide()
    
    # Check if it's a ground-targeting spell
    if (selected_spell_item.item_type in [Item.ItemType.BATTLE_SPELL, Item.ItemType.FIELD_SPELL] 
    and selected_spell_item.item_type == Item.ItemType.FIELD_SPELL):
        _use_field_spell()
    else:
        _use_character_targeting_spell()

func _use_field_spell() -> void:
    var spell_item := selected_spell_item
    print("[GROUND TARGET] Using spell at captured position: " + str(captured_ground_position))
    
    # Check if we have enough resources
    if not spell_item.check_cost(battle_character):
        print("[TARGETING] Cannot afford " + spell_item.item_name)
        # Reset flag since spell wasn't actually used
        _spell_used = false
        player_think_ui.show()
        return
    
    # Show message and spawn AOE
    await battle_state.message_ui.show_messages([spell_item.item_name])
    var spawned := SpellHelper.create_area_of_effect_radius(spell_item, battle_character, captured_ground_position)
    
    if not spawned:
        print("[GROUND TARGET] Failed to spawn spell effect at position: " + str(captured_ground_position))
        # Reset flag since spell wasn't actually used
        _spell_used = false
        player_think_ui.show()
        return

    # Spend the action cost - this will trigger battle callbacks
    battle_character.spend_actions(spell_item.actions_cost)
    # Stay in this state and wait - battle system will handle transitions

func _use_character_targeting_spell() -> void:
    var target_character := battle_state.player_selected_character
    if not target_character:
        print("[TARGETING] No target selected!")
        # Reset flag since spell wasn't actually used
        _spell_used = false
        player_think_ui.show()
        return
    
    # Check if the target is valid
    if not selected_spell_item.can_use_on(battle_character, target_character):
        print("[TARGETING] Cannot use " + selected_spell_item.item_name + " on " + target_character.character_name)
        # Reset flag since spell wasn't actually used
        _spell_used = false
        player_think_ui.show()
        return
    
    # Check range for non-self targeting
    if target_character != battle_character:
        var distance := floori(battle_character.get_parent().global_position.distance_to(
            target_character.get_parent().global_position))
        
        if (distance > battle_character.stats.get_stat(CharacterStatEntry.ECharacterStat.AttackRange)
        or distance > selected_spell_item.effective_range):
            print("[TARGETING] Target is out of range (distance: " + str(distance) + ", range: " + str(selected_spell_item.effective_range) + ")")
            # Reset flag since spell wasn't actually used
            _spell_used = false
            player_think_ui.show()
            return
    
    # Use the spell/item
    await battle_state.message_ui.show_messages([selected_spell_item.item_name])
    var status := SpellHelper.use_item_or_aoe(selected_spell_item, battle_character, target_character)
    
    print("[TARGETING] Final use status: " + Util.get_enum_name(Item.UseStatus, status))
    
    # Spend the action cost - this will trigger battle callbacks
    battle_character.spend_actions(selected_spell_item.actions_cost)
    # Stay in this state and wait - battle system will handle transitions

func _back_to_think() -> void:
    if active:
        Transitioned.emit(self, "ThinkState")

func _back_to_choosing() -> void:
    if active:
        Transitioned.emit(self, "ChooseSpellItemState")

func exit() -> void:
    print("[TARGETING] Exiting targeting state")
    # Reset selected spell
    selected_spell_item = null
    
    # Hide spell area indicator when exiting
    spell_area_indicator.visible = false
    
    # Clear line rendering when exiting
    _clear_line_rendering()
    
    # Disable input for turn order UI when exiting targeting state
    if battle_state.turn_order_ui:
        battle_state.turn_order_ui.input_allowed = false
    
    # Hide the targeting UI when exiting
    if player_think_ui:
        player_think_ui.hide()

func _state_process(_delta: float) -> void: pass

func _get_mouse_world_position() -> Vector3:
    # Use existing utility function with fallback
    var result := Util.raycast_from_center_or_mouse(top_down_camera, [battle_state.top_down_player.get_rid()])
    
    if result and result.has("position"):
        return result.position + Vector3(0.0, 0.001, 0.0)
    else:
        # Fallback to a position in front of the caster
        return battle_character.get_parent().global_position + Vector3.FORWARD * 5.0

func _update_spell_targeting() -> void:
    if not spell_area_indicator or not spell_area_indicator.visible:
        return
    
    # Only update targeting for free select spells
    if selected_spell_item.target_type != Item.TargetType.FREE_SELECT:
        return
        
    var mouse_world_pos := _get_mouse_world_position()
    
    match spell_area_indicator.area_type:
        AreaUtils.SpellAreaType.CIRCLE:
            # For circles, update position to mouse position
            spell_area_indicator.global_position = mouse_world_pos
        AreaUtils.SpellAreaType.CONE:
            # For cones, update direction from caster to mouse position
            spell_area_indicator.update_fixed_target(mouse_world_pos)
        AreaUtils.SpellAreaType.LINE:
            # For lines, update direction from caster to mouse position
            spell_area_indicator.update_fixed_target(mouse_world_pos)

func _setup_fixed_aoe_at_character() -> void:
    # Fixed AOE at character position - area doesn't move with mouse
    match selected_spell_item.area_type:
        AreaUtils.SpellAreaType.CIRCLE:
            _start_fixed_circle_cast()
        AreaUtils.SpellAreaType.CONE:
            _start_fixed_cone_cast()
        AreaUtils.SpellAreaType.LINE:
            _start_fixed_line_cast()

func _setup_free_select_aoe() -> void:
    # Free selection AOE - area follows mouse cursor
    match selected_spell_item.area_type:
        AreaUtils.SpellAreaType.CIRCLE:
            _start_circle_cast()
        AreaUtils.SpellAreaType.CONE:
            _start_cone_cast()
        AreaUtils.SpellAreaType.LINE:
            _start_line_cast()

func _start_fixed_circle_cast() -> void:
    spell_area_indicator.area_type = AreaUtils.SpellAreaType.CIRCLE
    spell_area_indicator.radius = selected_spell_item.area_of_effect_radius
    spell_area_indicator.caster = battle_character
    
    # Position fixed at character's ground level
    var ground_pos := Util.project_to_ground(battle_character.get_parent(), 1, 0.002)
    spell_area_indicator.global_position = ground_pos
    captured_ground_position = ground_pos
    
    # Set appropriate colors for targeting
    spell_area_indicator.set_area_colors(Color.BLUE * 0.3, Color.WHITE, Color.BLUE)
    
    # Update shader parameters and show
    spell_area_indicator.update_shader_params()
    spell_area_indicator.visible = true
    
    print("[FIXED CIRCLE CAST] Started fixed circle casting at character position with radius: %s" % selected_spell_item.area_of_effect_radius)

func _start_fixed_cone_cast() -> void:
    spell_area_indicator.area_type = AreaUtils.SpellAreaType.CONE
    spell_area_indicator.radius = selected_spell_item.area_of_effect_radius
    spell_area_indicator.cone_angle_degrees = selected_spell_item.cone_angle_degrees
    spell_area_indicator.caster = battle_character
    
    # Position fixed at caster's ground level
    var ground_pos := Util.project_to_ground(battle_character.get_parent(), 1, 0.002)
    spell_area_indicator.global_position = ground_pos
    captured_ground_position = ground_pos
    
    # Set initial direction forward
    spell_area_indicator.aim_direction = Vector3.FORWARD
    
    # Set appropriate colors for targeting  
    spell_area_indicator.set_area_colors(Color.BLUE * 0.3, Color.WHITE, Color.BLUE)
    
    # Update shader parameters and show
    spell_area_indicator.update_shader_params()
    spell_area_indicator.visible = true
    
    print("[FIXED CONE CAST] Started fixed cone casting at character position with radius: %s, angle: %s" % [selected_spell_item.area_of_effect_radius, selected_spell_item.cone_angle_degrees])

func _start_fixed_line_cast() -> void:
    spell_area_indicator.area_type = AreaUtils.SpellAreaType.LINE
    spell_area_indicator.radius = selected_spell_item.area_of_effect_radius  # radius represents length for lines
    spell_area_indicator.line_width = selected_spell_item.line_width
    spell_area_indicator.caster = battle_character
    
    # Position fixed at caster's ground level
    var ground_pos := Util.project_to_ground(battle_character.get_parent(), 1, 0.002)
    spell_area_indicator.global_position = ground_pos
    captured_ground_position = ground_pos
    
    # Set initial direction forward
    spell_area_indicator.aim_direction = Vector3.FORWARD
    
    # Set appropriate colors for targeting
    spell_area_indicator.set_area_colors(Color.BLUE * 0.3, Color.WHITE, Color.BLUE)
    
    # Update shader parameters and show
    spell_area_indicator.update_shader_params()
    spell_area_indicator.visible = true
    
    print("[FIXED LINE CAST] Started fixed line casting at character position with length: %s, width: %s" % [selected_spell_item.area_of_effect_radius, selected_spell_item.line_width])
