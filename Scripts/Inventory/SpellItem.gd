class_name SpellItem extends BaseInventoryItem

@export_group("Spell")
@export var spell_affinity := BattleEnums.EAffinityElement.FIRE
## The set modifier only applies if the affinity is a buff or debuff
@export var modifier: StatModifier


@export_group("Dice Roll Settings")
## The dice roll used to determine the item's power when used on a target. (This is not the attack roll!)
@export var use_roll: DiceRoll = DiceRoll.create(8, 1)
@export_group("Spell power settings")
## The base effectiveness of the spell.
## For healing spells, this means how much HP is healed on a regular success without modifiers.
## For damage spells, this means how much damage is dealt on a regular success without modifiers.
@export var base_spell_power: int = 1
var spell_power := base_spell_power
## The radius around the caster which targets need to be in to be affected by the spell.
@export var spell_radius := 0
@export var power_multiplier_success: float = 1.0
@export var power_multiplier_crit_success: float = 2.0
@export var power_multiplier_fail: float = 0.5
@export var power_multiplier_crit_fail: float = 0.0

@export_group("Junction system")

## Dictionary with a character stat entry as key and a float as value
## TODO: Typed Dictionary
@export var junction_table = {
    CharacterStatEntry.ECharacterStat.MaxHP: 2.0,
    CharacterStatEntry.ECharacterStat.Strength: 1.005,
} 

func get_icon_path() -> String:
    var icon_path := "res://Assets/GUI/Icons/Items/elements/"
    icon_path += Util.get_enum_name(BattleEnums.EAffinityElement, spell_affinity).to_lower()
    return icon_path + "_element.png"

func get_use_sound(_status: UseStatus = UseStatus.SPELL_SUCCESS) -> AudioStream:
    if spell_affinity == BattleEnums.EAffinityElement.HEAL:
        return heal_sound
    return null


func use(user: BattleCharacter, target: BattleCharacter) -> UseStatus:
    var spell_use_status := UseStatus.SPELL_FAIL
    var dice_status := DiceRoller.DiceStatus.ROLL_SUCCESS

    # don't calculate rolls if almighty
    if spell_affinity != BattleEnums.EAffinityElement.ALMIGHTY:
        var result := use_roll.roll_dc()
        print("[SPELL] Roll result for %s (DC %s): %s" % [item_name, use_roll.difficulty_class, result])
        dice_status = result.status as DiceRoller.DiceStatus

        print("[SPELL] %s used %s on %s" % [user.character_name, item_name, target.character_name])

        match dice_status:
            DiceRoller.DiceStatus.ROLL_CRIT_SUCCESS:
                print("[SPELL] %s CRIT succeeded!" % item_name)
                spell_power = ceili(spell_power * power_multiplier_crit_success)
                spell_use_status = UseStatus.SPELL_CRIT_SUCCESS
            DiceRoller.DiceStatus.ROLL_SUCCESS:
                print("[SPELL] %s Spell Succeeded!" % item_name)
                spell_power = ceili(spell_power * power_multiplier_success)
                spell_use_status = UseStatus.SPELL_SUCCESS
            DiceRoller.DiceStatus.ROLL_CRIT_FAIL:
                print("[SPELL] %s Spell CRIT Failed!" % item_name)
                spell_power = ceili(spell_power * power_multiplier_crit_fail)
                spell_use_status = UseStatus.SPELL_CRIT_FAIL
            DiceRoller.DiceStatus.ROLL_FAIL:
                print("[SPELL] %s Spell Failed!" % item_name)
                spell_power = ceili(spell_power * power_multiplier_fail)
                spell_use_status = UseStatus.SPELL_FAIL
            _:
                pass

    match spell_affinity:
        BattleEnums.EAffinityElement.HEAL:
            # spell use status is already set to success or fail
            var heal_amount := use_roll.roll_flat()
            target.heal(heal_amount, false, spell_use_status)
        BattleEnums.EAffinityElement.MANA:
            print("[SPELL] %s restored %s MP to %s" % [item_name, spell_power, target.character_name])
            # TODO: Mana restoration

        BattleEnums.EAffinityElement.BUFF,\
        BattleEnums.EAffinityElement.DEBUFF:
            
            if modifier and spell_use_status in [UseStatus.SPELL_SUCCESS, UseStatus.SPELL_CRIT_SUCCESS]:
                print("[MODIFIER] %s applied %s to %s" % [item_name, spell_power, target.character_name])
                target.stats.add_modifier(modifier)
            else:
                print("[MODIFIER] %s failed to apply %s to %s" % [item_name, spell_power, target.character_name])

        # other spell affinities deal damage
        # take_damage() doesn't take a spell result, because we use it for basic attacks too
        _:
            # TODO: attacks do damage based on an animation, not instantly
            # TODO: calculate damage more randomly
            target.take_damage(user, use_roll, spell_affinity, dice_status)

    item_used.emit(item_id, spell_use_status)

    # FIX: don't keep stacking crits!
    spell_power = base_spell_power

    return spell_use_status