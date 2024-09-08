class_name BattleEnums

enum CharacterType {
    PLAYER,
    FRIENDLY,
    NEUTRAL, ## Neutral characters will become enemies if attacked
    ENEMY
}

enum EPlayerCombatAction {
    CA_Attack, ## Choose a target to attack
    CA_Defend, ## Defend self (no target selection)
    CA_EffectSelf, ## Choose self to buff/debuff (no target selection)
    CA_EffectAlly, ## Choose an ally to buff/debuff
    CA_EffectEnemy, ## Choose an enemy to buff/debuff
    CA_DrawAndStock, ## Draw a spell and end turn
    CA_DrawAndCast, ## Draw a spell and then choose a target to cast it on
    CA_SpecialSkill, ## Use a special skill and choose target
    CA_CastSpell, ## Immediately cast a spell from inventory
    CA_UseItem ## Use an item from inventory
}

enum ESkillResult {
    SR_Success, ## Generic success
    SR_Critical, ## Critical hit
    SR_Resisted, ## An attack was successful but not as effective as expected
    SR_Evaded, ## An attack was evaded by the target
    SR_Absorbed, ## An attack was absorbed by the target
    SR_Reflected, ## An attack was reflected back at the attacker
    SR_Fail, ## Generic failure
    SR_NotEnoughHP,
    SR_NotEnoughSP
}

enum EAffinityType {
    AT_Weak,
    AT_Resist,
    AT_Immune,
    AT_Reflect,
    AT_Absorb
}