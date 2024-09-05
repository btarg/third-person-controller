extends State
class_name PlayerThinkState

# TODO: find a better way to get the BattleCharacter
@onready var player := get_tree().get_nodes_in_group("Player").front() as PlayerController
@onready var battle_character := player.get_node("BattleCharacter") as BattleCharacter
@onready var battle_state := get_node("/root/GameModeStateMachine/BattleState") as BattleState

func _ready() -> void:
    battle_character.LeaveBattle.connect(_on_leave_battle)

func _on_leave_battle() -> void:
    if active:
        _stop_thinking()

func enter() -> void:
    print("PLAYER is thinking about what to do")

func _stop_thinking() -> void:
    Transitioned.emit(self, "IdleState")

func exit() -> void:
    print(battle_character.character_name + " has stopped thinking")

func update(delta: float) -> void: pass

func physics_update(delta: float) -> void: pass

func shoot_ray() -> void:
    var camera := battle_state.top_down_player.camera

    # center the raycast origin position if using controller
    var mouse_pos := camera.get_viewport().get_mouse_position() if not battle_state.is_using_controller else Vector2.ZERO
    print("Raycast origin pos: " + str(mouse_pos))

    var from := camera.project_ray_origin(mouse_pos)
    var to := camera.project_ray_normal(mouse_pos) * 1000
    var space := camera.get_world_3d().direct_space_state
    var ray_query := PhysicsRayQueryParameters3D.new()
    ray_query.from = from
    ray_query.to = to
    ray_query.exclude = [battle_state.top_down_player]
    var result := space.intersect_ray(ray_query)
    if result.size() > 0:
        print(result.collider)
        var character := result.collider.get_node("BattleCharacter") as BattleCharacter
        if character:
            select_character(character)

func select_character(character: BattleCharacter) -> void:
    print("Selected character " + character.character_name)


func input_update(event: InputEvent) -> void:
    if event.is_echo():
        return

    if event.is_action_pressed("left_click"):
        shoot_ray()
    elif event.is_action_pressed("ui_select"):
        print("Player attacks!")
        _stop_thinking()
        battle_character.battle_state.ready_next_turn()

func unhandled_input_update(event: InputEvent) -> void: pass