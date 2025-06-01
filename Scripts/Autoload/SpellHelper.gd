extends Node
# class_name SpellHelper

var tracked_spell_aoe_nodes: Array[AOESpell] = []

var aoe_spell_resource: BaseInventoryItem = load("res://Scripts/Data/Items/Spells//test_aoe_spell.tres")
@onready var battle_state := GameModeStateMachine.get_node("BattleState") as BattleState


## Calling Spellitem#use on an AOE spell will not spawn the radius, but rather apply the effect to the target character.
## This function will handle both AOE spells and normal items/spells.
func use_item_or_aoe(item: BaseInventoryItem, user_character: BattleCharacter, target_character: BattleCharacter, update_inventory: bool = false) -> BaseInventoryItem.UseStatus:
    if item is SpellItem:
        var spell_item := item as SpellItem
        if spell_item.item_type == BaseInventoryItem.ItemType.FIELD_SPELL_PLACE:
            # If the spell is an AOE spell, we need to spawn it at the target position (get parent because BattleCharacter is not a 3D node by default)
            if not create_area_of_effect_radius(spell_item, user_character, target_character.get_parent().global_position):
                return BaseInventoryItem.UseStatus.SPELL_FAIL
        else:
            # Otherwise, use the spell normally
            return spell_item.use(user_character, target_character, update_inventory)
    # If it's not a spell, just use the item normally
    return item.use(user_character, target_character)

## This function should be used for spawning radius AOE spells without requiring a BattleCharacter (spawn at position)
func create_area_of_effect_radius(spell: SpellItem, caster: BattleCharacter, spawn_position: Vector3) -> bool:
    if spell.area_of_effect_radius == 0 or spell.item_type != BaseInventoryItem.ItemType.FIELD_SPELL_PLACE:
        print("[AOE SPELL] Spell %s is not an AOE spell" % spell.item_name)
        return false

    # TODO: AOE nodes should not be instant, they should have a node which spawns them in with animation e.g. a bomb,
    # which upon colliding with something spawns the AOE node at its position.
    # Spawn AOE
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
        var a_cast_anywhere := a.item_type == BaseInventoryItem.ItemType.FIELD_SPELL_PLACE
        var b_cast_anywhere := b.item_type == BaseInventoryItem.ItemType.FIELD_SPELL_PLACE
        if a_cast_anywhere != b_cast_anywhere: return a_cast_anywhere
    
    if a_useful != b_useful: return a_useful
    
    # Prioritize spells based on target's known weaknesses when targeting enemies
    if (battle_state.available_actions == BattleEnums.EAvailableCombatActions.ENEMY 
        and battle_state.player_selected_character 
        and a is SpellItem and b is SpellItem):
        
        var a_spell := a as SpellItem
        var b_spell := b as SpellItem
        var target_internal_name := battle_state.player_selected_character.character_internal_name
        
        # Get affinity priorities (WEAK=0, NEUTRAL=1, RESIST=2, IMMUNE=3, REFLECT=4, ABSORB=5)
        var a_affinity_priority := 1
        var b_affinity_priority := 1
        
        if AffinityLog.is_affinity_logged(target_internal_name, a_spell.spell_element):
            var a_affinity := AffinityLog.get_affinity(target_internal_name, a_spell.spell_element)
            a_affinity_priority = a_affinity as int
        
        if AffinityLog.is_affinity_logged(target_internal_name, b_spell.spell_element):
            var b_affinity := AffinityLog.get_affinity(target_internal_name, b_spell.spell_element)
            b_affinity_priority = b_affinity as int
        
        # Prioritize lower priority values (WEAK first, then NEUTRAL, etc.)
        if a_affinity_priority != b_affinity_priority: 
            return a_affinity_priority < b_affinity_priority
    
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