class_name StatModifier extends Resource

@export var stat := CharacterStatEntry.ECharacterStat.MaxHP
@export var modifier_id: String = ""
@export var name: String = "Stat Modifier"
@export var description: String = "Test Stat Modifier"

## if true, the value is a multiplier, otherwise it's additive
@export var is_multiplier: bool = false
@export var stat_value: float = 1.0


## -1 means infinite duration until removed
## TODO: allow for setting round duration instead of turns
@export var turn_duration: int = 1
var turns_left: int = turn_duration
@export var can_stack: bool = true
## If true, this modifier will override any other modifiers of the same type
## (This only applies to non-stackable modifiers)
@export var stack_override: bool = false

## This modifier does not reset on combat end
@export var apply_out_of_combat: bool = false

var modifier_active: bool = true
## The character this modifier is applied to
var character: BattleCharacter = null

# A unique ID for each instance
var unique_id: String = ""

func _init() -> void:
    unique_id = generate_scene_unique_id()
