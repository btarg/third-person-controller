class_name Inventory extends Node

const DEBUG_INFINITE_ITEMS: bool = false
const DEBUG_PRINT: bool = false

## How many decimal places to round to when calculating stat modifier value for junctioned items
const JUNCTION_DECIMAL_PLACES: int = 5

## Item ID and their counts in the inventory
var items: Dictionary[int, int] = {}

## Dictionary of item_id as key and a modifier id as value
var linked_modifiers: Dictionary[int, String] = {}

## Item id as key, junctioned stat as value
var junctioned_stat_by_item: Dictionary[int, CharacterStatEntry.ECharacterStat] = {}

@onready var battle_character := get_node("../BattleCharacter") as BattleCharacter

signal inventory_updated(resource: Item, count: int, is_new_item: bool)

# signal item_used(item_id: Item, use_status: Item.UseStatus)


func _ready() -> void:


    if DEBUG_PRINT:
        print("%s Inventory ready" % battle_character.character_name)
    
    # Add 15 of each spell to inventory for testing
    var spells := Util.get_files_with_extension("res://Scripts/Data/Items/Spells/", ".tres")
    for spell in spells:
        var i := ItemResourceCache.load_item(spell)
        add_item(i, 15)


    # TEST: set two different spells to the same stat, should only apply the modifier for the last one
    # since only one item is allowed to be junctioned to one stat at a time
    # I also set the same item to two different stats, should only apply the modifier for the last one
    # set_item_junctioned_stat(fire_spell.item_id, CharacterStatEntry.ECharacterStat.PhysicalStrength)
    # set_item_junctioned_stat(fire_spell.item_id, CharacterStatEntry.ECharacterStat.PhysicalDefense)
    # set_item_junctioned_stat(heal_spell.item_id, CharacterStatEntry.ECharacterStat.PhysicalStrength)

    if DEBUG_PRINT:
        print_inventory()


## Important: Called by items when they are used, so we can properly update the inventory.
func item_used_callback(item: Item) -> void:
    if not DEBUG_INFINITE_ITEMS:
        remove_item(item.item_id, 1)


func filtered_item_ids(predicate: Callable) -> Array[String]:
    var filtered_item_list: Array[String] = []
    for item_id in items:
        var item = get_item(item_id)
        if item and predicate.call(item):
            filtered_item_list.append(item_id)
    return filtered_item_list

func filtered_items(predicate: Callable) -> Array[Item]:
    var filtered_item_list: Array[Item] = []
    for item_id in items:
        var item = get_item(item_id)
        if item and predicate.call(item):
            filtered_item_list.append(item)
    return filtered_item_list

func get_items() -> Array[Item]:
    var item_list: Array[Item] = []
    for item_id in items:
        var item = get_item(item_id)
        if item:
            item_list.append(item)
    return item_list

## Set the stat that an item is junctioned to.
## [br]If the item was already junctioned to a different stat, the previous junction is removed.
## [br]Stats will usually be integers, but junction modifiers are typically additive floats. The final stat will be rounded.
## [br]E.g. 99 items junctioned to Strength with a multiplier of 1.005 and a base stat value of 1.0 will add 0.495 to the stat value,
## resulting in 1.5 being added to the attack, then the attack gets rounded up.
func set_item_junctioned_stat(item_id: int, stat: CharacterStatEntry.ECharacterStat) -> void:
    var old_stat := junctioned_stat_by_item.get(item_id, CharacterStatEntry.ECharacterStat.NONE) as CharacterStatEntry.ECharacterStat
    # If the item was junctioned to a different stat, remove that junction first
    if old_stat != CharacterStatEntry.ECharacterStat.NONE and old_stat != stat:
        junctioned_stat_by_item.erase(item_id)
        var prev_item := get_item(item_id) as Item
        if prev_item:
            # Remove old stat's junction effect by forcing count=0
            _update_junction_modifiers(prev_item, 0)

    # Now apply the new junction
    junctioned_stat_by_item[item_id] = stat
    _update_junction_modifiers(get_item(item_id) as Item, get_item_count(item_id))
    Console.print_line("[JUNCTION] Junctioned item %s to stat %s"
        % [item_id, Util.get_enum_name(CharacterStatEntry.ECharacterStat, stat)], true)

func _get_junctioned_stat(character_name: String, item_id: String) -> CharacterStatEntry.ECharacterStat:
    if character_name != battle_character.character_internal_name:
        return CharacterStatEntry.ECharacterStat.NONE
    
    var result := junctioned_stat_by_item.get(item_id, CharacterStatEntry.ECharacterStat.NONE) as CharacterStatEntry.ECharacterStat
    Console.print_line("Junctioned stat for item %s: %s" % [item_id, Util.get_enum_name(CharacterStatEntry.ECharacterStat, result)], true)
    return result

# Function for debug
func _on_inventory_updated(resource: Item, count: int, is_new_item: bool) -> void:
    if DEBUG_PRINT:
        print("[%s Inventory] Updated: %s (id:%d) - %s | New: %s" % [battle_character.character_name, resource.item_name, resource.item_id, count, str(is_new_item)])


func _generate_stat_modifier(spell_item: Item, stat: CharacterStatEntry.ECharacterStat, value: float) -> StatModifier:
    var modifier: StatModifier = StatModifier.new()
    modifier.turn_duration = -1
    modifier.apply_out_of_combat = true
    modifier.can_stack = true
    modifier.modifier_id = "junction_" + str(spell_item.item_id)
    modifier.name = spell_item.item_name + " (Junction)"
    modifier.description = "Junction effect for " + spell_item.item_name
    
    modifier.stat = stat
    modifier.is_multiplier = false # Junctioned stats are additive
    modifier.stat_value = Util.round_to_dec(value, JUNCTION_DECIMAL_PLACES)

    return modifier

func add_item(item_to_add: Item, count: int = 1) -> void:    
    if not item_to_add:
        printerr("Cannot add null item to inventory")
        return
    
    if item_to_add.item_id == -1:
        printerr("Cannot add item with invalid ID")
        return
    
    var item_id := item_to_add.item_id
    var current_count: int = items.get(item_id, 0)
    var new_count: int = min(current_count + count, item_to_add.max_stack)
    var is_new_item: int = current_count == 0
    
    items[item_id] = new_count

    if DEBUG_PRINT:
        print("[Inventory] Added %s of item %s (%s) - new count: %s" % [count, item_to_add.item_name, item_id, new_count])
    
    inventory_updated.emit(item_to_add, new_count, is_new_item)
    
    if item_to_add.item_type in [Item.ItemType.BATTLE_ITEM, Item.ItemType.FIELD_ITEM]:
        _update_junction_modifiers(item_to_add, new_count)

func _update_junction_modifiers(item_junctioned: Item, total_item_count: int) -> void:
    if not item_junctioned:
        push_error("[Junction] Item is null")
        return
    # print("[Junction] %s called modifier update with count " % spell_item.item_name + str(total_item_count))
    
    var junctioned_stat := junctioned_stat_by_item.get(item_junctioned.item_id, CharacterStatEntry.ECharacterStat.NONE) as CharacterStatEntry.ECharacterStat

    if total_item_count > 0 and item_junctioned.junction_table and item_junctioned.junction_table.size() > 0:
        for stat: CharacterStatEntry.ECharacterStat in item_junctioned.junction_table.keys():
            # Only apply the modifier if it matches the junctioned stat
            if stat != junctioned_stat:
                continue
            
            var base_stat_value := battle_character.stats.get_stat(stat, false)
            var junction_value := item_junctioned.junction_table[stat]
            # Calculate how much to add to the stat value for each item in the stack
            # (difference between the base stat value and the value added by one multiplier)
            var add_to_stat_value: float = (base_stat_value + junction_value) - base_stat_value
            add_to_stat_value *= total_item_count
            var modifier := _generate_stat_modifier(item_junctioned, stat, add_to_stat_value)
            # if we already have the modifier with this id, update the value
            battle_character.stats.add_or_update_modifier(modifier)
            linked_modifiers[item_junctioned.item_id] = modifier.modifier_id
    else:
        
        # Remove the modifier if the item count is 0
        var modifier_id := linked_modifiers.get(item_junctioned.item_id, "") as String
        print("REMOVING MODIFIER " + modifier_id)
        if modifier_id != "":
            battle_character.stats.remove_modifier_by_id(modifier_id)
            linked_modifiers.erase(item_junctioned.item_id)

# Remove an existing item by its item ID
func remove_item(item_id: int, amount_to_remove: int) -> void:
    var item_resource: Item = get_item(item_id)
    if not item_resource:
        push_error("[Inventory] Invalid item resource for ID: " + str(item_id))
        return
    
    if item_id not in items:
        push_error("[Inventory] Item %d not found. Available item IDs: %s" % [item_id, str(items.keys())])
        return

    var current_count: int = items.get(item_id, 0)

    var new_count := current_count - amount_to_remove
    if new_count <= 0:

        if DEBUG_PRINT:
            print("[Inventory] Removing whole stack of %s (id:%d)" % [item_resource.item_name, item_id])
        
        # erase item from map
        items.erase(item_id)
        new_count = 0
    else:
        items[item_id] = new_count

    _update_junction_modifiers(item_resource, new_count)

    if DEBUG_PRINT:
        print("[%s Inventory] Removed %s of item %s (id:%d) - new count: %s" % [battle_character.character_name, amount_to_remove, item_resource.item_name, item_id, new_count])

    inventory_updated.emit(item_resource, new_count, false)



# Get the count of an item in the inventory by its item_id
func get_item_count(item_id: int) -> int:
    return items.get(item_id, 0)

# Get an existing item's resource by its item_id
func get_item(item_id: int) -> Item:
    return ItemResourceCache.get_cached_item(item_id)

func print_inventory() -> void:
    if not items.is_empty():
        for item_id in items.keys():
            var item := get_item(item_id)
            if item:
                Console.print_line("%s (id:%d): %s" % [item.item_name, item_id, items[item_id]], true)
    else:
        Console.print_line("Inventory is empty", true)
