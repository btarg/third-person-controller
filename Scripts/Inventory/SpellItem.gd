class_name SpellItem extends BaseInventoryItem

@export_group("Spell")
@export var spell_affinity := BattleEnums.EAffinityElement.FIRE
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

## Override the spell's attack roll. Set to null to use a d20 vs the target's AC.
@export var use_roll: DiceRoll

var _roll_cache: Dictionary = {}
func get_spell_use_roll(target: BattleCharacter) -> DiceRoll:
    if use_roll:
        return use_roll
    if spell_affinity == BattleEnums.EAffinityElement.ALMIGHTY:
        return DiceRoll.roll(20, 1, 0) # DC 0: always hits

    return _roll_cache.get_or_add(target,
    DiceRoll.roll(20, 1, ceil(target.stats.get_stat(CharacterStatEntry.ECharacterStat.ArmourClass))))


## The radius around the caster which targets need to be in to be affected by the spell.
@export var spell_radius := 0

@export_group("Junction system")

## Dictionary with a character stat entry as key and a float as value
## TODO: Typed Dictionary
@export var junction_table = {
    CharacterStatEntry.ECharacterStat.MaxHP: 2.0,
    CharacterStatEntry.ECharacterStat.Strength: 1.005,
} 

func get_item_description() -> String:
    var description_string := ""

    if spell_affinity == BattleEnums.EAffinityElement.HEAL:
        description_string += "Restores %s HP " % [DiceRoll.get_dice_array_as_string(spell_power_rolls)]
    elif spell_affinity == BattleEnums.EAffinityElement.MANA:
        description_string += "Restores %s MP " % [DiceRoll.get_dice_array_as_string(spell_power_rolls)]
    elif spell_affinity in [BattleEnums.EAffinityElement.BUFF,
    BattleEnums.EAffinityElement.DEBUFF]:
        description_string += "Applies " + modifier.name
    else:
        description_string += "Deals %s %s damage " % [DiceRoll.get_dice_array_as_string(spell_power_rolls), Util.get_enum_name(BattleEnums.EAffinityElement, spell_affinity)]

    if can_use_on_enemies and can_use_on_allies:
        description_string += "to any target."
    elif can_use_on_enemies:
        description_string += "to an enemy."
    elif can_use_on_allies:
        description_string += "to an ally."

    return description_string

func get_icon_path() -> String:
    var icon_path := "res://Assets/GUI/Icons/Items/elements/"
    icon_path += Util.get_enum_name(BattleEnums.EAffinityElement, spell_affinity).to_lower()
    return icon_path + "_element.png"

func get_use_sound(_status: UseStatus = UseStatus.SPELL_SUCCESS) -> AudioStream:
    if spell_affinity == BattleEnums.EAffinityElement.HEAL:
        return heal_sound
    return null


func use(user: BattleCharacter, target: BattleCharacter) -> UseStatus:
    print("[SPELL] %s used %s on %s" % [user.character_name, item_name, target.character_name])
    
    var spell_use_status := UseStatus.SPELL_FAIL
    var dice_status := DiceRoll.DiceStatus.ROLL_SUCCESS

    # Almighty damage never misses, but other attacks roll to hit
    if spell_affinity != BattleEnums.EAffinityElement.ALMIGHTY:
        
        var spell_use_roll := get_spell_use_roll(target).reroll()
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

    match spell_affinity:
        BattleEnums.EAffinityElement.HEAL:
            # spell use status is already set to success or fail
            var heal_amount := DiceRoll.roll_all(spell_power_rolls)
            target.heal(heal_amount, false, spell_use_status)
        BattleEnums.EAffinityElement.MANA:
            pass
            # TODO: Mana restoration
            print("Mana restoration not implemented yet!")

        BattleEnums.EAffinityElement.BUFF,\
        BattleEnums.EAffinityElement.DEBUFF:
            if modifier and spell_use_status in [UseStatus.SPELL_SUCCESS, UseStatus.SPELL_CRIT_SUCCESS]:
                target.stats.add_modifier(modifier)
                print("[SPELL] %s applied %s to %s" % [user.character_name, modifier, target.character_name])
            else:
                print("[SPELL] No modifier set for %s" % [Util.get_enum_name(BattleEnums.EAffinityElement, spell_affinity)])

        # other spell affinities deal damage
        # take_damage() doesn't take a spell result, because we use it for basic attacks too
        _:
            var attack_roll := DiceRoll.roll(20, 1, ceil(target.stats.get_stat(CharacterStatEntry.ECharacterStat.ArmourClass)))
            # TODO: attacks do damage based on an animation, not instantly
            # TODO: calculate damage more randomly
            target.take_damage(user, spell_power_rolls, attack_roll, spell_affinity)

    item_used.emit(item_id, spell_use_status)

    # reset cached roll so we can roll again
    _roll_cache.clear()

    return spell_use_status