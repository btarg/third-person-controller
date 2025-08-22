class_name PlayerThinkState
extends State

# TODO: this isn't used for anything useful at the moment
# @onready var exploration_player := get_tree().get_nodes_in_group("Player").front() as PlayerController

@onready var battle_character := state_machine.get_parent() as BattleCharacter
@onready var radius_visual := MovementRadiusVisual as MeshInstance3D

# One level up is state machine, two levels up is the battle character. The inventory is on the same level
@onready var inventory_manager := get_node("../../../Inventory") as Inventory
@onready var battle_state := GameModeStateMachine.get_node("BattleState") as BattleState

# Camera used for raycasts
# We get the node manually here to avoid @onready order shenanigans
@onready var top_down_camera := battle_state.top_down_player.get_node("TopDownPlayerPivot/SpringArm3D/TopDownCamera") as Camera3D
@onready var player_think_ui := battle_state.get_node("PlayerThinkUI") as PlayerThinkUI

var _last_raycast_selected_character: BattleCharacter
var _has_already_chosen_action := false
var _raycast_paused := false

var _last_raycast_position := Vector3.ZERO
var _last_available_actions := BattleEnums.EAvailableCombatActions.NONE

func _ready() -> void:
    player_think_ui.hide()
    battle_character.OnLeaveBattle.connect(_on_leave_battle)

    BattleSignalBus.OnTurnStarted.connect(_on_turn_started)
    BattleSignalBus.OnBattleEnded.connect(_cleanup_visuals)
    BattleSignalBus.OnCharacterSelected.connect(_on_character_selected_from_ui)

    _cleanup_visuals()

func _on_character_selected_from_ui(_character: BattleCharacter) -> void:
    # Check if this selection came from turn order UI navigation
    if battle_state.turn_order_ui.visible and battle_state.turn_order_ui.is_player_turn:
        # Pause raycasting to prevent immediate override
        _raycast_paused = true
        # Store current raycast position instead of mouse position
        var ray_result := Util.raycast_from_center_or_mouse(top_down_camera, [battle_state.top_down_player.get_rid()])
        if ray_result and ray_result.has("position"):
            _last_raycast_position = ray_result.position


func _cleanup_visuals() -> void:
    radius_visual.visible = false


func _on_leave_battle() -> void:
    if active:
        _cleanup_visuals()
        Transitioned.emit(self, "IdleState")
    else:
        exit()

func _on_turn_started(turn_character: BattleCharacter) -> void:
    if turn_character != battle_character:
        _cleanup_visuals()
        return # not our turn
    

func enter() -> void:
    _has_already_chosen_action = false

    if battle_character.current_hp <= 0:
        # Players are able to be revived once "dead"
        Transitioned.emit(self, "DeadState")
        return

    player_think_ui.show()
    player_think_ui.set_text()
    
    # Enable input for turn order UI when entering think state
    if battle_state.turn_order_ui:
        battle_state.turn_order_ui.input_allowed = true

    print(battle_character.character_name + " is thinking about what to do")

    # remember last selected character
    if battle_state.player_selected_character:
        print("Selected character: " + battle_state.player_selected_character.character_name)
    else:
        print("No character selected")

    battle_state.top_down_player.allow_moving_focus = true

    if battle_character.character_controller:
        _process_radius_visual()
        battle_character.character_controller.update_home_position()
    else:
        print("No character controller found")


func exit() -> void:
    print(battle_character.character_name + " has stopped thinking")
    
    # Disable input for turn order UI when exiting think state
    if battle_state.turn_order_ui:
        battle_state.turn_order_ui.input_allowed = false
    
    # If the character is still moving when exiting, cancel movement and return home
    if battle_character.character_controller and battle_character.character_controller.is_moving():
        battle_character.character_controller.return_to_home_position()
    
    player_think_ui.hide()


func _process_radius_visual() -> void:

    var range_size := battle_character.character_controller.movement_left
    if range_size <= 0:
        # don't display a radius when we have no movement left
        radius_visual.visible = false
        return

    # print("Processing radius visual: " + battle_character.character_name)
    radius_visual.global_position = battle_character.character_controller.global_position
    radius_visual.global_position.y += 0.01 # prevent Z-fighting
    
    # The mesh is 1mx1m, so we scale it to the movement range x 2
    var scalar := range_size * 2
    radius_visual.scale = Vector3(scalar, 1, scalar)
    radius_visual.visible = true


# ==============================================================================
# THINK STATE
#
# This is where we handle raycasting for selecting characters and
# determining available actions based on the raycasted character.
# ==============================================================================

func _state_physics_process(_delta: float) -> void:
   
    # what the fuck is this
    # Here we need to pause raycasting so the turn order container works properly
    if not battle_state.top_down_player.moved_from_focus:
        if (not battle_state.top_down_player.is_at_focus
        or battle_state.available_actions == BattleEnums.EAvailableCombatActions.NONE):
            _raycast_paused = true
    else:
        _raycast_paused = false

    # Check if raycasting should resume based on raycast position changes
    if _raycast_paused:
        # Get current raycast position for comparison
        var current_ray_result := Util.raycast_from_center_or_mouse(top_down_camera, [battle_state.top_down_player.get_rid()])
        var current_raycast_pos := Vector3.ZERO
        if current_ray_result and current_ray_result.has("position"):
            current_raycast_pos = current_ray_result.position
        
        # Check if raycast position has moved significantly (works for both mouse and controller)
        var raycast_moved := current_raycast_pos.distance_to(_last_raycast_position) > 1.0
        var actions_changed := battle_state.available_actions != _last_available_actions
        
        if raycast_moved or actions_changed:
            if battle_state.top_down_player.is_at_focus:
                _raycast_paused = false
                _last_available_actions = battle_state.available_actions
                _last_raycast_position = current_raycast_pos

    if _raycast_paused:
        return

    var ray_result := Util.raycast_from_center_or_mouse(top_down_camera, [battle_state.top_down_player.get_rid()])
    if not ray_result:
        return

    var position := Vector3.INF
    if ray_result.has("position"):
        position = (ray_result.position as Vector3)
    if position == Vector3.INF:
        # print("[Think] No raycast position found")
        return
    if not ray_result.has("collider"):
        # print("[Think] No collider found")
        return

    var collider := ray_result.collider as Node3D

    # TODO: I should probably cache the result of find_children
    # to avoid spamming this intensive function
    var children := collider.find_children("BattleCharacter")
    if children.is_empty():
        battle_state.available_actions = BattleEnums.EAvailableCombatActions.GROUND
        _last_raycast_selected_character = null
        return

    var character := children.front() as BattleCharacter
    if not character:
        return
        
    if character != _last_raycast_selected_character:
        battle_state.select_character(character, false)
        _last_raycast_selected_character = character

func _state_process(_delta: float) -> void:
    # Update the radius visual to show movement range
    _process_radius_visual()

func _on_movement_finished() -> void:
    # Disconnect ourselves to prevent multiple connections
    if battle_state.current_character.character_controller.OnMovementFinished.is_connected(_on_movement_finished):
        battle_state.current_character.character_controller.OnMovementFinished.disconnect(_on_movement_finished)

    battle_state.select_character(battle_state.current_character)
    player_think_ui.set_text()
    _process_radius_visual()

func _state_unhandled_input(event: InputEvent) -> void:
    if ((not battle_state.player_selected_character)
    or battle_state.available_actions == BattleEnums.EAvailableCombatActions.NONE):
        return

    # ==============================================================================
    # PLAYER MOVEMENT
    # ==============================================================================
    if battle_state.available_actions in [BattleEnums.EAvailableCombatActions.GROUND,
    BattleEnums.EAvailableCombatActions.SELF]:
        # we need a character selected to move
        if not battle_state.current_character:
            return
        
        if event.is_action_pressed("combat_move"):

            if battle_state.movement_locked_in:
                print("[MOVE] Movement is locked in")
                return

            # var result := Util.raycast_from_center_or_mouse(top_down_camera, [battle_state.top_down_player.get_rid()])
            # var position := Vector3.INF
            # if result.has("position"):
            #     position = (result.position as Vector3)
            # if position != Vector3.INF:
            #     battle_state.current_character.character_controller.set_move_target(position)

            #     # Update the UI when moving
            #     player_think_ui.set_text()
            #     battle_state.current_character.character_controller.OnMovementFinished.connect(_on_movement_finished)

            #     print("[Move] Got raycast position: " + str(position))
            Transitioned.emit(self, "MoveState")

        # if event.is_action_pressed("ui_cancel"):
        #     battle_character.character_controller.stop_moving()
        #     _on_movement_finished()

    # ==============================================================================
    # SPELLS AND ATTACKS
    # ==============================================================================

    # Spell/item selection - go directly to inventory without needing a target first
    if event.is_action_pressed("combat_spellitem"):
        # Don't allow spell selection if moving
        if battle_character.character_controller.is_moving():
            return

        Transitioned.emit(self, "ChooseSpellItemState")

    elif battle_state.available_actions == BattleEnums.EAvailableCombatActions.ENEMY:

        if event.is_action_pressed("combat_select_target"):
            process_action(BattleEnums.EPlayerCombatAction.CA_ATTACK)
        
        elif event.is_action_pressed("combat_draw"):
            process_action(BattleEnums.EPlayerCombatAction.CA_DRAW)
    
    # TODO: defend
    

func process_action(chosen_action: BattleEnums.EPlayerCombatAction) -> void:
    if _has_already_chosen_action:
        return
    _has_already_chosen_action = true


    var target_character := battle_state.player_selected_character
    if not target_character:
        print("No target selected!")
        return
    match chosen_action:
        BattleEnums.EPlayerCombatAction.CA_ATTACK:
            var attack := await SpellHelper.process_basic_attack(battle_state.current_character, target_character)
            if attack != BattleEnums.ESkillResult.SR_OUT_OF_RANGE:
                battle_character.spend_actions(1)
        BattleEnums.EPlayerCombatAction.CA_DRAW:
            Transitioned.emit(self, "DrawState")
            
        _:
            print("Invalid action")
            battle_character.spend_actions(1)


func _state_input(_event: InputEvent) -> void: pass
