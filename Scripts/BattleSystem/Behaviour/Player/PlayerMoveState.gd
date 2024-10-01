extends State
class_name PlayerMoveState

@onready var battle_state := get_node("/root/GameModeStateMachine/BattleState") as BattleState
@onready var move_ui := battle_state.get_node("PlayerMoveUI") as Control
@onready var move_label := move_ui.get_node("Label") as RichTextLabel

func _ready() -> void:
    move_ui.hide()

func enter() -> void:
    print("[MOVE] Entered move state!!!!!")
    move_ui.show()

    move_label.text = ControllerHelper.get_button_glyph_img_embed("combat_select_target") + " Move to location\n"
    move_label.text += ControllerHelper.get_button_glyph_img_embed("ui_cancel") + " Cancel"

func _end_targeting() -> void:
    if active:
        Transitioned.emit(self, "IdleState")
        battle_state.ready_next_turn()
func _back_to_think() -> void:
    if active:
        Transitioned.emit(self, "ThinkState")

func shoot_ray() -> void:

    # TODO: use up movement meter when moving around
    # Once the meter is empty we should not be able to move anymore

    if not active:
        return

    var camera := battle_state.top_down_player.camera

    # center the raycast origin position if using controller
    var mouse_pos := (camera.get_viewport().get_mouse_position() if not ControllerHelper.is_using_controller
    else Vector2.ZERO)
    print("Raycast origin pos: " + str(mouse_pos))

    var space := camera.get_world_3d().direct_space_state
    var ray_query := PhysicsRayQueryParameters3D.new()
    ray_query.from = camera.project_ray_origin(mouse_pos)
    ray_query.to = camera.project_ray_normal(mouse_pos) * 1000
    ray_query.exclude = [battle_state.top_down_player]
    var result := space.intersect_ray(ray_query)

    var position := result.position as Vector3
    if position:
        battle_state.current_character.character_controller.set_move_target(position)


func exit() -> void:
    move_ui.hide()
func update(_delta: float) -> void: pass
func physics_update(_delta: float) -> void: pass
func input_update(event: InputEvent) -> void:
    if event.is_action_pressed("ui_cancel"):
        _back_to_think()
func unhandled_input_update(event: InputEvent) -> void:
    if event.is_action_pressed("combat_select_target"):
        shoot_ray()