@tool
extends Resource
class_name CharacterStatEntry

enum ECharacterStat { ## Character Stat
    MaxHP, ## Integer
    MaxSP, ## Integer
    Strength, ## Strength is used to increase physical damage when not resisted, absorbed, or immune (float 1-0)
    Defense, ## Defense is used to reduce incoming damage of resisted affinities (float 0-1)
    Evasion, ## Evasion is the DC for the attacker to hit this character (rounded to int)
    Vitality, ## Vitality is used as a bonus for initiative rolls (int)
    CritMultiplier, ## CritMultiplier is used to increase crit damage (float 1-0)
}
@export var stat_key: ECharacterStat = ECharacterStat.MaxHP
@export var stat_value: float = 100.0