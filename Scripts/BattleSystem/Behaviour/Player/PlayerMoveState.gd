extends State
class_name PlayerMoveState

@onready var battle_state := get_node("/root/GameModeStateMachine/BattleState") as BattleState
@onready var move_ui := battle_state.get_node("PlayerMoveUI") as Control
@onready var move_label := move_ui.get_node("Label") as RichTextLabel

var _current_character: BattleCharacter

@onready var top_down_camera := battle_state.top_down_player.get_node("TopDownPlayerPivot/SpringArm3D/TopDownCamera") as Camera3D


func _ready() -> void:
    move_ui.hide()
    ControllerHelper.OnInputDeviceChanged.connect(_update_label)

func _update_label(_is_using_controller: bool) -> void:
    move_label.text = ControllerHelper.get_button_glyph_img_embed("combat_select_target") + " Move to location\n"
    move_label.text += ControllerHelper.get_button_glyph_img_embed("ui_cancel") + " Cancel"

func enter() -> void:
    move_ui.show()
    _update_label(true)
    _current_character = battle_state.current_character
    

func _end_targeting() -> void:
    if active:
        Transitioned.emit(self, "IdleState")
        battle_state.ready_next_turn()
func _back_to_think() -> void:
    if active:
        Transitioned.emit(self, "ThinkState")


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
        var result := Util.raycast_from_center_or_mouse(top_down_camera, [battle_state.top_down_player.get_rid()])
        var position := Vector3.INF
        if result.has("position"):
            position = (result.position as Vector3)

        if position != Vector3.INF:
            _current_character.character_controller.set_move_target(position)
            print("[Move] Got raycast position: " + str(position))
        else:
            print("[Move] No raycast position found")

    elif event.is_action_pressed("ui_cancel"):
        _current_character.character_controller.stop_moving()