extends State
class_name PlayerTargetingState

@onready var battle_state := GameModeStateMachine.get_node("BattleState") as BattleState
@onready var battle_character := state_machine.get_parent() as BattleCharacter

# Camera used for raycasts
@onready var top_down_camera := battle_state.top_down_player.get_node("TopDownPlayerPivot/SpringArm3D/TopDownCamera") as Camera3D

# Get the selected spell from PlayerChooseSpellItemState
@onready var spell_selection_state := get_node("../ChooseSpellItemState") as PlayerChooseSpellItemState

var selected_spell_item: BaseInventoryItem = null
var _last_raycast_selected_character: BattleCharacter
var _spell_used: bool = false  # Flag to prevent spam clicking

# Ground position capture for "use anywhere" spells
var captured_ground_position := Vector3.ZERO

@onready var player_think_ui := battle_state.get_node("PlayerThinkUI") as PlayerThinkUI

func _ready() -> void:
    battle_character.OnLeaveBattle.connect(_on_leave_battle)

func _on_leave_battle() -> void:
    if active:
        Transitioned.emit(self, "IdleState")

func enter() -> void:
    print("[TARGETING] Entering targeting state")
    
    # Reset spell used flag
    _spell_used = false
    
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
    if selected_spell_item is SpellItem:
        var spell_item := selected_spell_item as SpellItem
        if spell_item.item_type == BaseInventoryItem.ItemType.FIELD_SPELL_PLACE:
            # Ground targeting spell - start in ground mode
            battle_state.available_actions = BattleEnums.EAvailableCombatActions.GROUND
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

func _capture_ground_position() -> void:
    # Get the ground position from the current raycast when entering the state
    var result := Util.raycast_from_center_or_mouse(top_down_camera)
    
    if result and result.has("position"):
        captured_ground_position = result.position
        print("[GROUND CAPTURE] Captured ground position: " + str(captured_ground_position))
    else:
        # Fallback to a position in front of the caster
        captured_ground_position = battle_character.get_parent().global_position + Vector3.FORWARD * 5.0
        print("[GROUND CAPTURE] Used fallback position: " + str(captured_ground_position))

func _state_physics_process(_delta: float) -> void:
    # Don't process anything if spell has been used
    if _spell_used:
        return
        
    # Perform main raycast and handle targeting
    var ray_result := _perform_raycast()
    
    # Check if this is a place anywhere spell
    var is_place_anywhere := (selected_spell_item is SpellItem 
        and (selected_spell_item as SpellItem).item_type != BaseInventoryItem.ItemType.BATTLE_SPELL)

    if is_place_anywhere:
        # Update ground position for place anywhere spells
        if ray_result.has("position"):
            captured_ground_position = ray_result.position
        battle_state.select_character(null, false)
    else:
        # Handle character targeting
        _handle_character_raycast(ray_result)

func _perform_raycast() -> Dictionary:
    return Util.raycast_from_center_or_mouse(top_down_camera, [battle_state.top_down_player.get_rid()])

func _handle_character_raycast(ray_result: Dictionary) -> void:
    if not ray_result.has("collider"):
        return

    var collider := ray_result.collider as Node3D
    var children := collider.find_children("BattleCharacter")
    
    if children.is_empty():
        _last_raycast_selected_character = null
        return

    var character := children.front() as BattleCharacter
    if not character or not is_valid_target(character) or character == _last_raycast_selected_character:
        return
    
    print("[TARGETING] Selecting character: " + character.character_name)
    battle_state.select_character(character, false)
    _last_raycast_selected_character = character

func is_valid_target(character: BattleCharacter) -> bool:
    if not selected_spell_item or not character:
        return false
    
    # Check if the spell/item can be used on this character type
    var same_side := (battle_character.character_type in [BattleEnums.ECharacterType.FRIENDLY, BattleEnums.ECharacterType.PLAYER]) == \
                    (character.character_type in [BattleEnums.ECharacterType.FRIENDLY, BattleEnums.ECharacterType.PLAYER])
    
    if same_side:
        return selected_spell_item.can_use_on_allies
    else:
        return selected_spell_item.can_use_on_enemies

func _state_input(event: InputEvent) -> void:
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
    if (selected_spell_item is SpellItem 
    and (selected_spell_item as SpellItem).item_type != BaseInventoryItem.ItemType.BATTLE_SPELL):
        _use_field_spell()
    else:
        _use_character_targeting_spell()

func _use_field_spell() -> void:
    var spell_item := selected_spell_item as SpellItem
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
    
    print("[TARGETING] Final use status: " + Util.get_enum_name(BaseInventoryItem.UseStatus, status))
    
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
    
    # Hide the targeting UI when exiting
    if player_think_ui:
        player_think_ui.hide()

func _state_process(_delta: float) -> void: pass
func _state_unhandled_input(_event: InputEvent) -> void: pass