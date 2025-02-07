extends Node
class_name DrawLog

var _drawn_spells: Array[String] = []

func _ready() -> void:
    # TODO: load log from file
    pass

## Get the known name of a spell, or "???" if it hasn't been drawn yet
func get_draw_spell_name(spell: SpellItem) -> String:
    return spell.item_name if _drawn_spells.has(spell.item_id) else "???"

func add_spell_to_log(spell: SpellItem) -> void:
    _drawn_spells.append(spell.item_id)