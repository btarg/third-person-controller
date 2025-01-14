extends State
class_name PlayerMoveState

@onready var battle_state := get_node("/root/GameModeStateMachine/BattleState") as BattleState
@onready var move_ui := battle_state.get_node("PlayerMoveUI") as Control
@onready var move_label := move_ui.get_node("Label") as RichTextLabel

var _current_character: BattleCharacter

@onready var top_down_camera := battle_state.top_down_player.get_node("TopDownPlayerPivot/SpringArm3D/TopDownCamera") as Camera3D


func _ready() -> void:
    move_ui.hide()

func enter() -> void:
    print("[MOVE] Entered move state!!!!!")
    move_ui.show()

    move_label.text = ControllerHelper.get_button_glyph_img_embed("combat_select_target") + " Move to location\n"
    move_label.text += ControllerHelper.get_button_glyph_img_embed("ui_cancel") + " Cancel"

    _current_character = battle_state.current_character
    

func _end_targeting() -> void:
    if active:
        Transitioned.emit(self, "IdleState")
        battle_state.ready_next_turn()
func _back_to_think() -> void:
    if active:
        Transitioned.emit(self, "ThinkState")

func shoot_ray() -> void:

    if not active:
        return

    # center the raycast origin position if using controller
    var viewport_center := Vector2(top_down_camera.get_viewport().size.x / 2, top_down_camera.get_viewport().size.y / 2)
    var mouse_pos := (top_down_camera.get_viewport().get_mouse_position() if not ControllerHelper.is_using_controller
    else viewport_center)
    print("[Move] Raycast origin 2d position: " + str(mouse_pos))

    var space := top_down_camera.get_world_3d().direct_space_state
    var ray_query := PhysicsRayQueryParameters3D.new()
    ray_query.from = top_down_camera.project_ray_origin(mouse_pos)
    ray_query.to = top_down_camera.project_ray_normal(mouse_pos) * 1000
    ray_query.exclude = [battle_state.top_down_player, top_down_camera.get_parent().get_parent()]
    var result := space.intersect_ray(ray_query)

    var position := Vector3.INF
    if result.has("position"):
        position = (result.position as Vector3)

    if position != Vector3.INF:
        _current_character.character_controller.set_move_target(position)
        print("[Move] Got raycast position: " + str(position))
    else:
        print("[Move] No raycast position found")

func exit() -> void:
    move_ui.hide()
    if _current_character:
        _current_character.character_controller.stop_moving()


func _state_process(_delta: float) -> void: pass
func _state_physics_process(_delta: float) -> void: pass
func _state_input(event: InputEvent) -> void:
    if event.is_action_pressed("ui_cancel"):
        _back_to_think()
func _state_unhandled_input(event: InputEvent) -> void:
    if event.is_action_pressed("combat_select_target"):
        shoot_ray()
    elif event.is_action_pressed("ui_cancel"):
        _current_character.character_controller.stop_moving()