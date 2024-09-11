class_name StatModifier extends Resource

@export var stat := CharacterStatEntry.ECharacterStat.MaxHP
@export var modifier_id: String = ""
@export var name: String = "Stat Modifier"
@export var description: String = "Test Stat Modifier"
## Value to multiply the stat by
@export var stat_value: float = 1.0
## -1 means infinite duration until removed
@export var turn_duration: int = 1
var turns_left: int = turn_duration
@export var can_stack: bool = true
## If true, this modifier will override any other modifiers of the same type
## (This only applies to non-stackable modifiers)
@export var stack_override: bool = false

var modifier_active: bool = true

# A unique ID for each instance
var unique_id: String = ""

func _init() -> void:
    unique_id = generate_scene_unique_id()
