extends Node
class_name BattleManager


static func process_basic_attack(attacker: BattleCharacter, target: BattleCharacter, damage_roll_sides: int = 20, num_damage_rolls: int = 1) -> void:
    print("Player attacks %s!" % target.character_name)
    var evasion : float = target.stats.get_stat(CharacterStatEntry.ECharacterStat.Evasion)
    print("[ATTACK] Evasion DC: " + str(evasion))
    var attack_roll := DiceRoller.roll_dc(20, ceil(evasion), 1)
    print("[ATTACK] Roll: " + str(attack_roll))

    var damage := DiceRoller.roll_flat(damage_roll_sides, num_damage_rolls)
    var result: BattleEnums.ESkillResult = target.take_damage(attacker, damage, attacker.basic_attack_element, attack_roll.status)
    print("[ATTACK] Result: " + Util.get_enum_name(BattleEnums.ESkillResult, result))