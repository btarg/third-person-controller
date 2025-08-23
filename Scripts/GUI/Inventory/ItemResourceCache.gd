extends Node
## Global item resource cache (Autoload)
## Manages loading and caching of Item resources to avoid duplication


## Cache of item resources by their ID for quick lookup
var _item_cache: Dictionary[String, Item] = {}

## Load an item resource by its resource path and cache it
func load_item(resource_path: String) -> Item:
    var item_id = resource_path.get_file().trim_suffix('.tres')
    
    # Check cache first
    if item_id in _item_cache:
        return _item_cache[item_id]
    
    # Load and cache
    var item := load(resource_path) as Item
    if item:
        item.item_id = item_id
        _item_cache[item_id] = item
        print("[ItemResourceCache] Loaded and cached item: %s (%s)" % [item.item_name, item_id])
    else:
        push_error("Failed to load item resource: %s" % resource_path)
    
    return item

## Get a cached item by its ID (without loading)
func get_cached_item(item_id: String) -> Item:
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

## Clear the cache (useful for memory management)
func clear_cache() -> void:
    _item_cache.clear()
    print("[ItemResourceCache] Cache cleared")

## Get cache statistics
func get_cache_stats() -> Dictionary:
    return {
        "cached_items": _item_cache.size(),
        "item_ids": get_cached_item_ids()
    }