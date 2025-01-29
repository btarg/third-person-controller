extends Node
class_name BattleManager


static func process_basic_attack(attacker: BattleCharacter, target: BattleCharacter) -> BattleEnums.ESkillResult:
    var attacker_position := attacker.get_parent().global_position as Vector3
    var target_position := target.get_parent().global_position as Vector3

    var distance := attacker_position.distance_to(target_position)
    var attack_range := attacker.stats.get_stat(CharacterStatEntry.ECharacterStat.AttackRange)
    if distance > attack_range:
        print("[ATTACK] Target out of range! (Distance: " + str(distance) + ", Range: " + str(range) + ")")
        return BattleEnums.ESkillResult.SR_OUT_OF_RANGE


    print("%s attacks %s with %s!" % [attacker.character_name, target.character_name, Util.get_enum_name(BattleEnums.EAffinityElement, attacker.basic_attack_element)])
    var AC : float = target.stats.get_stat(CharacterStatEntry.ECharacterStat.ArmourClass)
    print("[ATTACK] Armour class: " + str(AC))
    
    var attack_roll := DiceRoll.create(20, 1, ceil(AC)).roll_dc()
    print("[ATTACK] Attack Roll: " + str(attack_roll))

    var damage := DiceRoll.create(20, 1)
    print("[ATTACK] Damage Roll: " + str(damage))

    # TODO: attacks do damage based on an animation, not instantly
    var result := target.take_damage(attacker, [damage], attacker.basic_attack_element, attack_roll.status)
    print("[ATTACK] Result: " + Util.get_enum_name(BattleEnums.ESkillResult, result))

    return result