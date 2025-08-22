## This class is used along with ActionData for enemy AI decision-making.
class_name AIDecisionContext extends RefCounted

var health_ratio: float
var mana_ratio: float
var player_health_ratio: float
var distance_to_target: float
var in_attack_range: bool
var in_spell_range: bool
var aggression: float
# Ally health assessment variables
var injured_ally_count: int
var critically_injured_ally_count: int
var most_injured_ally: BattleCharacter
var lowest_ally_health_ratio: float
# New AOE support variables
var has_aoe_targets: bool
var aoe_target_count: int
# Dead ally support variables
var has_dead_allies: bool
var closest_dead_ally: BattleCharacter
var dead_ally_count: int

func _init(p_health_ratio: float, p_mana_ratio: float, p_player_health_ratio: float, 
            p_distance: float, p_in_attack_range: bool, p_in_spell_range: bool, p_aggression: float,
            p_injured_ally_count: int = 0, p_critically_injured_ally_count: int = 0, p_most_injured_ally: BattleCharacter = null, p_lowest_ally_health_ratio: float = 1.0,
            p_has_aoe_targets: bool = false, p_aoe_target_count: int = 0, 
            p_has_dead_allies: bool = false, p_closest_dead_ally: BattleCharacter = null, p_dead_ally_count: int = 0):
    health_ratio = p_health_ratio
    mana_ratio = p_mana_ratio
    player_health_ratio = p_player_health_ratio
    distance_to_target = p_distance
    in_attack_range = p_in_attack_range
    in_spell_range = p_in_spell_range
    aggression = p_aggression
    injured_ally_count = p_injured_ally_count
    critically_injured_ally_count = p_critically_injured_ally_count
    most_injured_ally = p_most_injured_ally
    lowest_ally_health_ratio = p_lowest_ally_health_ratio
    has_aoe_targets = p_has_aoe_targets
    aoe_target_count = p_aoe_target_count
    has_dead_allies = p_has_dead_allies
    closest_dead_ally = p_closest_dead_ally
    dead_ally_count = p_dead_ally_count
