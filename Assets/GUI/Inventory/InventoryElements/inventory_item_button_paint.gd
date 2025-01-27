extends Control
class_name InventoryItemButtonPaint

@onready var item_label_scroll := $Paint/ScrollContainer as ScrollContainer
@onready var item_name_label := item_label_scroll.get_node("Label") as Label
@onready var count_background := $Paint/CountBG as Panel
@onready var count_label := count_background.get_node("Label") as Label
@onready var item_icon := $Paint/ItemIcon as Sprite2D

var shader_mat: ShaderMaterial
var count_style_box: StyleBoxFlat

var tweens: Array[Tween] = []

const TEXT_COLOR := Color(213, 207, 190, 1)
const COUNT_BACKGROUND_COLOR := Color(217, 217, 217, 1)

const TRANSITION_TIME := 0.3

signal pressed_item

func set_item_name(item_name: String) -> void:
    item_name_label.text = item_name
func set_item_count(count: int) -> void:
    count_label.text = "%03d" % min(count, 999) if count < 999 else "999+"
func set_item_icon(icon: Texture) -> void:
    item_icon.texture = icon

func _ready() -> void:

    # make unique
    shader_mat = $Paint.material.duplicate()
    $Paint.material = shader_mat
    # set shader parameter "progress" to 0.0
    shader_mat.set_shader_parameter("progress", 0.0)

    item_name_label.label_settings.font_color = TEXT_COLOR
    # make unique
    item_name_label.label_settings = item_name_label.label_settings.duplicate()

    item_label_scroll.scroll_horizontal = 0

    count_style_box = count_background.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
    count_background.add_theme_stylebox_override("panel", count_style_box)
    count_style_box.bg_color = COUNT_BACKGROUND_COLOR

    for child in count_background.get_children():
        if child is Label:
            # make unique
            child.label_settings = child.label_settings.duplicate()
            child.label_settings.font_color = Color.BLACK

    focus_entered.connect(_on_focus_entered)
    focus_exited.connect(_on_focus_exited)
    mouse_entered.connect(_on_mouse_entered)


func _gui_input(event: InputEvent) -> void:
    if event.is_pressed() and not event.is_echo():
        if (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT
        or event.is_action_pressed("ui_accept")
        or event.is_action_pressed("ui_select")):
            pressed_item.emit()

func _on_mouse_entered() -> void:
    # call focus_entered
    grab_focus()

func _on_focus_entered() -> void:
    kill_tweens()
    var tween := create_tween()
    tweens.append(tween)
    tween.tween_property(item_name_label.label_settings, "font_color", Color.BLACK, 0.05)
    # tween the paint shader property "progress" to animate the paint effect
    tween.tween_property(shader_mat, "shader_parameter/progress", 0.5, TRANSITION_TIME)\
            .set_trans(Tween.TRANS_SINE)
    
    count_style_box.bg_color = Color.BLACK

    for child in count_background.get_children():
        if child is Label:
            child.label_settings.font_color = TEXT_COLOR

    # after a short delay, tween the scroll container
    var scroll_max := item_name_label.size.x - item_label_scroll.size.x
    if scroll_max <= 0:
        return
    tween.tween_property(item_label_scroll, "scroll_horizontal", scroll_max, 1.0)\
            .set_delay(0.15).set_trans(Tween.TRANS_SINE)
    await tween.finished
    tween = create_tween()
    tweens.append(tween)
    tween.tween_property(item_label_scroll, "scroll_horizontal", 0, 1.0)\
            .set_delay(1).set_trans(Tween.TRANS_SINE)

func _on_focus_exited() -> void:
    kill_tweens()
    shader_mat.set_shader_parameter("progress", 1.0)
    var tween := create_tween()
    tweens.append(tween)
    tween.tween_property(item_name_label.label_settings, "font_color", TEXT_COLOR, 0.05)
    tween.tween_property(shader_mat, "shader_parameter/progress", 0.0, TRANSITION_TIME / 2)

    count_style_box.bg_color = COUNT_BACKGROUND_COLOR

    for child in count_background.get_children():
        if child is Label:
            child.label_settings.font_color = Color.BLACK

    item_label_scroll.scroll_horizontal = 0
    

func kill_tweens() -> void:
    for tween in tweens:
        tween.kill()
    tweens.clear()
