class_name BaseInventoryItem
extends Resource

enum ItemType {
    SPELL,
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
@export var item_id: String = ""
@export var item_name: String = "???"
@export var item_description: String = "Test Description"
@export var max_stack: int = 999

@export var can_use_on_enemies: bool = true
@export var can_use_on_allies: bool = true

signal item_used(item_id: String, use_status: BaseInventoryItem.UseStatus)

# Preload audio types
var heal_sound := preload("res://Assets/Sounds/heal.wav") as AudioStream
var mana_sound := preload("res://Assets/Sounds/mana.wav") as AudioStream


func _init(_item_name: String = "", _max_stack: int = 999) -> void:
    self.item_name = _item_name
    self.max_stack = _max_stack

func get_icon_path() -> String:
    var icon_path := "res://Assets/Icons/item_"
    icon_path += Util.get_enum_name(BaseInventoryItem.ItemType, item_type).to_lower()
    return icon_path + ".png"

func get_rich_name(icon_size: int = 64) -> String:
    var icon_path = get_icon_path()
    return "[hint=%s][img=%s]%s[/img]%s[/hint]" % [item_description, icon_size, icon_path, item_name]

func get_use_sound() -> AudioStream:
    match item_type:
        ItemType.CONSUMABLE_HP:
            return heal_sound
        ItemType.CONSUMABLE_MP:
            return mana_sound
        _:
            return null

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

    item_used.emit(item_id, status)
    return status
