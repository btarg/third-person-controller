extends State
class_name PlayerChooseTargetState

@onready var battle_state := get_node("/root/GameModeStateMachine/BattleState") as BattleState
@onready var think_state := get_node("../ThinkState") as PlayerThinkState

var _can_select_enemies := true
var _can_select_allies := true

var last_selected_index := 0
    
func _ready() -> void:
    BattleSignalBus.BattleEnded.connect(_on_battle_ended)
    battle_state.turn_order_ui.connect("item_selected", _select)

func _on_battle_ended() -> void:
    # return to the default idle state
    if active:
        Transitioned.emit(self, "IdleState")
    else:
        exit()


func _select(index: int) -> void:
    if not active:
        return
    var selected_character: BattleCharacter = battle_state.turn_order[index]
    print("Selecting index: " + str(index))
    print("Selecting: " + selected_character.character_name)
    select_character(selected_character)

func shoot_ray() -> void:
    if not active:
        return

    var camera := battle_state.top_down_player.camera

    # center the raycast origin position if using controller
    var mouse_pos := (camera.get_viewport().get_mouse_position() if not ControllerHelper.is_using_controller
    else Vector2.ZERO)
    print("Raycast origin pos: " + str(mouse_pos))

    var space := camera.get_world_3d().direct_space_state
    var ray_query := PhysicsRayQueryParameters3D.new()
    ray_query.from = camera.project_ray_origin(mouse_pos)
    ray_query.to = camera.project_ray_normal(mouse_pos) * 1000
    ray_query.exclude = [battle_state.top_down_player]
    var result := space.intersect_ray(ray_query)
    if result.size() > 0:
        print(result.collider)
        var character = result.collider.get_node_or_null("BattleCharacter")
        if character:
            select_character(character as BattleCharacter)
        else:
            battle_state.player_selected_character = null

func select_character(character: BattleCharacter) -> void:
    var success := false
    if _can_select_enemies and character.character_type == BattleEnums.CharacterType.ENEMY:
        success = true # can select enemies
    if _can_select_allies and (character.character_type == BattleEnums.CharacterType.PLAYER
    or character.character_type == BattleEnums.CharacterType.FRIENDLY):
        success = true # can select any ally
    if not (_can_select_allies or _can_select_enemies) and character == battle_state.current_character:
        success = true # can only select self

    if success:
        battle_state.player_selected_character = character
        battle_state.selected_target_label.text = "Selected: " + character.character_name

        # Set the focused node to the selected character
        battle_state.top_down_player.focused_node = character.get_parent()

        last_selected_index = battle_state.turn_order.find(character)

    else:
        print("Cannot select " + character.character_name)
        battle_state.player_selected_character = null
        battle_state.selected_target_label.text = "Select a target"
        last_selected_index = 0
    

func enter() -> void:
    var selection := BattleEnums.get_combat_action_selection(think_state.chosen_action, think_state.chosen_spell_or_item)
    _can_select_enemies = selection.can_select_enemies
    _can_select_allies = selection.can_select_allies

    print("Player is choosing a target")
    battle_state.turn_order_ui.show()
    battle_state.turn_order_ui.grab_focus()
    battle_state.turn_order_ui.select(last_selected_index)
    _select(last_selected_index)
    battle_state.selected_target_label.show()


func exit() -> void:
    print("Exiting target selection")
    battle_state.turn_order_ui.hide()
    battle_state.selected_target_label.hide()


func _state_process(_delta: float) -> void: pass
func _state_physics_process(_delta: float) -> void: pass


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
            Transitioned.emit(self, "ChooseSpellItemState")
        else:
            Transitioned.emit(self, "ThinkState")

func _state_unhandled_input(event: InputEvent) -> void:
    if event.is_action_pressed("combat_select_target"):
        shoot_ray()