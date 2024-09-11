class_name SpellItem extends BaseInventoryItem

@export var spell_affinity := BattleEnums.EAffinityElement.FIRE
## The base effectiveness of the spell.
## For healing spells, this means how much HP is healed on a regular success without modifiers.
## For damage spells, this means how much damage is dealt on a regular success without modifiers.
@export var spell_power: int = 10
@export var spell_radius := 0

@export_group("Dice Roll Settings")
@export_range(4, 100) var die_sides: int = 20
@export_range(1, 10) var num_rolls: int = 1
@export_range(1, 100) var difficulty_class: int = 10
@export var crit_behaviour: DiceRoller.CritBehaviour = DiceRoller.CritBehaviour.CRIT_ON_ANY_NAT

@export var power_multiplier_success: float = 1.0
@export var power_multiplier_crit_success: float = 2.0
@export var power_multiplier_fail: float = 0.5
@export var power_multiplier_crit_fail: float = 0.0


func get_icon_path() -> String:
    var icon_path := "res://Assets/Icons/elements/"
    icon_path += Util.get_enum_name(BattleEnums.EAffinityElement, spell_affinity).to_lower()
    return icon_path + "_element.png"

func get_use_sound(status: UseStatus = UseStatus.SPELL_SUCCESS) -> AudioStream:
    if spell_affinity == BattleEnums.EAffinityElement.HEAL:
        return heal_sound
    return null


func use(user: BattleCharacter, target: BattleCharacter) -> UseStatus:
    var spell_use_status := UseStatus.SPELL_FAIL
    var dice_status := DiceRoller.DiceStatus.ROLL_SUCCESS

    # don't calculate rolls if almighty
    if spell_affinity != BattleEnums.EAffinityElement.ALMIGHTY:
        var result := DiceRoller.roll_dc(die_sides, difficulty_class, num_rolls, crit_behaviour)
        print("[SPELL] Roll result for %s: %s" % [item_name, result])
        dice_status = result.status as DiceRoller.DiceStatus        

        # TODO: spell use in battle
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
            _handle_healing(spell_power)
            spell_use_status = UseStatus.SPELL_SUCCESS
        BattleEnums.EAffinityElement.MANA:
            print("[SPELL] %s restored %s MP to %s" % [item_name, spell_power, target.character_name])
            # TODO: Mana restoration
            spell_use_status = UseStatus.SPELL_SUCCESS

        # other spell affinities deal damage
        _:
            print("[SPELL] %s 's %s did %s damage to %s" % [user.character_name, item_name, spell_power, target.character_name])
            target.take_damage(user, spell_power, spell_affinity, dice_status)
            spell_use_status = UseStatus.SPELL_SUCCESS

    item_used.emit(spell_use_status)
    return spell_use_status

func _handle_healing(heal_power: float) -> void:
    print(item_name + " Spell Healed " + str(heal_power) + " HP!")