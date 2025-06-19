## This class is used along with ActionData for enemy AI decision-making.
class_name AIDecisionContext extends RefCounted

var health_ratio: float
var mana_ratio: float
var player_health_ratio: float
var distance_to_target: float
var in_attack_range: bool
var in_spell_range: bool
var aggression: float
var ally_needs_healing: bool
var most_injured_ally: BattleCharacter
var ally_health_ratio: float

func _init(p_health_ratio: float, p_mana_ratio: float, p_player_health_ratio: float, 
            p_distance: float, p_in_attack_range: bool, p_in_spell_range: bool, p_aggression: float,
            p_ally_needs_healing: bool = false, p_most_injured_ally: BattleCharacter = null, p_ally_health_ratio: float = 1.0):
    health_ratio = p_health_ratio
    mana_ratio = p_mana_ratio
    player_health_ratio = p_player_health_ratio
    distance_to_target = p_distance
    in_attack_range = p_in_attack_range
    in_spell_range = p_in_spell_range
    aggression = p_aggression
    ally_needs_healing = p_ally_needs_healing
    most_injured_ally = p_most_injured_ally
    ally_health_ratio = p_ally_health_ratio