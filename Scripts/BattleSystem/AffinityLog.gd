extends Node
# Key = character internal name, Value = Dictionary of EAffinityElement : EAffinityType
# TODO: typed dictionary when Godot 4.4 is out
var _logged_affinities: Dictionary = {
        # "TestEnemy": {
        #     BattleEnums.EAffinityElement.FIRE : BattleEnums.EAffinityType.RESIST,
        #     BattleEnums.EAffinityElement.ICE : BattleEnums.EAffinityType.WEAK
        # }
    }

func _ready() -> void:
    # TODO: load log from file
    Console.add_command("affinity_log", _print_log)

func is_affinity_logged(internal_name: String, element: BattleEnums.EAffinityElement) -> bool:
    return internal_name in _logged_affinities and element in _logged_affinities[internal_name]

func _print_log() -> void:
    for character_internal_name: String in _logged_affinities.keys():
        Console.print_line("[AL] %s affinities:" % character_internal_name)
        for element: BattleEnums.EAffinityElement in _logged_affinities[character_internal_name].keys():
            Console.print_line("  %s: %s" % [Util.get_enum_name(BattleEnums.EAffinityElement, element), Util.get_enum_name(BattleEnums.EAffinityType, _logged_affinities[character_internal_name][element])])

## Once the player has used a spell of a certain element against an enemy,
## _logged_affinities the affinity of that enemy to that element so they can use previous experience to their advantage
func log_affinity(character_internal_name: String, element: BattleEnums.EAffinityElement, affinity: BattleEnums.EAffinityType) -> void:
    _logged_affinities.get_or_add(character_internal_name, {
        element : affinity
    })
    print("[AL] %s affinity to %s logged as %s" % [character_internal_name, Util.get_enum_name(BattleEnums.EAffinityElement, element), Util.get_enum_name(BattleEnums.EAffinityType, affinity)])

## Gets an already known affinity of a character to an element
## "How much casting can we possibly do in one function?"
func get_affinity(character_internal_name: String, element: BattleEnums.EAffinityElement) -> BattleEnums.EAffinityType:
    if character_internal_name as String in _logged_affinities:
        if element as BattleEnums.EAffinityElement in _logged_affinities[character_internal_name] as Dictionary:
            return _logged_affinities[character_internal_name][element] as BattleEnums.EAffinityType
    return BattleEnums.EAffinityType.UNKNOWN