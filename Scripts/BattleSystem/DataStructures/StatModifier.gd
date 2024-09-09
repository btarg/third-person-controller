@tool
class_name StatModifier
extends Resource

@export var stat: CharacterStatEntry.ECharacterStat = CharacterStatEntry.ECharacterStat.MaxHP

@export var name: String = "Stat Modifier"
@export var description: String = "Test Stat Modifier"
## Value to multiply the stat by
@export var stat_value: float = 1.0
## -1 means infinite duration until removed
@export var turn_duration: int = 1
var turns_left: int = 0
@export var can_stack: bool = true
## If true, this modifier will override any other modifiers of the same type
## (This only applies to non-stackable modifiers)
@export var stack_override: bool = false
