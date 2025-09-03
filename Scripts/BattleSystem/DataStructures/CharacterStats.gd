extends Node
class_name CharacterStats

@export var stats: Array[CharacterStatEntry] = []
@export var stat_modifiers: Array[StatModifier] = []

signal OnStatChanged(stat: CharacterStatEntry.ECharacterStat, new_value: float)

@onready var this_character := self.get_parent() as BattleCharacter


func level_up_all_stats() -> void:
    for i in range(stats.size()):
        if stats[i].level_up_roll == null:
            Console.print_line("[Stat] Cannot level up stat " + Util.get_enum_name(CharacterStatEntry.ECharacterStat, stats[i].stat_key) + " because the level up roll is null.", true)
            continue
        stats[i].stat_value += stats[i].level_up_roll.reroll().total()
        Console.print_line("[Stat] LEVEL UP: " + Util.get_enum_name(CharacterStatEntry.ECharacterStat, stats[i].stat_key) + " INCREASED TO " + str(stats[i].stat_value), true)
        OnStatChanged.emit(stats[i].stat_key, stats[i].stat_value)

func level_up_stat(stat: CharacterStatEntry.ECharacterStat) -> void:
    for i in range(stats.size()):
        if stats[i].stat_key == stat:
            if stats[i].level_up_roll == null:
                Console.print_line("[Stat] Cannot level up stat " + Util.get_enum_name(CharacterStatEntry.ECharacterStat, stat) + " because the level up roll is null.", true)
                return
            stats[i].stat_value += stats[i].level_up_roll.reroll().total()
            print("[Stat] LEVEL UP: " + Util.get_enum_name(CharacterStatEntry.ECharacterStat, stat) + " INCREASED TO " + str(stats[i].stat_value))
            OnStatChanged.emit(stat, stats[i].stat_value)
            break

func add_stat_entry(entry: CharacterStatEntry) -> void:
    stats.append(entry)

## If a modifier with this ID already exists, replace it.
## Otherwise, add the new modifier.
func add_or_update_modifier(modifier: StatModifier) -> void:
    for i in range(stat_modifiers.size()):
        var mod := stat_modifiers[i] as StatModifier
        if mod.modifier_id == modifier.modifier_id:
            print("[Modifier] UPDATING MODIFIER: " + modifier.name + " OLD VALUE: " + str(mod.stat_value) + " NEW VALUE: " + str(modifier.stat_value))
            stat_modifiers[i] = modifier
            return
    add_modifier(modifier)

func add_modifier(modifier: StatModifier) -> void:
    
    modifier = modifier.duplicate()

    # Modifiers now know which character they are applied to
    modifier.character = this_character
    
    var modifier_string := "[Modifier] ADDING MODIFIER: " + modifier.name + " WITH VALUE: " + str(modifier.stat_value)
    if modifier.stat == CharacterStatEntry.ECharacterStat.NONE:
        modifier_string += " (No stat)"
    elif modifier.is_multiplier:
        modifier_string += " (Multiplier)"
    else:
        modifier_string += " (Additive)"

    print(modifier_string)
    

    # FIX: do not allow non-stackable modifiers with the same unique ID to be added multiple times.
    # We also check here if we should override an existing modifier. If we don't override, we simply do not add the new modifier.
    for i in range(stat_modifiers.size()):
        var mod := stat_modifiers[i] as StatModifier
        if mod.modifier_id == modifier.modifier_id:
            
            if modifier.can_stack:
                continue
            elif modifier.override:
                print("[Modifier] REPLACING MODIFIER WITH OVERRIDE: " + modifier.name)
                stat_modifiers[i] = modifier
                if modifier is ActiveStatModifier:
                    var active_modifier := modifier as ActiveStatModifier
                    active_modifier.on_modifier_applied()
                return
            else:
                push_warning("[Modifier] Modifier with unique ID %s already exists. Not adding duplicate." % modifier.modifier_id)
                return

    stat_modifiers.append(modifier)

    if modifier is ActiveStatModifier:
        var active_modifier := modifier as ActiveStatModifier
        active_modifier.on_modifier_applied()

## Remove by the modifier ID (e.g. test_strength_modifier)
func remove_modifier_by_id(id: String) -> void:
    for i in range(stat_modifiers.size()):
        if stat_modifiers[i].modifier_id == id:
            stat_modifiers.remove_at(i)
            break

func remove_modifier(modifier: StatModifier) -> void:
    if modifier is ActiveStatModifier:
        var active_modifier := modifier as ActiveStatModifier
        active_modifier.on_modifier_removed()

    stat_modifiers.erase(modifier)

func update_modifiers() -> void:
    for i in range(stat_modifiers.size()):
        var modifier := stat_modifiers[i] as StatModifier
        if modifier.turns_left >= 0:
            modifier.turns_left -= 1
            print("[Modifier] TURNS LEFT FOR " + modifier.name + ": " + str(modifier.turns_left))
        elif modifier.turns_left != -1: # -1 means infinite duration
            print("[Modifier] REMOVING MODIFIER: " + modifier.name)
            stat_modifiers.remove_at(i)

            if modifier is ActiveStatModifier:
                var active_modifier := modifier as ActiveStatModifier
                active_modifier.on_modifier_removed()

        else:
            print("[Modifier] MODIFIER " + modifier.name + " HAS INFINITE DURATION")

## Use true for the start of the turn and false for the end of the turn
func active_modifiers_on_turn(start: bool = true) -> void:
    for modifier: StatModifier in stat_modifiers:
        if modifier is ActiveStatModifier:
            var active_modifier := modifier as ActiveStatModifier
            
            if start:
                @warning_ignore("redundant_await")
                await active_modifier.on_turn_start()
            else:
                @warning_ignore("redundant_await")
                await active_modifier.on_turn_finished()

## Remove all modifiers that are not supposed to be applied out of combat
func reset_modifiers() -> void:
    for modifier: StatModifier in stat_modifiers:
        if not modifier.apply_out_of_combat:
            stat_modifiers.erase(modifier)

func get_stat(stat: CharacterStatEntry.ECharacterStat, with_modifiers: bool = true) -> float:
    # return stat with multipliers applied and stack multipliers if they have the stack flag
    var stat_value: float = -1.0
    for entry: CharacterStatEntry in stats:
        if entry.stat_key == stat:
            stat_value = entry.stat_value
            break

    if stat_value == -1.0:
        return 1.0
    
    var stat_value_with_modifiers := stat_value
    var stat_modifiers_copy := stat_modifiers.duplicate()

    # sort stat modifiers by turns left
    stat_modifiers_copy.sort_custom(
        func(a: StatModifier, b: StatModifier) -> bool:
            return true if a.turns_left < b.turns_left else false)

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

            elif modifier.override:
                
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
