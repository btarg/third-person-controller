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

# Sort based on available actions. Used in the inventory UI to prioritize items that the player probably wants to use based on current context.
func sort_items_by_usefulness(a: BaseInventoryItem, b: BaseInventoryItem) -> bool:
    var ally_actions := [BattleEnums.EAvailableCombatActions.ALLY, BattleEnums.EAvailableCombatActions.SELF]
    var a_useful := (a.can_use_on_allies and battle_state.available_actions in ally_actions) or (a.can_use_on_enemies and battle_state.available_actions == BattleEnums.EAvailableCombatActions.ENEMY)
    var b_useful := (b.can_use_on_allies and battle_state.available_actions in ally_actions) or (b.can_use_on_enemies and battle_state.available_actions == BattleEnums.EAvailableCombatActions.ENEMY)
    
    if battle_state.available_actions == BattleEnums.EAvailableCombatActions.GROUND:
        var a_cast_anywhere := a.item_type == BaseInventoryItem.ItemType.SPELL_USE_ANYWHERE
        var b_cast_anywhere := b.item_type == BaseInventoryItem.ItemType.SPELL_USE_ANYWHERE
        if a_cast_anywhere != b_cast_anywhere: return a_cast_anywhere
    
    if a_useful != b_useful: return a_useful
    
    # Prioritize spells based on target's known weaknesses when targeting enemies
    if (battle_state.available_actions == BattleEnums.EAvailableCombatActions.ENEMY 
        and battle_state.player_selected_character 
        and a is SpellItem and b is SpellItem):
        
        var a_spell := a as SpellItem
        var b_spell := b as SpellItem
        var target_internal_name := battle_state.player_selected_character.character_internal_name
        
        # Check if we know the target's affinity to these spell elements
        var a_is_weakness := false
        var b_is_weakness := false
        
        if AffinityLog.is_affinity_logged(target_internal_name, a_spell.spell_element):
            var a_affinity := AffinityLog.get_affinity(target_internal_name, a_spell.spell_element)
            a_is_weakness = (a_affinity == BattleEnums.EAffinityType.WEAK)
        
        if AffinityLog.is_affinity_logged(target_internal_name, b_spell.spell_element):
            var b_affinity := AffinityLog.get_affinity(target_internal_name, b_spell.spell_element)
            b_is_weakness = (b_affinity == BattleEnums.EAffinityType.WEAK)
        
        # Prioritize spells that target known weaknesses
        if a_is_weakness != b_is_weakness: 
            return a_is_weakness
    
    if a is SpellItem and b is SpellItem:
        var a_spell := a as SpellItem
        var b_spell := b as SpellItem
        if battle_state.available_actions in ally_actions:
            var priority_elements := [BattleEnums.EAffinityElement.HEAL, BattleEnums.EAffinityElement.BUFF]
            var a_priority := a_spell.spell_element in priority_elements
            var b_priority := b_spell.spell_element in priority_elements
            if a_priority != b_priority: return a_priority
        return a_spell.spell_element < b_spell.spell_element
    
    return false