extends Node

# Battle system
@warning_ignore("UNUSED_SIGNAL")
signal OnCharacterJoinedBattle(character: BattleCharacter)

@warning_ignore("UNUSED_SIGNAL")
signal OnTurnStarted(character: BattleCharacter)
@warning_ignore("UNUSED_SIGNAL")
signal OnCharacterSelected(character: BattleCharacter)
@warning_ignore("UNUSED_SIGNAL")
signal OnBattleStarted
@warning_ignore("UNUSED_SIGNAL")
signal OnBattleEnded

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
signal OnAvailableActionsChanged
