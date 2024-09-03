@tool
extends Resource
class_name CharacterStatEntry

enum ECharacterStat {
    MaxHP,
    MaxSP,
    Strength,
    Defense,
    Evasion,
    Vitality
}
@export var stat_key: ECharacterStat = ECharacterStat.MaxHP
@export var stat_value: float = 100.0

func create(stat: ECharacterStat, value: float) -> CharacterStatEntry:
    stat_key = stat
    stat_value = value
    return self