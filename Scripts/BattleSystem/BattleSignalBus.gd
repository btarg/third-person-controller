extends Node

# Battle system
@warning_ignore("UNUSED_SIGNAL")
signal TurnStarted(character: BattleCharacter)
@warning_ignore("UNUSED_SIGNAL")
signal BattleEnded

# Characters in battle
@warning_ignore("UNUSED_SIGNAL")
signal OnHeal(character: BattleCharacter, amount: int)
@warning_ignore("UNUSED_SIGNAL")
signal OnRevive(character: BattleCharacter)
@warning_ignore("UNUSED_SIGNAL")
signal OnDeath(character: BattleCharacter)
@warning_ignore("UNUSED_SIGNAL")
signal OnTakeDamage(character: BattleCharacter, amount: int)
@warning_ignore("UNUSED_SIGNAL")
signal OnDowned(character: BattleCharacter, turns: int)
@warning_ignore("UNUSED_SIGNAL")
signal OnDownRecovery(character: BattleCharacter)
@warning_ignore("UNUSED_SIGNAL")
signal OnTurnsAwarded(character: BattleCharacter, turns: int)
@warning_ignore("UNUSED_SIGNAL")
signal OnAvailableActionsChanged()

func _ready() -> void:
    OnTakeDamage.connect(_on_take_damage)

func _on_take_damage(character: BattleCharacter, amount: int) -> void:
    # TODO: this will be used for damage number UI
    print("[Signal] Character " + character.character_name + " took " + str(amount) + " damage!")