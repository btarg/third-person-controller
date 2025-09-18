extends Area3D

@onready var fire_spell: Item = ItemResourceCache.load_item("res://Scripts/Data/Items/Spells/test_fire_spell.tres")

func _ready() -> void:
    body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node3D) -> void:
    print("Projectile hit: " + str(body.name))

    var character: BattleCharacter = body.get_node("BattleCharacter")
    if not character:
        return
    print("Hit character: " + character.character_name)
    
    if character.is_alive():
        fire_spell.activate(character, character, false, false)