extends State
class_name PlayerDrawState

@onready var battle_state := get_node("/root/GameModeStateMachine/BattleState") as BattleState
@onready var draw_ui := battle_state.get_node("PlayerDrawUI") as Control
@onready var draw_label := draw_ui.get_node("Label") as RichTextLabel
@onready var item_display_list := draw_ui.get_node("ItemList") as ItemList

const MASTERY_DRAW_ROLLS := 2

var selected_spell_index := 0

func _ready() -> void:
    draw_ui.hide()
    item_display_list.item_selected.connect(_on_spell_selected)

func enter() -> void:
    print("[DRAW] Entered draw state")
    draw_ui.show()
    draw_label.text = "Choose spell to draw..."
    _populate_draw_list()

func _populate_draw_list() -> void:
    item_display_list.clear()
    var spells := battle_state.player_selected_character.draw_list
    for spell in spells:
        item_display_list.add_item(spell.item_name)
    if item_display_list.item_count > 0:
        item_display_list.select(0)
        selected_spell_index = 0

func _on_spell_selected(index: int) -> void:
    selected_spell_index = index

func draw(target_character: BattleCharacter, current_character: BattleCharacter, cast_immediately: bool = true) -> void:
    print("[DRAW] Player is drawing... ")
    var draw_list := target_character.draw_list
    var drawn_spell := draw_list[selected_spell_index] as SpellItem

    print("[DRAW] Drawn spell: " + drawn_spell.item_name)

    var draw_bonus_d4s := ceili(current_character.stats.get_stat(CharacterStatEntry.ECharacterStat.DrawBonus))
    var draw_bonus := DiceRoll.roll(4, draw_bonus_d4s).total()

    # Mastery gives 2 d6 rolls for drawing instead of 1, but does not affect the draw bonus
    var rolls := 1
    if drawn_spell.spell_affinity in current_character.mastery_elements:
        print("[DRAW] Character has mastery for %s" % [Util.get_enum_name(BattleEnums.EAffinityElement, drawn_spell.spell_affinity)])
        rolls = MASTERY_DRAW_ROLLS

    print("[DRAW] Draw bonus: " + str(draw_bonus))
    var drawn_amount := DiceRoll.roll(6, rolls, draw_bonus).total()
    print("[DRAW] Drawn amount: " + str(drawn_amount))
    

    if cast_immediately:
        var status := drawn_spell.use(current_character, target_character, false)
        print("[DRAW] Final use status: " + Util.get_enum_name(BaseInventoryItem.UseStatus, status))
    else:
        print("[DRAW] Received %s %s!" % [str(drawn_amount), drawn_spell.item_name])
        current_character.inventory.add_item(drawn_spell, drawn_amount)

        if current_character.inventory:
            current_character.inventory.add_item(drawn_spell, drawn_amount)
        else:
            print("[DRAW] Character has no inventory")
    _end_targeting()

func _end_targeting() -> void:
    if not active:
        return
    Transitioned.emit(self, "IdleState")
    battle_state.ready_next_turn()

func _back_to_target() -> void:
    if active:
        Transitioned.emit(self, "ChooseTargetState")

func exit() -> void:
    item_display_list.clear()
    draw_ui.hide()

func _state_process(_delta: float) -> void:
    pass

func _state_physics_process(_delta: float) -> void:
    pass

func _state_input(event: InputEvent) -> void:
    if event.is_action_pressed("ui_cancel"):
        _back_to_target()
    elif event.is_action_pressed("ui_accept"):
        draw(battle_state.player_selected_character, battle_state.current_character, false)

func _state_unhandled_input(_event: InputEvent) -> void:
    pass