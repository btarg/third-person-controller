extends State
class_name PlayerChooseSpellItemState

@onready var battle_state := get_node("/root/GameModeStateMachine/BattleState") as BattleState
@onready var think_state := get_node("../ThinkState") as PlayerThinkState

@onready var spell_ui := battle_state.get_node("PlayerChooseSpellitemUi") as Control
func _ready() -> void:
    spell_ui.hide()

func enter() -> void:
    print("[SPELL/ITEM STATE] Choosing spell or item")
    var spell_label := spell_ui.get_node("Label") as RichTextLabel
    
    if think_state.chosen_spell_or_item:
        spell_label.text = "Chosen spell/item: " + think_state.chosen_spell_or_item.item_name
    else:
        spell_label.text = "Choose a spell/item"
    spell_label.text += "\n" + ControllerHelper.get_button_glyph_img_embed("ui_cancel") + " Back"

    spell_ui.show()

func _choose_spell(spell: SpellItem) -> void:
    print("[SPELL/ITEM] Spell chosen: " + spell.item_name)
    think_state.chosen_spell_or_item = spell

    if think_state.chosen_spell_or_item.item_type == BaseInventoryItem.ItemType.SPELL:
        think_state.chosen_action = BattleEnums.EPlayerCombatAction.CA_CAST
    else:
        think_state.chosen_action = BattleEnums.EPlayerCombatAction.CA_ITEM
    Transitioned.emit(self, "ChooseTargetState")

func _end_targeting() -> void:
    if active:
        Transitioned.emit(self, "IdleState")
        battle_state.ready_next_turn()
func _back_to_think() -> void:
    if active:
        Transitioned.emit(self, "ThinkState")

func exit() -> void:
    spell_ui.hide()

func update(_delta: float) -> void: pass
func physics_update(_delta: float) -> void: pass
func input_update(event: InputEvent) -> void:
    if not active or event.is_echo():
        return
    if event.is_action_pressed("ui_cancel"):
        _back_to_think()
    elif (event.is_action_pressed("combat_spellitem")
    or event.is_action_pressed("combat_attack")):
        _choose_spell(think_state.fire_spell)

func unhandled_input_update(_event: InputEvent) -> void: pass