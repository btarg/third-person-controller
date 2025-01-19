class_name ActiveStatModifier extends StatModifier

## When the modifier is first applied
func on_modifier_applied() -> void: pass

## Run at the start of every turn while the modifier is active
func on_turn_start() -> void: pass

## When the modifier is removed (depleted or actively removed)
func on_modifier_removed() -> void: pass


func _init() -> void:
    super._init()
