extends Node
class_name CharacterStats


@export var stats: Array[CharacterStatEntry] = []
@export var stat_modifiers: Array[StatModifier] = []

signal OnStatChanged(stat: CharacterStatEntry.ECharacterStat, new_value: float)

func add_stat_entry(entry: CharacterStatEntry) -> void:
    stats.append(entry)

## If a modifier with this ID already exists, replace it.
## Otherwise, add the new modifier.
func add_or_update_modifier(modifier: StatModifier) -> void:
    for i in range(stat_modifiers.size()):
        var mod := stat_modifiers[i] as StatModifier
        if mod.modifier_id == modifier.modifier_id:
            print("[Modifier] UPDATING MODIFIER: " + modifier.name)
            print("OLD VALUE: " + str(mod.stat_value) + " NEW VALUE: " + str(modifier.stat_value))
            stat_modifiers[i] = modifier
            return
    add_modifier(modifier)

func add_modifier(modifier: StatModifier) -> void:
    var modifier_string := "[Modifier] ADDING MODIFIER: " + modifier.name + " WITH VALUE: " + str(modifier.stat_value)

    if modifier.is_multiplier:
        modifier_string += " (Multiplier)"
    else:
        modifier_string += " (Additive)"

    print(modifier_string)
    stat_modifiers.append(modifier)
    modifier.turns_left = modifier.turn_duration

## Remove by the modifier ID (e.g. test_strength_modifier)
func remove_modifier_by_id(id: String) -> void:
    for i in range(stat_modifiers.size()):
        if stat_modifiers[i].modifier_id == id:
            stat_modifiers.remove_at(i)
            break
## Remove by the UUID (unique_id)
func remove_modifier_by_unqiue_id(unique: String) -> void:
    for i in range(stat_modifiers.size()):
        if stat_modifiers[i].unique_id == unique:
            stat_modifiers.remove_at(i)
            break


func remove_modifier(modifier: StatModifier) -> void:
    stat_modifiers.erase(modifier)

func update_modifier_by_unique_id(unique: String, new_value: float) -> void:
    for modifier: StatModifier in stat_modifiers:
        if modifier.unique_id == unique:
            modifier.stat_value = new_value
            print("[Modifier] CHANGED MODIFIER " + modifier.name + " TO " + str(new_value))
            break

func update_modifiers() -> void:
    for i in range(stat_modifiers.size()):
        var modifier := stat_modifiers[i] as StatModifier
        if modifier.turns_left >= 0:
            modifier.turns_left -= 1
            print("[Modifier] TURNS LEFT FOR " + modifier.name + ": " + str(modifier.turns_left))
        elif modifier.turns_left != -1: # -1 means infinite duration
            print("[Modifier] REMOVING MODIFIER: " + modifier.name)
            stat_modifiers.remove_at(i)
        else:
            print("[Modifier] MODIFIER " + modifier.name + " HAS INFINITE DURATION")

func get_stat(stat: CharacterStatEntry.ECharacterStat, with_modifiers: bool = true) -> float:
    # return stat with multipliers applied and stack multipliers if they have the stack flag
    var stat_value: float = -1.0
    for entry: CharacterStatEntry in stats:
        if entry.stat_key == stat:
            stat_value = entry.stat_value
            break
    var stat_value_with_modifiers := stat_value
    var stat_modifiers_copy := stat_modifiers.duplicate()

    # sort stat modifiers by turns left
    stat_modifiers_copy.sort_custom(
        func(a: StatModifier, b: StatModifier) -> bool:
            return true if a.turns_left < b.turns_left else false)

    if stat_value != -1.0:
        for modifier: StatModifier in stat_modifiers_copy:
            if not modifier.modifier_active:
                print("[Modifier] MODIFIER " + modifier.name + " IS INACTIVE")
                continue

            if stat == modifier.stat:
                if modifier.can_stack:

                    if modifier.is_multiplier:
                        stat_value_with_modifiers *= modifier.stat_value
                    else:
                        stat_value_with_modifiers += modifier.stat_value

                elif modifier.stack_override:
                    
                    if modifier.is_multiplier:
                        stat_value_with_modifiers = stat_value * modifier.stat_value
                    else:
                        stat_value_with_modifiers = stat_value + modifier.stat_value

                    break # do not apply any other modifiers
                else:
                    # non stackable modifiers that do not override will be removed
                    stat_modifiers.erase(modifier)
    
    return stat_value_with_modifiers if with_modifiers else stat_value

## Change a base stat value (not considering modifiers)
func set_stat(stat: CharacterStatEntry.ECharacterStat, new_value: int) -> void:
    for i in range(stats.size()):
        if stats[i].stat_key == stat:
            stats[i].stat_value = new_value
            OnStatChanged.emit(stat, new_value)
            break
