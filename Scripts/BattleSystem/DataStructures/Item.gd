class_name BaseInventoryItem
extends Resource

enum ItemType {
    SPELL, ## A spell that can be used on another character
    SPELL_USE_ANYWHERE, ## Allows the item to be used on a position in the world, instead of a character target
    WEAPON,
    ARMOR,
    CONSUMABLE_HP,
    CONSUMABLE_MP,
    QUEST,
    MISC
}
enum UseStatus {
    SPELL_FAIL,
    SPELL_SUCCESS,
    SPELL_CRIT_FAIL,
    SPELL_CRIT_SUCCESS,
    CONSUMED_HP,
    CONSUMED_MP,
    CANNOT_USE,
    EQUIPPED
}

## item_type should be SPELL for a SpellItem
@export var item_type: ItemType = ItemType.WEAPON

var item_id : String = "default_item_id":
    get:
        return resource_path.get_file().trim_suffix('.tres')

@export var item_name: String = "???"
@export var item_description: String = "Test Description"
@export var max_stack: int = 999

@export var can_use_on_enemies: bool = true
@export var can_use_on_allies: bool = true

## How far away a target can be to use this item (does not apply to self)
@export var effective_range: int = 5

@export_group("Cost")
@export var actions_cost: int = 1
@export var mp_cost: int = 0


var inventory: Inventory = null

# Preload audio types
var heal_sound := preload("res://Assets/Sounds/heal.wav") as AudioStream
var mana_sound := preload("res://Assets/Sounds/mana.wav") as AudioStream


func _init(_item_name: String = "", _max_stack: int = 999) -> void:
    self.item_name = _item_name
    self.max_stack = _max_stack

## This is to be overloaded by child classes
func get_item_description() -> String:
    return item_description

func get_icon_path() -> String:
    var icon_path := "res://Assets/GUI/Icons/Items/item_"
    icon_path += Util.get_enum_name(BaseInventoryItem.ItemType, item_type).to_lower()
    return icon_path + ".png"

func get_rich_name(icon_size: int = 64) -> String:
    var icon_path = get_icon_path()
    return "[hint=%s][img=%s]%s[/img]%s[/hint]" % [get_item_description(), icon_size, icon_path, item_name]

func get_use_sound() -> AudioStream:
    match item_type:
        ItemType.CONSUMABLE_HP:
            return heal_sound
        ItemType.CONSUMABLE_MP:
            return mana_sound
        _:
            return null

func check_cost(user: BattleCharacter) -> bool:
    if user == null:
        return false

    if user.actions_left < actions_cost:
        print("%s does not have enough actions left to use %s" % [user.character_name, item_name])
        return false

    if user.current_mp < mp_cost:
        print("%s does not have enough MP to use %s" % [user.character_name, item_name])
        return false

    return true

func can_use_on(user: BattleCharacter, target: BattleCharacter, ignore_costs: bool = false) -> bool:
    if user == null:
        return false
    if target == null and item_type != ItemType.SPELL_USE_ANYWHERE:
        return false

    if not check_cost(user) and not ignore_costs:
        return false
    
    # we can only use this on ourselves 
    if (user == target
    and not can_use_on_allies
    and not can_use_on_enemies):
        return true
    
    var same_side := (user.character_type in [BattleEnums.ECharacterType.FRIENDLY, BattleEnums.ECharacterType.PLAYER]) == \
                    (target.character_type in [BattleEnums.ECharacterType.FRIENDLY, BattleEnums.ECharacterType.PLAYER])
    
    return can_use_on_allies if same_side else can_use_on_enemies

func _update_inventory(status: UseStatus) -> void:
    inventory.on_item_used(self, status)

func use(user: BattleCharacter, target: BattleCharacter) -> UseStatus:
    var status: UseStatus

    match item_type:
        ItemType.CONSUMABLE_HP:
            print("%s Healing %s for %s HP" % [user.character_name, target.character_name, item_name])
            status = UseStatus.CONSUMED_HP
        ItemType.CONSUMABLE_MP:
            print("%s Restoring %s for %s MP" % [user.character_name, target.character_name, item_name])
            status = UseStatus.CONSUMED_MP
        _:
            print("Item cannot be consumed: %s" % item_name)
            status = UseStatus.CANNOT_USE
    
    _update_inventory(status)
    
    return status
