extends Resource
class_name CharacterStatEntry

enum ECharacterStat { ## Character Stat
    MaxHP, ## Integer
    MaxSP, ## Integer
    Strength, ## Multiplier for physical damage when not resisted, absorbed, or immune (float 0-1)
    Defense, ## Used to reduce incoming damage of resisted affinities (float 0-1)
    Evasion, ## Integer DC for the attacker to hit this character
    Vitality, ## Integer bonus for initiative rolls
    CritMultiplier, ## Multiplier for damage on crit (float 0-1)
}
@export var stat_key: ECharacterStat = ECharacterStat.MaxHP
@export var stat_value: float = 0.0