extends Node

# Battle system
signal TurnStarted(character: BattleCharacter)
signal BattleEnded

# Characters in battle
signal OnHeal(character: BattleCharacter, amount: int)
signal OnDeath(character: BattleCharacter)
signal OnTakeDamage(character: BattleCharacter, amount: int)

func _ready() -> void:
    OnTakeDamage.connect(_on_take_damage)

func _on_take_damage(character: BattleCharacter, amount: int) -> void:
    print("[Signal] Character " + character.character_name + " took " + str(amount) + " damage!")