extends LineRenderingState
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

    # Only render line for enemies and allies
    if (battle_state.available_actions in 
    [BattleEnums.EAvailableCombatActions.NONE,
    BattleEnums.EAvailableCombatActions.SELF,
    BattleEnums.EAvailableCombatActions.GROUND]):
        should_render_line = false

    else:
        line_current_character = battle_state.current_character
        line_target_character = battle_state.player_selected_character
        should_render_line = true

func _choose_spell(spell: SpellItem) -> void:
    print("[SPELL/ITEM] Spell chosen: " + spell.item_name)
    think_state.chosen_spell_or_item = spell

    if think_state.chosen_spell_or_item.item_type == BaseInventoryItem.ItemType.SPELL:
        think_state.chosen_action = BattleEnums.EPlayerCombatAction.CA_CAST
    else:
        think_state.chosen_action = BattleEnums.EPlayerCombatAction.CA_ITEM

    if think_state.chosen_spell_or_item.can_use_on(
        battle_state.current_character, battle_state.player_selected_character):
        Transitioned.emit(self, "ChooseTargetState")
    else:
        print("[SPELL/ITEM] Cannot use " + think_state.chosen_spell_or_item.item_name + " on " + battle_state.player_selected_character.character_name)

func _end_targeting() -> void:
    if active:
        Transitioned.emit(self, "IdleState")
        battle_state.ready_next_turn()
func _back_to_think() -> void:
    if active:
        Transitioned.emit(self, "ThinkState")

func exit() -> void:
    should_render_line = false
    spell_ui.hide()
    super.exit()

func _state_process(_delta: float) -> void: pass
func _state_physics_process(_delta: float) -> void:
    super._state_physics_process(_delta)


func _state_input(event: InputEvent) -> void:
    if event.is_action_pressed("ui_cancel"):
        _back_to_think()
    elif (event.is_action_pressed("combat_spellitem")
    or event.is_action_pressed("combat_attack")):
        # TODO: use UI for choosing spells
        _choose_spell(think_state.heal_spell)

func _state_unhandled_input(_event: InputEvent) -> void: pass