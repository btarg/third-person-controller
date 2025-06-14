class_name SpellItem extends BaseInventoryItem

## TODO: allow normal items to be AOE, so we can have molotovs or grenades.
## It might be better to combine everything into SpellItem and just change
## the visuals for non-spell items, but have them act the same as spells anyway.
@export_group("AOE")
enum TargetType {
    NONE,
    FIXED_AIM_FROM_CHAR,  ## Aim the AOE from the player
    FREE_SELECT   ## Aim the AOE from the mouse cursor position
}
@export var target_type: TargetType = TargetType.NONE
@export var area_type := AreaUtils.SpellAreaType.CIRCLE
## Radius also acts as the length for line and cone area types
@export var area_of_effect_radius: float = 0.0
## only applies to line area type
@export var line_width: float = 0.0
## only applies to cone area type
@export var cone_angle_degrees: float = 60.0

## Time to live in turns: -1 means sustained spell, 0 means we do the effect once and then remove the spell
@export var ttl_turns: int = -1 


@export_group("Spell")
@export var spell_element := BattleEnums.EAffinityElement.FIRE
## The set modifier only applies if the affinity is a buff or debuff
@export var modifier: StatModifier

@export_group("Dice Roll Settings")
## The dice roll used to determine the item's power when used on a target. (This is not the attack roll!)
var _default_spell_power_rolls: Array[DiceRoll] = [DiceRoll.roll(8)]
@export var spell_power_rolls: Array[DiceRoll] = []:
    get:
        return spell_power_rolls if spell_power_rolls.size() > 0 \
        else _default_spell_power_rolls
    set(value):
        spell_power_rolls = value

## Override the spell's use roll (not the damage roll). Set to null to use a d20 vs the target's AC.
@export var use_roll: DiceRoll

var _roll_cache: Dictionary[BattleCharacter, DiceRoll] = {}
const DEFAULT_ROLL_DC: int = 10 # default DC for spell use rolls when the character is invalid

func get_spell_use_roll(caster: BattleCharacter, target: BattleCharacter) -> DiceRoll:
    if use_roll:
        return use_roll
    if spell_element == BattleEnums.EAffinityElement.ALMIGHTY:
        return DiceRoll.roll(20, 1, 0) # DC 0: always hits
    
    if not target:
        return DiceRoll.roll(20, 1, DEFAULT_ROLL_DC,
        ceil(caster.stats.get_stat(CharacterStatEntry.ECharacterStat.MagicalStrength)))

    return _roll_cache.get_or_add(target,
    DiceRoll.roll(20, 1, ceil(target.stats.get_stat(CharacterStatEntry.ECharacterStat.ArmourClass)),
    ceil(caster.stats.get_stat(CharacterStatEntry.ECharacterStat.MagicalStrength)))) # NEW: add magical strength to the roll

@export_group("Junction system")

## Dictionary with a character stat entry as key and a float as value
@export var junction_table: Dictionary[CharacterStatEntry.ECharacterStat, float] = {
    CharacterStatEntry.ECharacterStat.PhysicalStrength: 1,
    CharacterStatEntry.ECharacterStat.PhysicalDefense: 1,
} 

func get_item_description() -> String:
    var description_parts: Array[String] = []

    # Damage/healing effects
    if spell_element == BattleEnums.EAffinityElement.HEAL:
        description_parts.append("Restores %s HP" % [DiceRoll.get_dice_array_as_string(spell_power_rolls)])
    elif spell_element == BattleEnums.EAffinityElement.MANA:
        description_parts.append("Restores %s MP" % [DiceRoll.get_dice_array_as_string(spell_power_rolls)])
    elif spell_element not in [BattleEnums.EAffinityElement.BUFF, BattleEnums.EAffinityElement.DEBUFF]:
        description_parts.append("Deals %s %s damage" % [DiceRoll.get_dice_array_as_string(spell_power_rolls), Util.get_enum_name(BattleEnums.EAffinityElement, spell_element)])

    # Modifier effects
    if modifier:
        description_parts.append("applies " + modifier.name)

    var description_string := ""
    if description_parts.size() > 1:
        description_string = " and ".join(description_parts) + " "
    elif description_parts.size() == 1:
        description_string = description_parts[0] + " "

    # Target specification
    if can_use_on_enemies and can_use_on_allies:
        if item_type == ItemType.FIELD_SPELL and area_of_effect_radius > 0:
            description_string += "to all targets"
        else:
            description_string += "to any target"
    elif can_use_on_enemies:
        description_string += "to an enemy"
    elif can_use_on_allies:
        description_string += "to an ally"

    # Range specification
    if area_of_effect_radius > 0 and item_type == ItemType.FIELD_SPELL:
        description_string += " within %s units" % [str(int(area_of_effect_radius))]
    else:
        description_string += " at any range"

    # Modifier duration
    if modifier:
        if modifier.turn_duration == -1:
            description_string += ":\n%s indefinitely" % [modifier.description]
        else:
            description_string += ":\n%s for %s turns" % [modifier.description, str(modifier.turn_duration)]
    description_string += "."

    return description_string

func get_icon_path() -> String:
    var icon_path := "res://Assets/GUI/Icons/Items/elements/"
    icon_path += Util.get_enum_name(BattleEnums.EAffinityElement, spell_element).to_lower()
    return icon_path + "_element.png"

func get_use_sound(_status: UseStatus = UseStatus.SPELL_SUCCESS) -> AudioStream:
    if spell_element == BattleEnums.EAffinityElement.HEAL:
        return heal_sound
    return null


func use(user: BattleCharacter, target: BattleCharacter, update_inventory: bool = true) -> UseStatus:   
    print("[SPELL] %s used %s on %s" % [user.character_name, item_name, target.character_name])
    
    var spell_use_status := UseStatus.SPELL_FAIL
    var dice_status := DiceRoll.DiceStatus.ROLL_SUCCESS

    # Almighty damage never misses, but other attacks roll to hit
    if spell_element != BattleEnums.EAffinityElement.ALMIGHTY:
        
        var spell_use_roll := get_spell_use_roll(user, target).reroll()
        print("[SPELL] Rolling %s for %s total" % [spell_use_roll.to_string(), str(spell_use_roll.total())])
        dice_status = spell_use_roll.get_status()
        print("[SPELL] Roll status: %s" % [Util.get_enum_name(DiceRoll.DiceStatus, dice_status)])

        match dice_status:
            DiceRoll.DiceStatus.ROLL_SUCCESS:
                spell_use_status = UseStatus.SPELL_SUCCESS
            DiceRoll.DiceStatus.ROLL_CRIT_SUCCESS:
                spell_use_status = UseStatus.SPELL_CRIT_SUCCESS
            DiceRoll.DiceStatus.ROLL_FAIL:
                spell_use_status = UseStatus.SPELL_FAIL
            DiceRoll.DiceStatus.ROLL_CRIT_FAIL:
                spell_use_status = UseStatus.SPELL_CRIT_FAIL

    # we only apply buffs and debuffs if we are not immune to those.
    # some enemies can be immune to debuffs, and allies could potentially be given immunity to buffs by an enemy
    if target.get_affinity(spell_element) != BattleEnums.EAffinityType.IMMUNE:
        match spell_element:
            BattleEnums.EAffinityElement.HEAL:
                target.heal(DiceRoll.roll_all(spell_power_rolls), false, spell_use_status)
            BattleEnums.EAffinityElement.MANA:
                target.restore_mp(DiceRoll.roll_all(spell_power_rolls), spell_use_status)

            BattleEnums.EAffinityElement.BUFF,\
            BattleEnums.EAffinityElement.DEBUFF:
                if modifier and spell_use_status in [UseStatus.SPELL_SUCCESS, UseStatus.SPELL_CRIT_SUCCESS]:
                    target.stats.add_modifier(modifier)
                    print("[SPELL] %s applied %s to %s" % [user.character_name, modifier, target.character_name])
                else:
                    print("[SPELL] No modifier set for %s" % [Util.get_enum_name(BattleEnums.EAffinityElement, spell_element)])

        # other spell affinities deal damage
        # take_damage() doesn't take a spell result, because we use it for basic attacks too

    var attack_roll := DiceRoll.roll(20, 1, ceil(target.stats.get_stat(CharacterStatEntry.ECharacterStat.ArmourClass)))
    # TODO: attacks do damage based on a separate spawned node, like a projectile
    # TODO: calculate damage more randomly
    target.take_damage(user, spell_power_rolls, attack_roll, spell_element)

    if update_inventory:
        _update_inventory(spell_use_status)

    # reset cached roll so we can roll again
    _roll_cache.clear()

    return spell_use_status