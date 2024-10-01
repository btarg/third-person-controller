extends Resource
class_name CharacterStatEntry

enum ECharacterStat { ## Character Stat
    MaxHP, ## Integer
    MaxSP, ## Integer
    Strength, ## Multiplier for physical damage when not resisted, absorbed, or immune (float 0-1)
    Defense, ## Used to reduce incoming damage of resisted affinities (float 0-1)
    Evasion, ## Integer DC for the attacker to hit this character
    Vitality, ## Integer bonus for initiative rolls
    AttackCritMultiplier, ## Multiplier for damage on crit (float 0-1)
    DrawBonus, ## Integer number of d4 rolls to add as a bonus to amount of spells drawn
    Movement, ## Integer number of metres the character can move per turn
    AttackRange, ## Integer number of metres the character can attack from (basic attack)
    DrawRange, ## Integer number of metres the character can draw from
    # Attacks don't have a fail multiplier as failures result in resisted, absorbed, or immune damage    
    MagicCritMultiplier, ## Multiplier for magic damage on crit (float 0-1)
    MagicFailMultiplier, ## Multiplier for magic damage on fail (float 0-1)
    MagicCritFailMultiplier, ## Multiplier for magic damage on crit fail (float 0-1)

    NONE ## Placeholder for no stat
}
@export var stat_key: ECharacterStat = ECharacterStat.MaxHP
@export var stat_value: float = 0.0