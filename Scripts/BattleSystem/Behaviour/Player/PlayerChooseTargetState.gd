extends State
class_name PlayerChooseTargetState

@onready var battle_state := get_node("/root/GameModeStateMachine/BattleState") as BattleState

var can_select_enemies := true
var can_select_friendlies := true

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
        var character = result.collider.get_node_or_null("BattleCharacter")
        if character:
            select_character(character as BattleCharacter)

func select_character(character: BattleCharacter) -> void:
    var success := false
    if can_select_enemies and character.character_type == BattleEnums.CharacterType.ENEMY:
        success = true
    elif can_select_friendlies and (character.character_type == BattleEnums.CharacterType.PLAYER or character.character_type == BattleEnums.CharacterType.FRIENDLY):
        success = true

    if success:
        battle_state.player_selected_character = character
    else:
        print("Cannot select " + character.character_name)

func enter() -> void:
    print("Player is choosing a target")

func exit() -> void: pass
func update(_delta: float) -> void: pass
func physics_update(_delta: float) -> void: pass

func input_update(event: InputEvent) -> void:
    if event.is_echo():
        return

    elif event.is_action_pressed("ui_cancel"):
        Transitioned.emit(self, "ThinkState") # Go back to thinking state

func unhandled_input_update(event: InputEvent) -> void:
    if event.is_echo():
        return
    if event.is_action_pressed("left_click"):
        shoot_ray()