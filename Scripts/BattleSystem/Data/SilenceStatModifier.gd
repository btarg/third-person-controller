class_name SilenceStatModifier extends ActiveStatModifier

## When the modifier is first applied
func on_modifier_applied() -> void:
    print("%s has been silenced!" % character.character_name)
    character.can_use_spells = false

## Run at the start of every turn while the modifier is active
func on_turn_start() -> void: pass

## When the modifier is removed (depleted or actively removed)
func on_modifier_removed() -> void:
    character.can_use_spells = true


func _init() -> void:
    super._init()