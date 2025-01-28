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
    if not battle_state.player_selected_character:
        return
    var target_character := battle_state.player_selected_character as BattleCharacter
    var current_character := battle_state.current_character

    match think_state.chosen_action:
        BattleEnums.EPlayerCombatAction.CA_ATTACK:
            var attack := BattleManager.process_basic_attack(current_character, target_character)
            if attack == BattleEnums.ESkillResult.SR_OUT_OF_RANGE:
                print("Target out of range!")
            else:
                _end_targeting()
    
        BattleEnums.EPlayerCombatAction.CA_ITEM,\
        BattleEnums.EPlayerCombatAction.CA_CAST:
            var status := think_state.chosen_spell_or_item.use(current_character, target_character)
            print("[SPELL/ITEM] Final use status: " + Util.get_enum_name(BaseInventoryItem.UseStatus, status))
            _end_targeting()
        BattleEnums.EPlayerCombatAction.CA_DRAW:
            Transitioned.emit(self, "DrawState")
        _:
            print("Invalid action")
            _end_targeting()

func _end_targeting() -> void:
    # check if active in case the character has left the battle (ie. died)
    if active:
        print("Ending target selection")
        Transitioned.emit(self, "IdleState")
        battle_state.ready_next_turn()

func _state_input(event: InputEvent) -> void:

    if event.is_action_pressed("ui_select") or event.is_action_pressed("combat_attack"):
        if battle_state.player_selected_character == null:
            print("No character selected!")
            return
        _process_targeting()

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

func _state_unhandled_input(event: InputEvent) -> void:
    if event.is_action_pressed("combat_select_target"):
        var result := Util.raycast_from_center_or_mouse(frelook_camera, [battle_state.top_down_player.get_rid()])
        if result.size() > 0:
            print(result.collider)
            var character := result.collider.get_node_or_null("BattleCharacter") as BattleCharacter
            if character:
                select_character(character)
            else:
                battle_state.select_character(null, false)
