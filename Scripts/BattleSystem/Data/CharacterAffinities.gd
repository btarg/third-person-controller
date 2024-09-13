class_name CharacterAffinities

## TODO: this is temporary, character affinities will be replaced with a typed dictionary on the
## character themselves when Godot 4.4 is out, so we can edit in the editor
static var affinities_test_enemy: Dictionary = {
    BattleEnums.EAffinityElement.FIRE: BattleEnums.EAffinityType.REFLECT,
    BattleEnums.EAffinityElement.ICE: BattleEnums.EAffinityType.WEAK,
    BattleEnums.EAffinityElement.ELEC: BattleEnums.EAffinityType.RESIST,
    BattleEnums.EAffinityElement.WIND: BattleEnums.EAffinityType.WEAK,
    BattleEnums.EAffinityElement.LIGHT: BattleEnums.EAffinityType.REFLECT,
    BattleEnums.EAffinityElement.DARK: BattleEnums.EAffinityType.IMMUNE,
}