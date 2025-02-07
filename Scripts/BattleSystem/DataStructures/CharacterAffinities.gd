class_name CharacterAffinities

## TODO: this is temporary, character affinities will be replaced with a typed dictionary on the
## character themselves when Godot 4.4 is out, so we can edit in the editor
# Enemy is FIRE type
static var affinities_test_enemy: Dictionary = {
    BattleEnums.EAffinityElement.FIRE: BattleEnums.EAffinityType.ABSORB,
    BattleEnums.EAffinityElement.ICE: BattleEnums.EAffinityType.WEAK,
    BattleEnums.EAffinityElement.ELEC: BattleEnums.EAffinityType.RESIST,
}
# Player is ICE type
static var affinities_test_player: Dictionary = {
    BattleEnums.EAffinityElement.FIRE: BattleEnums.EAffinityType.WEAK,
    BattleEnums.EAffinityElement.ICE: BattleEnums.EAffinityType.IMMUNE,
    BattleEnums.EAffinityElement.ELEC: BattleEnums.EAffinityType.WEAK,
    BattleEnums.EAffinityElement.WIND: BattleEnums.EAffinityType.RESIST,
    
}