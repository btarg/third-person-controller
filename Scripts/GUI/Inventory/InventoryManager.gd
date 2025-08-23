extends Node
class_name Inventory

var items: Dictionary[Item, int] = {}
## Dictionary of item_id as key and a modifier id as value
var linked_modifiers: Dictionary[String, String] = {}

## Item id as key, junctioned stat as value
var junctioned_stat_by_item: Dictionary = {}
## How many decimal places to round to when calculating stat modifier value for junctioned items
const JUNCTION_DECIMAL_PLACES: int = 5

const DEBUG_INFINITE_ITEMS: bool = false

@onready var battle_character := get_node("../BattleCharacter") as BattleCharacter

signal inventory_updated(resource: Item, count: int, is_new_item: bool)
signal item_used(item_id: Item, use_status: Item.UseStatus)

var fire_spell: Item = load("res://Scripts/Data/Items/Spells//test_fire_spell.tres")
var heal_spell: Item = load("res://Scripts/Data/Items/Spells//test_healing_spell.tres")
var almighty_spell: Item = load("res://Scripts/Data/Items/Spells//test_almighty_spell.tres")
var ice_spell: Item = load("res://Scripts/Data/Items/Spells//test_ice_spell.tres")
var elec_spell: Item = load("res://Scripts/Data/Items/Spells//test_elec_spell.tres")
var wind_spell: Item = load("res://Scripts/Data/Items/Spells//test_wind_spell.tres")
var silence_spell: Item = load("res://Scripts/Data/Items/Spells//silence_spell.tres")

var aoe_spell: Item = load("res://Scripts/Data/Items/Spells//test_aoe_spell.tres")
var aoe_spell_2: Item = load("res://Scripts/Data/Items/Spells//test_cone_spell.tres")

var revive_item: Item = load("res://Scripts/Data/Items/test_revive_item.tres")

func _ready() -> void:

    print("InventoryManager ready")

    add_item(aoe_spell, 15)
    add_item(aoe_spell_2, 15)
    add_item(heal_spell, 15)
    add_item(fire_spell, 15)
#    add_item(ice_spell, 15)
#    add_item(elec_spell, 15)
#    add_item(wind_spell, 15)
    add_item(almighty_spell, 15)
    add_item(silence_spell, 15)
    add_item(revive_item, 15)


    # TEST: set two different spells to the same stat, should only apply the modifier for the last one
    # since only one item is allowed to be junctioned to one stat at a time
    # I also set the same item to two different stats, should only apply the modifier for the last one
    # set_item_junctioned_stat(fire_spell.item_id, CharacterStatEntry.ECharacterStat.PhysicalStrength)
    # set_item_junctioned_stat(fire_spell.item_id, CharacterStatEntry.ECharacterStat.PhysicalDefense)
    # set_item_junctioned_stat(heal_spell.item_id, CharacterStatEntry.ECharacterStat.PhysicalStrength)

    print_inventory()

func filtered_item_ids(predicate: Callable) -> Array[String]:
    var filtered_item_list: Array[String] = []
    for item in items:
        if predicate.call(item):
            filtered_item_list.append(item.item_id)
    return filtered_item_list

func filtered_items(predicate: Callable) -> Array[Item]:
    var filtered_item_list: Array[Item] = []
    for item in items:
        if predicate.call(item):
            filtered_item_list.append(item)
    return filtered_item_list

func get_items() -> Array[Item]:
    return items.keys()

## Set the stat that an item is junctioned to.
## [br]If the item was already junctioned to a different stat, the previous junction is removed.
## [br]Stats will usually be integers, but junction modifiers are typically additive floats. The final stat will be rounded.
## [br]E.g. 99 items junctioned to Strength with a multiplier of 1.005 and a base stat value of 1.0 will add 0.495 to the stat value,
## resulting in 1.5 being added to the attack, then the attack gets rounded up.
func set_item_junctioned_stat(item_id: String, stat: CharacterStatEntry.ECharacterStat) -> void:
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
    print("Inventory updated: %s (%s) - %s" % [resource.item_name, resource.item_id, count])
    if is_new_item:
        print("New item added to inventory")
    else:
        print("Item count updated")

func item_used_callback(item: Item, status: Item.UseStatus) -> void:
    print("[ITEM CALLBACK] %s used: %s" % [item.item_name, Util.get_enum_name(Item.UseStatus, status)])
    item_used.emit(item, status)
    
    if not DEBUG_INFINITE_ITEMS:
        remove_item(item, 1)

func _generate_stat_modifier(spell_item: Item, stat: CharacterStatEntry.ECharacterStat, value: float) -> StatModifier:
    var modifier: StatModifier = StatModifier.new()
    modifier.turn_duration = -1
    modifier.apply_out_of_combat = true
    modifier.can_stack = true
    modifier.modifier_id = "junction_" + spell_item.item_id
    modifier.name = spell_item.item_name + " (Junction)"
    modifier.description = "Junction effect for " + spell_item.item_name
    
    modifier.stat = stat
    modifier.is_multiplier = false # Junctioned stats are additive
    modifier.stat_value = Util.round_to_dec(value, JUNCTION_DECIMAL_PLACES)

    return modifier


func add_item(item: Item, count: int = 1) -> void:    
    if not item:
        printerr("Cannot add null item to inventory")
        return
    
    var is_new_item: bool = false
    var original_path := item.resource_path.get_file().trim_suffix('.tres') # Get the original resource path without the .tres extension
    
    item = item.duplicate() # duplicate to prevent setting properties of the original resource
    item.item_id = original_path # restore the original resource path after duplication   

    var current_count: int = items.get_or_add(item, 0)
    var new_count := current_count + count
    
    if current_count == 0:
        is_new_item = true
        # Add the item to the inventory
        item.inventory = self
    
    # Ensure we do not exceed the max stack count
    if new_count > item.max_stack:
        print("Cannot add more than max stack count")
        new_count = item.max_stack
    
    items[item] = new_count

    print("[Inventory] Added %s of item %s (%s) - new count: %s" % [count, item.item_name, item.item_id, new_count])
    inventory_updated.emit(item, new_count, is_new_item)
    
    if item.item_type in [Item.ItemType.BATTLE_ITEM, Item.ItemType.FIELD_ITEM]:
        _update_junction_modifiers(item, new_count)

func _update_junction_modifiers(spell_item: Item, total_item_count: int) -> void:
    if not spell_item:
        print("[Junction] Spell item is null")
        return
    # print("[Junction] %s called modifier update with count " % spell_item.item_name + str(total_item_count))
    var junctioned_stat := junctioned_stat_by_item.get(spell_item.item_id, CharacterStatEntry.ECharacterStat.NONE) as CharacterStatEntry.ECharacterStat

    if total_item_count > 0 and spell_item.junction_table and spell_item.junction_table.size() > 0:
        for stat: CharacterStatEntry.ECharacterStat in spell_item.junction_table.keys():
            # Only apply the modifier if it matches the junctioned stat
            if stat != junctioned_stat:
                continue
            
            var base_stat_value := battle_character.stats.get_stat(stat, false)
            var junction_value := spell_item.junction_table[stat]
            # Calculate how much to add to the stat value for each item in the stack
            # (difference between the base stat value and the value added by one multiplier)
            var add_to_stat_value: float = (base_stat_value + junction_value) - base_stat_value
            add_to_stat_value *= total_item_count
            var modifier := _generate_stat_modifier(spell_item, stat, add_to_stat_value)
            # if we already have the modifier with this id, update the value
            battle_character.stats.add_or_update_modifier(modifier)
            linked_modifiers[spell_item.item_id] = modifier.modifier_id
    else:
        
        # Remove the modifier if the item count is 0
        var modifier_id := linked_modifiers.get(spell_item.item_id, "") as String
        print("REMOVING MODIFIER " + modifier_id)
        if modifier_id != "":
            battle_character.stats.remove_modifier_by_id(modifier_id)
            linked_modifiers.erase(spell_item.item_id)

# Remove an existing item by its resource reference or item ID
func remove_item(item: Variant, count: int) -> void:
    var item_resource: Item
    
    # Determine if the item is a Item or a String
    if item is Item:
        item_resource = item
    elif item is String:
        item_resource = get_item(item)
        if not item_resource:
            print("Item not found in inventory")
            return
    else:
        push_error("Invalid item type. Must be Item or String.")
        return
    
    if item_resource not in items:
        print("Item not found in inventory")
        return

    var current_count: int = items[item_resource]
    var new_count := current_count - count
    if new_count <= 0:
        print("Removing item from inventory")
        # erase item from map
        items.erase(item_resource)
        new_count = 0
    else:
        items[item_resource] = new_count

    _update_junction_modifiers(item_resource, new_count)
    print("[Inventory] Removed %s of item %s (%s) - new count: %s" % [count, item_resource.item_name, item_resource.item_id, new_count])
    inventory_updated.emit(item_resource, new_count, false)


# Get the count of an item in the inventory by its item_id
func get_item_count(item_id: String) -> int:
    for item in items.keys():
        if item.item_id == item_id:
            return items[item]
    return 0

# Get an existing item's resource by its item_id
func get_item(item_id: String) -> Item:
    for item in items.keys():
        if item.item_id == item_id:
            return item
    return null

func print_inventory() -> void:
    if not items.is_empty():
        for item in items.keys():
            Console.print_line("%s (%s): %s" % [item.item_name, item.item_id, items[item]], true)
    else:
        Console.print_line("Inventory is empty", true)
