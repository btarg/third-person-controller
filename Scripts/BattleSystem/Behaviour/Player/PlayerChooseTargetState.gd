extends LineRenderingState
class_name PlayerChooseTargetState

@onready var battle_state := get_node("/root/GameModeStateMachine/BattleState") as BattleState
@onready var think_state := get_node("../ThinkState") as PlayerThinkState

var _can_select_enemies := true
var _can_select_allies := true

var last_selected_index := 0

@onready var frelook_camera := battle_state.top_down_player.get_node("TopDownPlayerPivot/SpringArm3D/TopDownCamera") as Camera3D

func _ready() -> void:
    BattleSignalBus.OnBattleEnded.connect(_on_battle_ended)

func _on_battle_ended() -> void:
    # return to the default idle state
    if active:
        Transitioned.emit(self, "IdleState")
    else:
        exit()


func select_character(character: BattleCharacter) -> void:
    var success := false
    if _can_select_enemies and character.character_type == BattleEnums.ECharacterType.ENEMY:
        success = true # can select enemies
    if _can_select_allies and (character.character_type == BattleEnums.ECharacterType.PLAYER
    or character.character_type == BattleEnums.ECharacterType.FRIENDLY):
        success = true # can select any ally
    if not (_can_select_allies or _can_select_enemies) and character == battle_state.current_character:
        success = true # can only select self

    cleanup_line_renderers()

    if success:
        battle_state.select_character(character)

        match think_state.chosen_action:
            BattleEnums.EPlayerCombatAction.CA_ATTACK:
                battle_state.selected_target_label.text = "Attacking: "
            BattleEnums.EPlayerCombatAction.CA_CAST:
                battle_state.selected_target_label.text = "Casting spell on: "
            BattleEnums.EPlayerCombatAction.CA_ITEM:
                battle_state.selected_target_label.text = "Using item on: "
            BattleEnums.EPlayerCombatAction.CA_DRAW:
                battle_state.selected_target_label.text = "Drawing from: "
            _:
                battle_state.selected_target_label.text = "Selecting: "

        battle_state.selected_target_label.text += character.character_name

        # Set the focused node to the selected character
        battle_state.top_down_player.focused_node = character.get_parent()

        var selected_self := character == battle_state.current_character
        if not selected_self:

            line_target_character = character
            line_current_character = battle_state.current_character

            should_render_line = true

    else:
        should_render_line = false

        print("Cannot select " + character.character_name)
        battle_state.select_character(null, false)
        battle_state.selected_target_label.text = "Select a target"
        last_selected_index = 0


func enter() -> void:
    var selection := BattleEnums.get_combat_action_selection(think_state.chosen_action, think_state.chosen_spell_or_item)
    _can_select_enemies = selection.can_select_enemies
    _can_select_allies = selection.can_select_allies

    select_character(battle_state.player_selected_character)
    
    battle_state.selected_target_label.show()


func exit() -> void:
    print("Exiting target selection")
    battle_state.selected_target_label.hide()
    super.exit()


func _state_process(_delta: float) -> void: pass

func _state_physics_process(_delta: float) -> void:
    super._state_physics_process(_delta)

func _process_targeting() -> void:
    if not battle_state.player_selected_character or not battle_state.current_character:
        return

    var target_character := battle_state.player_selected_character as BattleCharacter
    var current_character := battle_state.current_character

    
    if not target_character.is_inside_tree():
        return


    match think_state.chosen_action:
        BattleEnums.EPlayerCombatAction.CA_ATTACK:
            var attack := process_basic_attack(current_character, target_character)
            if attack == BattleEnums.ESkillResult.SR_OUT_OF_RANGE:
                print("Target out of range!")
            else:
                _end_targeting()
    
        BattleEnums.EPlayerCombatAction.CA_ITEM,\
        BattleEnums.EPlayerCombatAction.CA_CAST:
            await battle_state.message_ui.show_messages([think_state.chosen_spell_or_item.item_name])
            var status := think_state.chosen_spell_or_item.use(current_character, target_character)
            print("[SPELL/ITEM] Final use status: " + Util.get_enum_name(BaseInventoryItem.UseStatus, status))
            _end_targeting()
        BattleEnums.EPlayerCombatAction.CA_DRAW:
            Transitioned.emit(self, "DrawState")
        _:
            print("Invalid action")
            _end_targeting()

func process_basic_attack(attacker: BattleCharacter, target: BattleCharacter) -> BattleEnums.ESkillResult:
    var attacker_position := attacker.get_parent().global_position as Vector3
    var target_position := target.get_parent().global_position as Vector3

    var distance := attacker_position.distance_to(target_position)
    var attack_range := attacker.stats.get_stat(CharacterStatEntry.ECharacterStat.AttackRange)
    if distance > attack_range:
        print("[ATTACK] Target out of range! (Distance: " + str(distance) + ", Range: " + str(range) + ")")
        return BattleEnums.ESkillResult.SR_OUT_OF_RANGE

    # message
    battle_state.message_ui.show_messages(["Attack"])


    print("%s attacks %s with %s!" % [attacker.character_name, target.character_name, Util.get_enum_name(BattleEnums.EAffinityElement, attacker.basic_attack_element)])
    var AC : float = target.stats.get_stat(CharacterStatEntry.ECharacterStat.ArmourClass)
    print("[ATTACK] Armour class: " + str(AC))
    
    var attack_roll := DiceRoll.roll(20, 1, ceil(AC))
    print("[ATTACK] Attack Roll: " + str(attack_roll))
    print("[ATTACK] Attack Roll Total: " + str(attack_roll.total()))

    var damage_roll := DiceRoll.roll(20, 1)
    # TODO: attacks do damage based on an animation, not instantly

    var result := target.take_damage(attacker, [damage_roll], attack_roll, attacker.basic_attack_element)
    print("[ATTACK] Result: " + Util.get_enum_name(BattleEnums.ESkillResult, result))

    return result

func _end_targeting() -> void:
    # check if active in case the character has left the battle (ie. died)
    if not active:
        return

    print("Ending target selection")
    Transitioned.emit(self, "IdleState")


    battle_state.ready_next_turn()

func _state_input(event: InputEvent) -> void:

    if event.is_action_pressed("ui_select") or event.is_action_pressed("combat_attack"):
        if battle_state.player_selected_character == null:
            print("No character selected!")
            return
        await _process_targeting()

    elif event.is_action_pressed("ui_page_down"):
        print("Removing selected character from battle...")
        if battle_state.player_selected_character:
            battle_state.leave_battle(battle_state.player_selected_character)

    elif event.is_action_pressed("ui_cancel"):
        if (think_state.chosen_action == BattleEnums.EPlayerCombatAction.CA_CAST
        or think_state.chosen_action == BattleEnums.EPlayerCombatAction.CA_ITEM):
            print(">>>>> Going back to the spell/item selection state")
            Transitioned.emit(self, "ChooseSpellItemState")
        else:
            Transitioned.emit(self, "ThinkState")
