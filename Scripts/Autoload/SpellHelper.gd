extends Node
# class_name SpellHelper

var tracked_spell_aoe_nodes: Array[AOESpell] = []

var aoe_spell_resource: BaseInventoryItem = load("res://Scripts/Data/Items/Spells//test_aoe_spell.tres")
@onready var battle_state := get_node("/root/GameModeStateMachine/BattleState") as BattleState

func spawn_aoe_spell_effect(spell: SpellItem, caster: BattleCharacter, spawn_position: Vector3) -> bool:
    if spell.area_of_effect_radius == 0 or spell.item_type != BaseInventoryItem.ItemType.SPELL_USE_ANYWHERE:
        print("[AOE SPELL] Spell %s is not an AOE spell" % spell.item_name)
        return false
    var aoe_spell: AOESpell = AOESpell.new(spell, caster, spawn_position)
    get_tree().get_root().add_child(aoe_spell)

    # we only need to track Sustain spells, so we can remove the spell when a condition is met
    # TODO: spend one action to sustain the spell every turn (optionally) - we need a UI for this
    if spell.ttl_turns == -1:
        tracked_spell_aoe_nodes.append(aoe_spell)

    print("[AOE SPELL] Spawned AOE spell effect at %s" % spawn_position)
    return true


# on middle click input spawn aoe spell effect where mouse is pointing in 3d
func _input(event: InputEvent) -> void:
    if event is InputEventMouseButton and event.is_pressed():
        if event.button_index == MOUSE_BUTTON_MIDDLE:
            print("Middle mouse button pressed")
            var raycast_result := Util.raycast_from_center_or_mouse(
                battle_state.top_down_player.camera)
            if raycast_result:
                var target_position: Vector3 = raycast_result.position
                spawn_aoe_spell_effect(aoe_spell_resource, battle_state.current_character, target_position)
            else:
                print("No raycast result")
