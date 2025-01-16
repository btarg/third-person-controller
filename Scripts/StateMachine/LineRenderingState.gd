extends State
class_name LineRenderingState

@export_group("Target line rendering")
const CURVE_SEGMENTS := 20
const CURVE_HEIGHT_OFFSET := 5.0
const CURVE_TARGET_HEIGHT_OFFSET := 0.1

var line_current_character: BattleCharacter
var line_target_character: BattleCharacter

var _current_line_renderer: LineRenderer3D


var should_render_line : bool = false:
    get:
        return should_render_line
    set(value):
        
        if value and line_current_character:
            var renderer := line_current_character.get_node_or_null("../LineRenderer3D") as LineRenderer3D
            if renderer:
                renderer.material_override = ResourceLoader.load("res://addons/LineRenderer/demo/target_line_renderer.tres") as Material
                _current_line_renderer = renderer
            else:
                print("No line renderer found on current character")
                should_render_line = false
                
        should_render_line = value


var _current_segment := 0

## Called when the state is entered
func enter() -> void: pass
## Called when the state is exited
func exit() -> void:
    cleanup_line_renderers()
## Updates every _process() update (When state is active)
@warning_ignore("UNUSED_PARAMETER")
func _state_process(delta: float) -> void: pass

## Updates every _physics_process() update (When state is active)
func _state_physics_process(_delta: float) -> void:
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
    else line_current_character.get_parent().global_position

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
    else:
        should_render_line = false


func cleanup_line_renderers() -> void:
    _current_segment = 0
    line_current_character = null
    line_target_character = null

    if _current_line_renderer:
        _current_line_renderer.remove_line()

## Updates every _input() update (When state is active)
@warning_ignore("UNUSED_PARAMETER")
func _state_input(event: InputEvent) -> void: pass
## Updates every _unhandled_input() update (When state is active)
@warning_ignore("UNUSED_PARAMETER")
func _state_unhandled_input(event: InputEvent) -> void: pass
