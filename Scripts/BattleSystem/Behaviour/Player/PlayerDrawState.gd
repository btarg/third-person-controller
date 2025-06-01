extends State
class_name PlayerDrawState

@onready var battle_state := GameModeStateMachine.get_node("BattleState") as BattleState
@onready var battle_character := state_machine.get_parent() as BattleCharacter

@onready var draw_ui := battle_state.get_node("PlayerDrawUI") as Control
@onready var draw_label := draw_ui.get_node("Label") as RichTextLabel
@onready var item_display_list := draw_ui.get_node("ItemList") as ItemList

# TODO: should this be a stat on the character?
const MASTERY_DRAW_ROLLS := 2

var selected_spell_index := 0

func _ready() -> void:
    draw_ui.hide()
    item_display_list.item_selected.connect(_on_spell_selected)
    ControllerHelper.OnInputDeviceChanged.connect(_update_label)
    
func enter() -> void:
    print("[DRAW] Entered draw state")
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

func draw(target_character: BattleCharacter, current_character: BattleCharacter, cast_immediately: bool = false) -> void:
    print("[DRAW] Player is drawing... ")
    var draw_list := target_character.draw_list
    var drawn_spell := draw_list[selected_spell_index] as SpellItem

    print("[DRAW] Drawn spell: " + drawn_spell.item_name)

    var draw_bonus_d4s := ceili(current_character.stats.get_stat(CharacterStatEntry.ECharacterStat.Luck))
    var draw_bonus := DiceRoll.roll(4, draw_bonus_d4s).total()

    # Mastery gives 2 d6 rolls for drawing instead of 1, but does not affect the draw bonus
    var rolls := 1
    if drawn_spell.spell_element in current_character.mastery_elements:
        print("[DRAW] Character has mastery for %s" % [Util.get_enum_name(BattleEnums.EAffinityElement, drawn_spell.spell_element)])
        rolls = MASTERY_DRAW_ROLLS

    print("[DRAW] Draw bonus: " + str(draw_bonus))
    var drawn_amount := DiceRoll.roll(6, rolls, draw_bonus).total()
    print("[DRAW] Drawn amount: " + str(drawn_amount))
    

    if cast_immediately:
        await battle_state.message_ui.show_messages([drawn_spell.item_name])
        var status := drawn_spell.use(current_character, target_character, false)
        print("[DRAW] Final use status: " + Util.get_enum_name(BaseInventoryItem.UseStatus, status))
    else:
        
        if current_character.inventory:
            current_character.inventory.add_item(drawn_spell, drawn_amount)
            print("[DRAW] Received %s %s!" % [str(drawn_amount), drawn_spell.item_name])
            var draw_display_string := "%s drew %s %ss"
            if current_character.mastery_elements.has(drawn_spell.spell_element):
                draw_display_string += " (Mastery)"

            await battle_state.message_ui.show_messages([draw_display_string % [current_character.character_name, str(drawn_amount), drawn_spell.item_name]])
        else:
            print("[DRAW] Character has no inventory")

    if not current_character.is_spell_familiar(drawn_spell):
        current_character.add_familiar_spell(drawn_spell)

    _end_targeting()

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
        draw(battle_state.player_selected_character, battle_state.current_character, false)
    elif event.is_action_pressed("combat_spellitem"):
        draw(battle_state.player_selected_character, battle_state.current_character, true)

func _state_unhandled_input(_event: InputEvent) -> void:
    pass