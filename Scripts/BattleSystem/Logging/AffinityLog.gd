extends Node

class AffinityLogEntry:
    var affinity_dict: Dictionary[BattleEnums.EAffinityElement, BattleEnums.EAffinityType] = {}


var _logged_affinities: Dictionary[String, AffinityLogEntry] = {
        # "TestEnemy": {
        #     BattleEnums.EAffinityElement.FIRE : BattleEnums.EAffinityType.RESIST,
        #     BattleEnums.EAffinityElement.ICE : BattleEnums.EAffinityType.WEAK
        # }
    }

func _ready() -> void:
    # TODO: load log from file
    Console.add_command("affinity_log", _print_log)

func is_affinity_logged(internal_name: String, element: BattleEnums.EAffinityElement) -> bool:
    return internal_name in _logged_affinities and element in _logged_affinities[internal_name].affinity_dict

func _print_log() -> void:
    for character_internal_name: String in _logged_affinities.keys():
        Console.print_line("[AL] %s affinities:" % character_internal_name)
        for element: BattleEnums.EAffinityElement in _logged_affinities[character_internal_name].affinity_dict.keys():
            Console.print_line("  %s: %s" % [Util.get_enum_name(BattleEnums.EAffinityElement, element), Util.get_enum_name(BattleEnums.EAffinityType, _logged_affinities[character_internal_name].affinity_dict[element])])

## Once the player has used a spell of a certain element against an enemy,
## _logged_affinities the affinity of that enemy to that element so they can use previous experience to their advantage
func log_affinity(character_internal_name: String, element: BattleEnums.EAffinityElement, affinity: BattleEnums.EAffinityType) -> void:
    var new_aff: AffinityLogEntry = AffinityLogEntry.new()
    new_aff.affinity_dict.get_or_add(element, affinity)
    _logged_affinities.get_or_add(character_internal_name, new_aff)
    print("[AL] %s affinity to %s logged as %s" % [character_internal_name, Util.get_enum_name(BattleEnums.EAffinityElement, element), Util.get_enum_name(BattleEnums.EAffinityType, affinity)])

## Gets an already known affinity of a character to an element
## "How much casting can we possibly do in one function?"
## 4.4 update: we no longer do silly amounts of casting here!
func get_affinity(character_internal_name: String, element: BattleEnums.EAffinityElement) -> BattleEnums.EAffinityType:
    if character_internal_name as String in _logged_affinities:
        if element as BattleEnums.EAffinityElement in _logged_affinities[character_internal_name].affinity_dict:
            return _logged_affinities[character_internal_name].affinity_dict[element] as BattleEnums.EAffinityType
    return BattleEnums.EAffinityType.NEUTRAL