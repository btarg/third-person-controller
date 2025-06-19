extends State
class_name PlayerDrawState

@onready var battle_state := GameModeStateMachine.get_node("BattleState") as BattleState
@onready var battle_character := state_machine.get_parent() as BattleCharacter

@onready var draw_ui := battle_state.get_node("PlayerDrawUI") as Control
@onready var draw_label := draw_ui.get_node("Label") as RichTextLabel
@onready var item_display_list := draw_ui.get_node("ItemList") as ItemList

var selected_spell_index := 0

func _ready() -> void:
    draw_ui.hide()
    item_display_list.item_selected.connect(_on_spell_selected)
    ControllerHelper.OnInputDeviceChanged.connect(_update_label)
    
func enter() -> void:
    print("[DRAW] Entered draw_spell state")
    draw_ui.show()

    _populate_draw_list()
    _update_label()

func _populate_draw_list() -> void:
    item_display_list.clear()
    var spells := battle_state.player_selected_character.draw_list
    for spell in spells:
        if battle_state.current_character.is_spell_familiar(spell):
            item_display_list.add_item(spell.item_name)
        else:
            item_display_list.add_item("???")
    if item_display_list.item_count > 0:
        item_display_list.select(0)
        selected_spell_index = 0


func _on_spell_selected(index: int) -> void:
    selected_spell_index = index

func _end_targeting() -> void:
    if not active:
        return
    _back_to_think()
    battle_character.spend_actions(1)

func _back_to_think() -> void:
    if active:
        Transitioned.emit(self, "ThinkState")

func exit() -> void:
    item_display_list.clear()
    draw_ui.hide()

func _state_process(_delta: float) -> void:
    pass

func _state_physics_process(_delta: float) -> void:
    item_display_list.grab_focus()

func _update_label() -> void:
    var drawtext := ""

    # Controller glyphs for drawing
    drawtext = ControllerHelper.get_button_glyph_img_embed("combat_attack") + " Stock\n"
    drawtext += ControllerHelper.get_button_glyph_img_embed("combat_spellitem") + " Cast\n"
    drawtext += ControllerHelper.get_button_glyph_img_embed("ui_cancel") + " Back\n"

    draw_label.text = drawtext

func _state_input(event: InputEvent) -> void:
    if event.is_action_pressed("ui_cancel"):
        _back_to_think()
    elif event.is_action_pressed("combat_attack"):
        SpellHelper.draw_spell(battle_state.player_selected_character, battle_state.current_character, selected_spell_index, false)
    elif event.is_action_pressed("combat_spellitem"):
        SpellHelper.draw_spell(battle_state.player_selected_character, battle_state.current_character, selected_spell_index, true)

    _end_targeting()

func _state_unhandled_input(_event: InputEvent) -> void:
    pass