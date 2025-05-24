extends Area3D
class_name AOESpell


var _area_of_effect_radius: float = 0.0
var _caster: BattleCharacter = null
var _spell_item: SpellItem = null

@onready var battle_state := get_node("/root/GameModeStateMachine/BattleState") as BattleState

var _target_position: Vector3

var _has_already_entered: Array[BattleCharacter] = []

func _init(spell_item: SpellItem, caster: BattleCharacter, target_position: Vector3) -> void:
    _caster = caster
    _spell_item = spell_item
    _target_position = target_position
    # set the area of effect radius
    _area_of_effect_radius = spell_item.area_of_effect_radius

func _ready() -> void:
    # Connect area signals for enter/exit detection
    body_entered.connect(_on_body_entered)
    body_exited.connect(_on_body_exited)
    BattleSignalBus.OnTurnStarted.connect(_on_turn_started)

func _enter_tree() -> void:
    global_position = _target_position
    print("[AOE SPELL NODE] %s cast %s at %s" % [_caster.character_name, _spell_item.item_name, _target_position])

    # Set collision mask to detect players on layer 2
    collision_mask = 2  # Binary: 10 (layer 2)

    # Set up collision detection
    var sphere_shape := SphereShape3D.new()
    sphere_shape.radius = _area_of_effect_radius
    var collision_shape := CollisionShape3D.new()

    collision_shape.shape = sphere_shape
    add_child(collision_shape)
    
    # Add visual mesh
    var mesh_instance := MeshInstance3D.new()
    var sphere_mesh := SphereMesh.new()
    sphere_mesh.radius = _area_of_effect_radius
    sphere_mesh.height = _area_of_effect_radius * 0.5  # a flat sphere: used for ground AOE spells
    mesh_instance.mesh = sphere_mesh
    
    # Create a semi-transparent material
    var material := StandardMaterial3D.new()
    material.albedo_color = Color(1.0, 0.2, 0.2, 0.3)  # Red with transparency
    material.flags_transparent = true
    material.flags_unshaded = true
    material.no_depth_test = true
    mesh_instance.material_override = material
    
    add_child(mesh_instance)
    
    _on_turn_started() # Apply immediately to all characters in the area

    
    

func apply_effect(character: BattleCharacter) -> void:
    if _spell_item.can_use_on(_caster, character, true): # Ignore costs for AOE
        
        _spell_item.use(_caster, character, false)  # Don't consume item for AOE
        print("[AOE SPELL] %s used %s on %s" % [_caster.character_name, _spell_item.item_name, character.character_name])

        _has_already_entered.append(character)

func _on_body_entered(body: Node3D) -> void:
    # Check if the body has a BattleCharacter component
    print("[BODY ENTERED] " + str(body))
    var battle_character := body.get_node_or_null("BattleCharacter") as BattleCharacter
    if battle_character:
        # If character has already been affected, don't do anything
        if battle_character in _has_already_entered:
            return
            
        # Check if the character is currently moving (in PlayerMoveState)
        var character_controller := battle_character.character_controller
        if character_controller and character_controller.free_movement:
            # Character is in movement mode - connect to spend actions signal to apply effect when movement is locked in
            print("[AOE SPELL] %s entered AOE area while moving" % battle_character.character_name)
            _disconnect_actions_signal(battle_character)
            battle_character.OnSpendActions.connect(_on_spend_actions)
        else:
            # Character is not moving, apply effect immediately
            apply_effect(battle_character)

# Apply the effect once we lock in movement
func _on_spend_actions(character: BattleCharacter) -> void:
    print("[AOE SPELL] %s spent actions" % character.character_name)
    apply_effect(character)
    # disconnect the signal after applying the effect to avoid firing multiple times while inside the area just because we spend an action
    _disconnect_actions_signal(character)

func _on_body_exited(body: Node3D) -> void:
    # Check if the body has a BattleCharacter component
    print("[BODY EXITED] " + str(body))
    var battle_character := body.get_node_or_null("BattleCharacter") as BattleCharacter
    if battle_character:
        # disconnect signal
        _disconnect_actions_signal(battle_character)
        
        # Remove from already affected list so they can be affected again if they re-enter
        _has_already_entered.erase(battle_character)

        print("[AOE SPELL] %s exited AOE area" % battle_character.character_name)

func _disconnect_actions_signal(battle_character: BattleCharacter) -> void:
    if battle_character.OnSpendActions.is_connected(_on_spend_actions):
        battle_character.OnSpendActions.disconnect(_on_spend_actions)

func _on_turn_started(_turn_character: BattleCharacter = null) -> void:
    var area_overlapping_bodies := get_overlapping_bodies()
    for body in area_overlapping_bodies:
        print("[BODY FOUND] " + str(body))
        var battle_character := body.get_node_or_null("BattleCharacter") as BattleCharacter
        if battle_character:
            # Only apply effect to characters not currently moving
            var character_controller := battle_character.character_controller
            if not (character_controller and character_controller.free_movement):
                print("[AOE SPELL] %s is in AOE area, applying effect" % battle_character.character_name)
                apply_effect(battle_character)


func _exit_tree() -> void:
    # Clean up any connections when the spell is destroyed
    body_entered.disconnect(_on_body_entered)
    body_exited.disconnect(_on_body_exited)