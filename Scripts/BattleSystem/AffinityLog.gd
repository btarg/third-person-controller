extends Node
# Key = character internal name, Value = Dictionary of EAffinityElement : EAffinityType
# TODO: typed dictionary when Godot 4.4 is out
var log: Dictionary = {
        # "TestEnemy": {
        #     BattleEnums.EAffinityElement.FIRE : BattleEnums.EAffinityType.RESIST,
        #     BattleEnums.EAffinityElement.ICE : BattleEnums.EAffinityType.WEAK
        # }
    }

func _ready() -> void:
#     var element := BattleEnums.EAffinityElement.ICE
#     var affinity := get_affinity("TestEnemy", element)
#     var element_name := Util.get_enum_name(BattleEnums.EAffinityElement, element)
#     print("[AL] TestEnemy %s affinity: %s" % [element_name, Util.get_enum_name(BattleEnums.EAffinityType, affinity)])
    Console.add_command("affinity_log", _print_log)

func is_affinity_logged(internal_name: String, element: BattleEnums.EAffinityElement) -> bool:
    return internal_name in log and element in log[internal_name]

func _print_log() -> void:
    for character_internal_name: String in log.keys():
        Console.print_line("[AL] %s affinities:" % character_internal_name)
        for element: BattleEnums.EAffinityElement in log[character_internal_name].keys():
            Console.print_line("  %s: %s" % [Util.get_enum_name(BattleEnums.EAffinityElement, element), Util.get_enum_name(BattleEnums.EAffinityType, log[character_internal_name][element])])

## Once the player has used a spell of a certain element against an enemy,
## log the affinity of that enemy to that element so they can use previous experience to their advantage
func log_affinity(character_internal_name: String, element: BattleEnums.EAffinityElement, affinity: BattleEnums.EAffinityType) -> void:
    log.get_or_add(character_internal_name, {
        element : affinity
    })
    print("[AL] %s affinity to %s logged as %s" % [character_internal_name, Util.get_enum_name(BattleEnums.EAffinityElement, element), Util.get_enum_name(BattleEnums.EAffinityType, affinity)])

## Gets an already known affinity of a character to an element
## "How much casting can we possibly do in one function?"
func get_affinity(character_internal_name: String, element: BattleEnums.EAffinityElement) -> BattleEnums.EAffinityType:
    if character_internal_name as String in log:
        if element as BattleEnums.EAffinityElement in log[character_internal_name] as Dictionary:
            return log[character_internal_name][element] as BattleEnums.EAffinityType
    return BattleEnums.EAffinityType.UNKNOWN