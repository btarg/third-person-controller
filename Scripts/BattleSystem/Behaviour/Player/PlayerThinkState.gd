class_name PlayerThinkState
extends State

# TODO: this isn't used for anything useful at the moment
# @onready var exploration_player := get_tree().get_nodes_in_group("Player").front() as PlayerController

@onready var battle_character := state_machine.get_parent() as BattleCharacter
@onready var radius_visual := get_node("/root/RadiusVisual") as CSGMesh3D

# One level up is state machine, two levels up is the battle character. The inventory is on the same level
@onready var inventory_manager := get_node("../../../Inventory") as Inventory
@onready var battle_state := get_node("/root/GameModeStateMachine/BattleState") as BattleState

# Camera used for raycasts
# We get the node manually here to avoid @onready order shenanigans
@onready var top_down_camera := battle_state.top_down_player.get_node("TopDownPlayerPivot/SpringArm3D/TopDownCamera") as Camera3D
@onready var player_think_ui := battle_state.get_node("PlayerThinkUI") as PlayerThinkUI

var chosen_action: BattleEnums.EPlayerCombatAction = BattleEnums.EPlayerCombatAction.CA_DEFEND

@onready var chosen_spell_or_item: BaseInventoryItem

var _last_raycast_selected_character: BattleCharacter

func _ready() -> void:
	Console.add_command("choose_item", _choose_item_command, 1)

	player_think_ui.hide()
	battle_character.OnLeaveBattle.connect(_on_leave_battle)

	BattleSignalBus.OnTurnStarted.connect(_on_turn_started)
	BattleSignalBus.OnBattleEnded.connect(_cleanup_visuals)

	_cleanup_visuals()


func _cleanup_visuals() -> void:
	radius_visual.visible = false

func _choose_item_command(item_name: String) -> void:
	if not active:
		return

	var item: BaseInventoryItem = inventory_manager.get_item(item_name)
	if item:
		chosen_spell_or_item = item
		Console.print_line("Chosen item: " + item_name)
	else:
		Console.print_line("Item not found") 

func _on_leave_battle() -> void:
	if active:
		Transitioned.emit(self, "IdleState")
	else:
		exit()

func _on_turn_started(turn_character: BattleCharacter) -> void:
	if turn_character != battle_character:
		return # not our turn

	if battle_character.character_controller:
		_process_radius_visual()
		battle_character.character_controller.update_home_position()
	else:
		print("No character controller found")

func enter() -> void:
	if battle_character.current_hp <= 0:
		# Players are able to be revived once "dead"
		Transitioned.emit(self, "DeadState")
		return

	player_think_ui.show()
	player_think_ui.set_text()

	if battle_state.turn_order_ui.is_ui_active:
		battle_state.turn_order_ui.is_ui_active = false

	# battle_state.turn_order_ui.show()
	# battle_state.turn_order_ui.focus_last_selected()

	print(battle_character.character_name + " is thinking about what to do")

	# remember last selected character
	if battle_state.player_selected_character:
		print("Selected character: " + battle_state.player_selected_character.character_name)
	else:
		print("No character selected")

	battle_state.top_down_player.allow_moving_focus = true


func exit() -> void:
	print(battle_character.character_name + " has stopped thinking")
	player_think_ui.hide()
	battle_state.turn_order_ui.hide()
	battle_state.turn_order_ui.is_ui_active = false


func _process_radius_visual() -> void:

	var range_size := battle_character.character_controller.movement_left
	if range_size <= 0:
		# don't display a radius when we have no movement left
		radius_visual.visible = false
		return

	print("Processing radius visual: " + battle_character.character_name)
	radius_visual.global_position = battle_character.character_controller.global_position
	radius_visual.global_position.y += 0.01 # prevent Z-fighting
	
	# The mesh is 1mx1m, so we scale it to the movement range x 2
	var scalar := range_size * 2
	radius_visual.scale = Vector3(scalar, 1, scalar)
	radius_visual.visible = true


# ==============================================================================
# PLAN FOR THINK STATE
# Step 1: shoot a raycast from either the middle of the camera every frame
# when we are using a controller, or from the click pos when clicking mouse
#
# Step 2: if the raycast hits a character, show context actions
# e.g. if it's an enemy, show the options to attack, draw, or use a spell
#
# Step 3: if the raycast hits the ground, show the options to move
#
# Step 4: if the player selects an action, transition to the appropriate state
# for the UI to be displayed, e.g. display the inventory when casting a spell
# ==============================================================================

func _state_physics_process(_delta: float) -> void:

	if (battle_state.available_actions == BattleEnums.EAvailableCombatActions.NONE
	or battle_state.turn_order_ui.is_ui_active):
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
		battle_state.select_character(null, false)
		return
	
	if character != _last_raycast_selected_character:
		battle_state.select_character(character, false)
		
		_last_raycast_selected_character = character

func _state_process(_delta: float) -> void: pass

func _on_movement_finished() -> void:
	# Disconnect ourselves to prevent multiple connections
	battle_state.current_character.character_controller.OnMovementFinished.disconnect(_on_movement_finished)

	battle_state.select_character(battle_state.current_character)
	player_think_ui.set_text()

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

			chosen_action = BattleEnums.EPlayerCombatAction.CA_MOVE
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

	# Spell/item selection is available for allies and enemies, and self
	if event.is_action_pressed("combat_spellitem"):
		# Select self if no other character is selected before handling a button press
		if (battle_state.player_selected_character == null
		and battle_character):
			battle_state.select_character(battle_character)
		# Don't allow selecting self if moving
		if (battle_character.character_controller.is_moving()
		or battle_state.player_selected_character.character_controller.is_moving()):
			return

		Transitioned.emit(self, "ChooseSpellItemState")

	elif battle_state.available_actions == BattleEnums.EAvailableCombatActions.ENEMY:

		if event.is_action_pressed("combat_attack"):
			chosen_action = BattleEnums.EPlayerCombatAction.CA_ATTACK
			Transitioned.emit(self, "ChooseTargetState")
		
		elif event.is_action_pressed("combat_draw"):
			chosen_action = BattleEnums.EPlayerCombatAction.CA_DRAW
			Transitioned.emit(self, "ChooseTargetState")
	
	# TODO: defend
	


func _state_input(_event: InputEvent) -> void: pass
