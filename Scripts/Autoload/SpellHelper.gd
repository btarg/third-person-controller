extends Node

var tracked_spell_aoe_nodes: Array = []
@onready var battle_state := GameModeStateMachine.get_node("BattleState") as BattleState

const MASTERY_DRAW_ROLLS := 2

func _ready() -> void:
    Console.add_command("add_item", _add_item_command, ["item_id", "amount"], 2, "Adds an item to the current character's inventory. Usage: add_item <item_id> <amount>")

func _add_item_command(item_id:String, amount:String) -> void:
    print("[ADD_ITEM] Adding item %s with amount %s" % [item_id, amount])
    if not battle_state.current_character:
        return
    
    var item: Item = load("res://Scripts/Data/Items/%s.tres" % item_id)
    if not item:
        print("[ADD_ITEM] Item %s not found!" % item_id)
        return
    battle_state.current_character.inventory.add_item(item, int(amount))

func process_basic_attack(attacker: BattleCharacter, target: BattleCharacter) -> BattleEnums.ESkillResult:
    var attacker_position: Vector3 = attacker.get_parent().global_position
    var target_position: Vector3 = target.get_parent().global_position

    var distance: float = attacker_position.distance_to(target_position)
    var attack_range := attacker.stats.get_stat(CharacterStatEntry.ECharacterStat.AttackRange)
    if distance > attack_range:
        print("[ATTACK] Target out of range!")
        return BattleEnums.ESkillResult.SR_OUT_OF_RANGE

    await battle_state.message_ui.show_messages(["Attack"])

    print("%s attacks %s with %s!" % [attacker.character_name, target.character_name, 
        Util.get_enum_name(BattleEnums.EAffinityElement, attacker.basic_attack_element)])
    
    var AC := ceili(target.stats.get_stat(CharacterStatEntry.ECharacterStat.ArmourClass))
    var luck := ceili(attacker.stats.get_stat(CharacterStatEntry.ECharacterStat.Luck))


    var attack_roll := DiceRoll.roll(20, 1, AC, luck) # use luck as bonus
    var phys_str := ceili(attacker.stats.get_stat(CharacterStatEntry.ECharacterStat.PhysicalStrength))
    var damage_roll := DiceRoll.roll(20, 1, phys_str)

    var result := target.take_damage(attacker, [damage_roll], attack_roll, attacker.basic_attack_element)
    print("[ATTACK] Result: " + Util.get_enum_name(BattleEnums.ESkillResult, result))
    return result

## This function should be used for spawning radius AOE spells without requiring a BattleCharacter (spawn at position)
func create_area_of_effect(spell: Item, caster: BattleCharacter, spawn_position: Vector3, aim_direction: Vector3 = Vector3.FORWARD) -> bool:
    if spell.area_of_effect_radius == 0 or spell.item_type != Item.ItemType.FIELD_SPELL:
        print("[AOE] Invalid spell for AOE: radius=%.1f, type=%s" % [spell.area_of_effect_radius, Item.ItemType.keys()[spell.item_type]])
        return false

    # Create a persistent SpellArea with trigger behavior, passing the aim direction
    var aoe_area = PersistentSpellArea.new(spell, caster, spawn_position, aim_direction)
    
    print("[AOE] Created spell area with aim direction: %s" % aim_direction)
    
    get_tree().get_root().add_child(aoe_area)

    # we only need to track Sustain spells, so we can remove the spell when a condition is met
    # TODO: spend one action to sustain the spell every turn (optionally) - we need a UI for this
    if spell.ttl_turns == -1:
        tracked_spell_aoe_nodes.push_back(aoe_area)

    print("[AOE] Spawned AOE spell effect at %s" % spawn_position)
    return true

func draw_spell(target_character: BattleCharacter, current_character: BattleCharacter, selected_spell_index: int = 0, cast_immediately: bool = false) -> void:

    if selected_spell_index < 0 or selected_spell_index >= target_character.draw_list.size():
        return

    var drawn_spell := target_character.draw_list[selected_spell_index] as Item

    print("[DRAW] Drawn spell: " + drawn_spell.item_name)

    var draw_bonus_d4s := ceili(current_character.stats.get_stat(CharacterStatEntry.ECharacterStat.Luck))
    var draw_bonus := DiceRoll.roll(4, draw_bonus_d4s).total()

    # Mastery gives 2 d6 rolls for drawing instead of 1, but does not affect the draw_spell bonus
    var rolls := 1
    if drawn_spell.spell_element in current_character.mastery_elements:
        print("[DRAW] Character has mastery for %s" % [Util.get_enum_name(BattleEnums.EAffinityElement, drawn_spell.spell_element)])
        rolls = MASTERY_DRAW_ROLLS

    print("[DRAW] Draw bonus: " + str(draw_bonus))
    var drawn_amount := DiceRoll.roll(6, rolls, draw_bonus).total()
    print("[DRAW] Drawn amount: " + str(drawn_amount))
    

    if cast_immediately:
        await battle_state.message_ui.show_messages([drawn_spell.item_name])
        var status: Item.UseStatus = drawn_spell.activate(current_character, target_character, false)
        print("[DRAW] Final use status: " + Util.get_enum_name(Item.UseStatus, status))
    else:
        
        if current_character.inventory:
            current_character.inventory.add_item(drawn_spell, drawn_amount)
            print("[DRAW] Received %s %s!" % [str(drawn_amount), drawn_spell.item_name])
            var draw_display_string := "%s drew %s %ss"
            if current_character.mastery_elements.has(drawn_spell.spell_element):
                draw_display_string += " (Mastery)"

            await battle_state.message_ui.show_messages([draw_display_string % [current_character.character_name, str(drawn_amount), drawn_spell.item_name]])
        else:
            print("[DRAW] Character has no inventory")

    if not current_character.is_spell_familiar(drawn_spell):
        current_character.add_familiar_spell(drawn_spell)


# Sort based on available actions. Used in the inventory UI to prioritize items that the player probably wants to use based on current context.
func sort_items_by_usefulness(a: Item, b: Item) -> bool:
    var ally_actions := [BattleEnums.EAvailableCombatActions.ALLY, BattleEnums.EAvailableCombatActions.SELF]
    var a_useful := (a.can_use_on_allies and battle_state.available_actions in ally_actions) or (a.can_use_on_enemies and battle_state.available_actions == BattleEnums.EAvailableCombatActions.ENEMY)
    var b_useful := (b.can_use_on_allies and battle_state.available_actions in ally_actions) or (b.can_use_on_enemies and battle_state.available_actions == BattleEnums.EAvailableCombatActions.ENEMY)
    
    if battle_state.available_actions == BattleEnums.EAvailableCombatActions.GROUND:
        var a_cast_anywhere := a.item_type == Item.ItemType.FIELD_SPELL
        var b_cast_anywhere := b.item_type == Item.ItemType.FIELD_SPELL
        if a_cast_anywhere != b_cast_anywhere: return a_cast_anywhere
    
    if a_useful != b_useful: return a_useful
    
    # Prioritize spells based on target's known weaknesses when targeting enemies
    if (battle_state.available_actions == BattleEnums.EAvailableCombatActions.ENEMY 
        and battle_state.player_selected_character 
        and a.item_type in [Item.ItemType.BATTLE_SPELL, Item.ItemType.FIELD_SPELL] and b.item_type in [Item.ItemType.BATTLE_SPELL, Item.ItemType.FIELD_SPELL]):
        
        var a_spell := a
        var b_spell := b
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
    
    if a.item_type in [Item.ItemType.BATTLE_SPELL, Item.ItemType.FIELD_SPELL] and b.item_type in [Item.ItemType.BATTLE_SPELL, Item.ItemType.FIELD_SPELL]:
        var a_spell := a
        var b_spell := b
        if battle_state.available_actions in ally_actions:
            var priority_elements := [BattleEnums.EAffinityElement.HEAL, BattleEnums.EAffinityElement.BUFF]
            var a_priority := a_spell.spell_element in priority_elements
            var b_priority := b_spell.spell_element in priority_elements
            if a_priority != b_priority: return a_priority
        return a_spell.spell_element < b_spell.spell_element
    
    return false
