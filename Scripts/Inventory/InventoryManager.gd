extends Node
class_name InventoryManager

## TODO: Typed Dictionary
## Item id as key, count as value
var items: Dictionary = {}
## Dictionary of item_id as key and an array of linked unique ids as value
var linked_modifiers: Dictionary = {}

## Item id as key, junctioned stat as value
var junctioned_stat_by_item: Dictionary = {}

@onready var battle_character := get_node("../BattleCharacter") as BattleCharacter

signal inventory_updated(resource: BaseInventoryItem, count: int, is_new_item: bool)

@onready var fire_spell: BaseInventoryItem = preload("res://Scripts/Inventory/Resources/Spells/test_fire_spell.tres")
@onready var heal_spell: BaseInventoryItem = preload("res://Scripts/Inventory/Resources/Spells/test_healing_spell.tres")
@onready var almighty_spell: BaseInventoryItem = preload("res://Scripts/Inventory/Resources/Spells/test_almighty_spell.tres")

func _ready() -> void:
    Console.add_command("print_inventory", print_inventory)
    Console.add_command("set_junction", _set_junction_command, 2)
    Console.add_command("get_junction", get_junctioned_stat, 1)
    inventory_updated.connect(_on_inventory_updated)
    set_item_junctioned_stat(fire_spell.item_id, CharacterStatEntry.ECharacterStat.Strength)
    add_item(heal_spell, 99)
    add_item(fire_spell, 99)
    add_item(almighty_spell, 99)

func _set_junction_command(item_id: String, stat_int_string: String) -> void:
    if not battle_character.character_active:
        return
    var stat := int(stat_int_string) as CharacterStatEntry.ECharacterStat
    set_item_junctioned_stat(item_id, stat)

func set_item_junctioned_stat(item_id: String, stat: CharacterStatEntry.ECharacterStat) -> void:    
    junctioned_stat_by_item[item_id] = stat
    Console.print_line("Junctioned item %s to stat %s" % [item_id, Util.get_enum_name(CharacterStatEntry.ECharacterStat, stat)])

func get_junctioned_stat(item_id: String) -> CharacterStatEntry.ECharacterStat:
    if not battle_character.character_active:
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

func _generate_stat_modifier(spell_item: SpellItem, stat: CharacterStatEntry.ECharacterStat) -> StatModifier:
    var modifier: StatModifier = StatModifier.new()
    modifier.turn_duration = -1
    modifier.can_stack = true
    modifier.name = spell_item.item_name + " (Junction)"
    modifier.description = "Junction effect for " + spell_item.item_name

    modifier.stat = stat
    modifier.stat_value = spell_item.junction_table[stat] as float

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
    inventory_updated.emit(item, items[item.item_id]["count"], is_new_item)

    # add stat modifiers if the item has any
    if item is SpellItem:
        var spell_item := item as SpellItem
        if spell_item.junction_table.size() > 0:
            for stat: CharacterStatEntry.ECharacterStat in spell_item.junction_table.keys():
                
                # Only apply the modifier if it matches the junctioned stat
                var junctioned_stat := junctioned_stat_by_item.get(spell_item.item_id, CharacterStatEntry.ECharacterStat.NONE) as CharacterStatEntry.ECharacterStat
                if junctioned_stat != stat:
                    continue

                # repeat for every item added
                for i in range(count):
                    print("[INVENTORY] Adding junction modifier for %s to %s" % [spell_item.item_name, Util.get_enum_name(CharacterStatEntry.ECharacterStat, stat)])
                    var modifier := _generate_stat_modifier(spell_item, stat)
                    battle_character.stats.add_modifier(modifier)
                    # Use the unique id instead of the modifier id so we can keep track of individual modifiers
                    # even if they are copies / stacked
                    if linked_modifiers.has(spell_item.item_id):
                        linked_modifiers[spell_item.item_id].append(modifier.unique_id)
                    else:
                        linked_modifiers[spell_item.item_id] = [modifier.unique_id]

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

    item_id = item_id as String

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
    inventory_updated.emit(item_resource, new_count, false)

    if linked_modifiers.has(item_id):
        for modifier: StatModifier in battle_character.stat_modifiers:
            if modifier.unique_id in linked_modifiers[item_id] as Array[String]:
                print("[Inventory] Removing modifier: " + modifier.name)
                battle_character.stats.remove_modifier(modifier)
                linked_modifiers[item_id].erase(modifier.unique_id)
        

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

func print_inventory() -> void:
    if not battle_character.character_active:
        return

    for item_id: String in items.keys():
        Console.print_line("%s (%s): %s" % [items[item_id]["resource"].item_name, item_id, items[item_id]["count"]])
