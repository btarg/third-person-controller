extends Node
class_name CharacterStats


@export var stats: Array[CharacterStatEntry] = []
@export var stat_modifiers: Array[StatModifier] = []

signal OnStatChanged(stat: CharacterStatEntry.ECharacterStat, new_value: float)

func add_stat_entry(entry: CharacterStatEntry) -> void:
    stats.append(entry)

func add_modifier(modifier: StatModifier) -> void:
    print(">>> ADDING MODIFIER: " + modifier.name)
    stat_modifiers.append(modifier)
    modifier.turns_left = modifier.turn_duration


func remove_modifier(modifier: StatModifier) -> void:
    stat_modifiers.erase(modifier)

func update_modifiers() -> void:
    for i in range(stat_modifiers.size()):
        var modifier := stat_modifiers[i] as StatModifier
        if modifier.turns_left >= 0:
            modifier.turns_left -= 1
            print(">>> TURNS LEFT FOR " + modifier.name + ": " + str(modifier.turns_left))
        elif modifier.turns_left != -1: # -1 means infinite duration
            print(">>> REMOVING MODIFIER: " + modifier.name)
            stat_modifiers.remove_at(i)
        else:
            print(">>> MODIFIER " + modifier.name + " HAS INFINITE DURATION")

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
                print(">>> MODIFIER " + modifier.name + " IS INACTIVE")
                continue

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

## Change a base stat value (not considering modifiers)
func set_stat(stat: CharacterStatEntry.ECharacterStat, new_value: int) -> void:
    for i in range(stats.size()):
        if stats[i].stat_key == stat:
            stats[i].stat_value = new_value
            OnStatChanged.emit(stat, new_value)
            break

# update modifiers when key 7 is pressed
func _input(event) -> void:
    if event is InputEventKey and event.is_pressed() and not event.is_echo() and event.keycode == KEY_7:
        update_modifiers()
        print(">>> MAX HP: " + str(get_stat(CharacterStatEntry.ECharacterStat.MaxHP)))
