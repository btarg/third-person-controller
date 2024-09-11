extends Node
class_name Inventory

# Define a dictionary to hold the items and their counts
var items: Dictionary = {}

signal inventory_updated(resource: BaseInventoryItem, count: int, is_new_item: bool)

func _ready() -> void:
    Console.add_command("print_inventory", print_inventory)
    inventory_updated.connect(_on_inventory_updated)

    

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
    
    if item_id as String in items:
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
    else:
        print("Item not found in inventory.")
        

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
    for item_id: String in items.keys():
        Console.print_line("%s (%s): %s" % [items[item_id]["resource"].item_name, item_id, items[item_id]["count"]])
