extends State
class_name PlayerDrawState

@onready var battle_state := get_node("/root/GameModeStateMachine/BattleState") as BattleState
@onready var draw_ui := battle_state.get_node("PlayerDrawUI") as Control

@onready var draw_label := draw_ui.get_node("Label") as RichTextLabel
func _ready() -> void:
    draw_ui.hide()

func enter() -> void:
    print("[DRAW] Entered draw state")
    draw_ui.show()
    draw_label.text = "Drawing spell..."
    draw(battle_state.player_selected_character as BattleCharacter, battle_state.current_character)

func draw(target_character: BattleCharacter, current_character: BattleCharacter, draw_index: int = -1, cast_immediately: bool = true) -> void:

    print("[DRAW] Player is drawing... ")
    var draw_list := target_character.draw_list

    # TODO: manually choose drawn spell
    if draw_index == -1:
        print("[DRAW] Choosing random spell to draw")
        draw_index = randi() % draw_list.size()

    var drawn_spell := draw_list[draw_index] as SpellItem

    print("[DRAW] Drawn spell: " + drawn_spell.item_name)

    var draw_bonus_d4s := ceili(current_character.stats.get_stat(CharacterStatEntry.ECharacterStat.DrawBonus))
    var draw_bonus := DiceRoller.roll_flat(4, draw_bonus_d4s)
    print("[DRAW] Draw bonus: " + str(draw_bonus))
    var drawn_amount := DiceRoller.roll_flat(6, 1, draw_bonus)

    print("[DRAW] Received %s %s!" % [str(drawn_amount), drawn_spell.item_name])
    current_character.inventory.add_item(drawn_spell, drawn_amount)

    # TODO: manually decide whether to stock or cast
    if cast_immediately:
        var status := drawn_spell.use(current_character, target_character)
        print("[DRAW] Final use status: " + Util.get_enum_name(BaseInventoryItem.UseStatus, status))
        _end_targeting()
    else:
        print("[DRAW] Stocking spell for later use")
        if current_character.inventory:
            current_character.inventory.add_item(drawn_spell, drawn_amount)
        else:
            print("[DRAW] Character has no inventory")
    _end_targeting()

func _end_targeting() -> void:
    if active:
        Transitioned.emit(self, "IdleState")
        battle_state.ready_next_turn()
func _back_to_target() -> void:
    if active:
        Transitioned.emit(self, "ChooseTargetState")

func exit() -> void:
    draw_ui.hide()


func update(_delta: float) -> void: pass
func physics_update(_delta: float) -> void: pass
func input_update(event: InputEvent) -> void:
    if event.is_action_pressed("ui_cancel"):
        _back_to_target()

func unhandled_input_update(_event: InputEvent) -> void: pass