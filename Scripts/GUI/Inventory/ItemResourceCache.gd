extends Node
## Global item resource cache (Autoload)
## Manages loading and caching of Item resources to avoid duplication
const DEBUG_PRINT: bool = false

## Cache of item resources by their ID for quick lookup
var _item_cache: Dictionary[int, Item] = {}

## Load an item resource by its resource path and cache it
func load_item(resource_path: String) -> Item:
    var item_id = ResourceLoader.get_resource_uid(resource_path)
    
    # Check cache first
    if item_id in _item_cache:
        return _item_cache[item_id]
    
    # Load and cache
    var item := load(resource_path) as Item
    if item:
        item.item_id = item_id
        _item_cache[item_id] = item

        if DEBUG_PRINT:
            print("[IRC] Loaded and cached item: %s (%s)" % [item.item_name, item_id])
    
    else:
        push_error("Failed to load item resource: %s" % resource_path)
    
    return item

## Get a cached item by its ID (without loading)
func get_cached_item(item_id: int) -> Item:
    return _item_cache.get(item_id, null)

## Check if an item is cached
func is_cached(item_id: String) -> bool:
    return item_id in _item_cache

## Preload multiple items at once
func preload_items(resource_paths: Array[String]) -> void:
    for path in resource_paths:
        load_item(path)

## Get all cached item IDs
func get_cached_item_ids() -> Array[String]:
    var ids: Array[String] = []
    for item_id in _item_cache.keys():
        ids.append(item_id)
    return ids


## Get cache statistics
func get_cache_stats() -> Dictionary:
    return {
        "cached_items": _item_cache.size(),
        "item_ids": get_cached_item_ids()
    }