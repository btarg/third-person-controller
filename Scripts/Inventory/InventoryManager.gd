extends Node
class_name InventoryManager

## TODO: Typed Dictionary
## Item id as key, count as value
var items: Dictionary = {}
## Dictionary of item_id as key and a modifier id as value
var linked_modifiers: Dictionary = {}

## Item id as key, junctioned stat as value
var junctioned_stat_by_item: Dictionary = {}

@onready var battle_character := get_node("../BattleCharacter") as BattleCharacter

signal inventory_updated(resource: BaseInventoryItem, count: int, is_new_item: bool)

@onready var fire_spell: BaseInventoryItem = preload("res://Scripts/Inventory/Resources/Spells/test_fire_spell.tres")
@onready var heal_spell: BaseInventoryItem = preload("res://Scripts/Inventory/Resources/Spells/test_healing_spell.tres")
@onready var almighty_spell: BaseInventoryItem = preload("res://Scripts/Inventory/Resources/Spells/test_almighty_spell.tres")

func _ready() -> void:
    Console.add_command("print_inventory", print_inventory, 1)
    Console.add_command("set_junction", _set_junction_command, 3)
    Console.add_command("get_junction", _get_junctioned_stat, 2)


    Console.add_command("add_item_path", _add_item_command, 3)
    Console.add_command("remove_item_id", _remove_item_command, 3)
    
    inventory_updated.connect(_on_inventory_updated)
    # set_item_junctioned_stat(fire_spell.item_id, CharacterStatEntry.ECharacterStat.Strength)
    # add_item(heal_spell, 99)
    add_item(fire_spell, 5)
    # add_item(almighty_spell, 99)

func _add_item_command(character_name: String, item_path: String, count_string: String) -> void:
    if character_name != battle_character.character_internal_name:
        return
    var item: BaseInventoryItem = load("res://Scripts/Inventory/Resources/Spells/" + item_path + ".tres") as BaseInventoryItem
    if item:
        add_item(item, int(count_string))

func _remove_item_command(character_name: String, item_id: String, count_string: String) -> void:
    if character_name != battle_character.character_internal_name:
        return
    remove_item(item_id, int(count_string))

func _set_junction_command(character_name: String, item_id: String, stat_int_string: String) -> void:
    if character_name != battle_character.character_internal_name:
        return
    var stat := int(stat_int_string) as CharacterStatEntry.ECharacterStat
    set_item_junctioned_stat(item_id, stat)

func set_item_junctioned_stat(item_id: String, stat: CharacterStatEntry.ECharacterStat) -> void:    
    junctioned_stat_by_item[item_id] = stat
    _update_junction_modifiers(get_item(item_id) as SpellItem, get_item_count(item_id))
    Console.print_line("Junctioned item %s to stat %s" % [item_id, Util.get_enum_name(CharacterStatEntry.ECharacterStat, stat)])

func _get_junctioned_stat(character_name: String, item_id: String) -> CharacterStatEntry.ECharacterStat:
    if character_name != battle_character.character_internal_name:
        return CharacterStatEntry.ECharacterStat.NONE
    
    var result := junctioned_stat_by_item.get(item_id, CharacterStatEntry.ECharacterStat.NONE) as CharacterStatEntry.ECharacterStat
    Console.print_line("Junctioned stat for item %s: %s" % [item_id, Util.get_enum_name(CharacterStatEntry.ECharacterStat, result)])
    return result

# Function for debug
func _on_inventory_updated(resource: BaseInventoryItem, count: int, is_new_item: bool) -> void:
    print("Inventory updated: %s (%s) - %s" % [resource.item_name, resource.item_id, count])
    if is_new_item:
        print("New item added to inventory")
    else:
        print("Item count updated")

func _on_item_used(status: BaseInventoryItem.UseStatus) -> void:
    match status:
        BaseInventoryItem.UseStatus.CONSUMED_HP:
            print("SIGNAL: Item used to restore HP")
        BaseInventoryItem.UseStatus.CONSUMED_MP:
            print("SIGNAL: Item used to restore MP")
        BaseInventoryItem.UseStatus.CANNOT_USE:
            print("SIGNAL: Item cannot be used")
        BaseInventoryItem.UseStatus.EQUIPPED:
            print("SIGNAL: Item equipped")
        _:
            print("SIGNAL: Item used")

func _generate_stat_modifier(spell_item: SpellItem, stat: CharacterStatEntry.ECharacterStat, value: float) -> StatModifier:
    var modifier: StatModifier = StatModifier.new()
    modifier.turn_duration = -1
    modifier.can_stack = true
    modifier.modifier_id = "junction_" + spell_item.item_id
    modifier.name = spell_item.item_name + " (Junction)"
    modifier.description = "Junction effect for " + spell_item.item_name
    
    modifier.stat = stat
    modifier.is_multiplier = false
    modifier.stat_value = value

    return modifier


# Function to add items to the inventory
func add_item(item: BaseInventoryItem, count: int = 1) -> void:
    var is_new_item: bool = false
    if item.item_id in items:
        var current_count := items[item.item_id]["count"] as int
        var new_count := current_count + count
        # Ensure we do not exceed the max stack count
        if new_count > item.max_stack:
            print("Cannot add more than max stack count")
            new_count = item.max_stack
        items[item.item_id]["count"] = new_count
    else:
        # Add the item to the inventory
        items[item.item_id] = {"resource": item, "count": count}
        is_new_item = true
        item.connect("item_used", _on_item_used)
    
    var total := items[item.item_id]["count"] as int
    inventory_updated.emit(item, total, is_new_item)
    if item is SpellItem:
        _update_junction_modifiers(item as SpellItem, total)
    

func _update_junction_modifiers(spell_item: SpellItem, total_item_count: int) -> void:
    print("[Junction] Modifier update called with count " + str(total_item_count))
    if spell_item.junction_table.is_empty():
        print("[Junction] Spell has no junction table")
        return

    var junctioned_stat := junctioned_stat_by_item.get(spell_item.item_id, CharacterStatEntry.ECharacterStat.NONE) as CharacterStatEntry.ECharacterStat

    if total_item_count > 0:
        for stat: CharacterStatEntry.ECharacterStat in spell_item.junction_table.keys():
            # Only apply the modifier if it matches the junctioned stat
            if stat != junctioned_stat:
                continue
            
            var base_stat_value := battle_character.stats.get_stat(stat, false)
            var multiplier := spell_item.junction_table[stat] as float
            # Calculate how much to add to the stat value for each item in the stack
            # (difference between the base stat value and the value added by one multiplier)
            var add_to_stat_value: float = (base_stat_value * multiplier) - base_stat_value
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
    var item_id: String
    var item_resource: BaseInventoryItem
    
    # Determine if the item is a BaseInventoryItem or a String
    if item is BaseInventoryItem:
        print("Item is BaseInventoryItem")
        item_id = item.item_id
        item_resource = item
    elif item is String:
        print("Item is String")
        item_id = item
        item_resource = get_item(item_id)
    else:
        push_error("Invalid item type. Must be BaseInventoryItem or String.")
        return
    
    if item_id not in items:
        print("Item not found in inventory")
        return

    var current_count := items[item_id]["count"] as int
    print("Current count: " + str(current_count))
    var new_count := current_count - count
    print("New count: " + str(new_count))
    if new_count <= 0:
        print("Removing item from inventory")
        # disconnect signal for use
        item_resource.disconnect("item_used", _on_item_used)
        # erase item from map
        items.erase(item_id)
        new_count = 0
    else:
        print("Updating item count")
        items[item_id]["count"] = new_count

    _update_junction_modifiers(item_resource, new_count)
    inventory_updated.emit(item_resource, new_count, false)


# Get the count of an item in the inventory by its item_id
func get_item_count(item_id: String) -> int:
    if item_id as String in items:
        return items[item_id]["count"] as int
    return 0

# Get an existing item's resource by its item_id
func get_item(item_id: String) -> BaseInventoryItem:
    if item_id as String in items:
        return items[item_id]["resource"] as BaseInventoryItem
    return null

func print_inventory(character_name: String) -> void:
    if character_name != battle_character.character_internal_name:
        return
    for item_id: String in items.keys():
        Console.print_line("%s (%s): %s" % [items[item_id]["resource"].item_name, item_id, items[item_id]["count"]])