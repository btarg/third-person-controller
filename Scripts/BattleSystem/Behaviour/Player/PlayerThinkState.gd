class_name PlayerThinkState
extends State

# TODO: this isn't used for anything useful at the moment
@onready var exploration_player := get_tree().get_nodes_in_group("Player").front() as PlayerController

# TODO: get the battle character from the parent node
@onready var battle_character := state_machine.get_parent() as BattleCharacter
# One level up is state machine, two levels up is the battle character. The inventory is on the same level
@onready var inventory_manager := get_node("../../../Inventory") as InventoryManager
@onready var battle_state := get_node("/root/GameModeStateMachine/BattleState") as BattleState

# Camera used for raycasts
# We get the node manually here to avoid @onready order shenanigans
@onready var top_down_camera := battle_state.top_down_player.get_node("TopDownPlayerPivot/SpringArm3D/TopDownCamera") as Camera3D


@onready var player_think_ui := battle_state.get_node("PlayerThinkUI") as PlayerThinkUI

var chosen_action: BattleEnums.EPlayerCombatAction = BattleEnums.EPlayerCombatAction.CA_DEFEND

@onready var fire_spell: BaseInventoryItem = preload("res://Scripts/Inventory/Resources/Spells/test_fire_spell.tres")
@onready var heal_spell: BaseInventoryItem = preload("res://Scripts/Inventory/Resources/Spells/test_healing_spell.tres")
@onready var almighty_spell: BaseInventoryItem = preload("res://Scripts/Inventory/Resources/Spells/test_almighty_spell.tres")
@onready var chosen_spell_or_item: BaseInventoryItem = heal_spell


func _ready() -> void:
    Console.add_command("choose_item", _choose_item_command, 1)

    player_think_ui.hide()
    battle_character.OnLeaveBattle.connect(_on_leave_battle)

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

func enter() -> void:
    if battle_character.current_hp <= 0:
        # Players are able to be revived once "dead"
        Transitioned.emit(self, "DeadState")
        return

    player_think_ui.show()
    print(battle_character.character_name + " is thinking about what to do")

    # remember last selected character
    if battle_state.player_selected_character:
        print("Selected character: " + battle_state.player_selected_character.character_name)
    else:
        print("No character selected")


func exit() -> void:
    print(battle_character.character_name + " has stopped thinking")
    player_think_ui.hide()

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
    var ray_result := shoot_ray()

    var position := Vector3.INF
    if ray_result.has("position"):
        position = (ray_result.position as Vector3)
    if position == Vector3.INF:
        print("[Think] No raycast position found")
        return
    if not ray_result.has("collider"):
        print("[Think] No collider found")
        return

    var collider := ray_result.collider as Node3D

    # TODO: I should probably cache the result of find_children
    # to avoid spamming this intensive function
    var children := collider.find_children("BattleCharacter")
    if children.is_empty():
        player_think_ui.update_ground()
        return

    var character := children.front() as BattleCharacter
    if character:
        if character.character_type == BattleEnums.CharacterType.PLAYER:
            if character == battle_state.current_character:
                player_think_ui.update_self()
            else:
                player_think_ui.update_ally(character)

        elif character.character_type == BattleEnums.CharacterType.ENEMY:
            player_think_ui.update_enemy(character)
    else:
        player_think_ui.update_ground()



## Returns an intersect_ray dictionary
func shoot_ray() -> Dictionary:
    # center the raycast origin position if using controller
    var viewport_center := Vector2(top_down_camera.get_viewport().size.x / 2, top_down_camera.get_viewport().size.y / 2)
    var mouse_pos := (top_down_camera.get_viewport().get_mouse_position() if not ControllerHelper.is_using_controller
    else viewport_center)

    var space := top_down_camera.get_world_3d().direct_space_state
    var ray_query := PhysicsRayQueryParameters3D.new()
    ray_query.from = top_down_camera.project_ray_origin(mouse_pos)
    ray_query.to = top_down_camera.project_ray_normal(mouse_pos) * 1000
    ray_query.exclude = [battle_state.top_down_player]
    var result := space.intersect_ray(ray_query)

    return result


func _state_process(_delta: float) -> void: pass

func _state_input(event: InputEvent) -> void:

    if event.is_action_pressed("combat_attack"):
        chosen_action = BattleEnums.EPlayerCombatAction.CA_ATTACK
        Transitioned.emit(self, "ChooseTargetState")

    elif event.is_action_pressed("combat_spellitem"):
        Transitioned.emit(self, "ChooseSpellItemState")
      
    elif event.is_action_pressed("combat_draw"):
        chosen_action = BattleEnums.EPlayerCombatAction.CA_DRAW
        Transitioned.emit(self, "ChooseTargetState")

    elif event.is_action_pressed("combat_move"):
        chosen_action = BattleEnums.EPlayerCombatAction.CA_MOVE
        Transitioned.emit(self, "MoveState")


func _state_unhandled_input(_event: InputEvent) -> void: pass
