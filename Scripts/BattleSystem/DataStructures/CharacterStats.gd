extends Node
class_name CharacterStats


@export var stats: Array[CharacterStatEntry] = []
@export var stat_modifiers: Array[StatModifier] = []
# Dictionary of stat modifiers with turns left as integer
var stat_modifiers_turns_left: Dictionary = {}

func add_stat_entry(entry: CharacterStatEntry) -> void:
    stats.append(entry)

func add_modifier(modifier: StatModifier) -> void:
    print(">>> ADDING MODIFIER: " + modifier.name)
    stat_modifiers.append(modifier)
    stat_modifiers_turns_left[modifier] = modifier.turn_duration

func remove_modifier(modifier: StatModifier) -> void:
    stat_modifiers.erase(modifier)
    stat_modifiers_turns_left.erase(modifier)

func update_modifiers() -> void:
    for i in range(stat_modifiers.size()):
        var modifier: StatModifier = stat_modifiers[i]
        if stat_modifiers_turns_left[modifier] == 0:
            stat_modifiers_turns_left[modifier] -= 1
            print(">>> TURNS LEFT FOR " + modifier.name + ": " + str(stat_modifiers_turns_left[modifier]))
        elif stat_modifiers_turns_left[modifier] != -1: # -1 means infinite duration
            print(">>> REMOVING MODIFIER: " + modifier.name)
            stat_modifiers.remove_at(i)
            stat_modifiers_turns_left.erase(modifier)

func get_stat(stat: CharacterStatEntry.ECharacterStat, with_modifiers: bool = true) -> float:
    # return stat with multipliers applied and stack multipliers if they have the stack flag
    var stat_value: float = -1.0
    for entry in stats:
        if entry.stat_key == stat:
            stat_value = entry.stat_value
            break
    var stat_value_with_modifiers: float = stat_value
    print(">>> STAT VALUE: " + str(stat_value))
    var stat_modifiers_copy := stat_modifiers

    # sort stat modifiers by turns left
    stat_modifiers_copy.sort_custom(
        func(a: StatModifier, b: StatModifier) -> bool:
            return true if a.turns_left < b.turns_left else false)

    if stat_value != -1.0:
        for modifier in stat_modifiers_copy:
            if stat == modifier.stat:
                if modifier.can_stack:
                    stat_value_with_modifiers *= modifier.stat_value
                elif modifier.stack_override:
                    stat_value_with_modifiers = stat_value * modifier.stat_value
                    break # do not apply any other modifiers
                else:
                    # non stackable modifiers that do not override will be removed
                    stat_modifiers.erase(modifier)
    
    return stat_value_with_modifiers if with_modifiers else stat_value


# update modifiers when key 7 is pressed
func _input(event) -> void:
    if event is InputEventKey and event.is_pressed() and not event.is_echo() and event.keycode == KEY_7:
        update_modifiers()
        print(">>> MAX HP: " + str(get_stat(CharacterStatEntry.ECharacterStat.MaxHP)))
