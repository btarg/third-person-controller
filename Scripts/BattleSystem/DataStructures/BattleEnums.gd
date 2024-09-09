class_name BattleEnums

enum CharacterType {
    PLAYER,
    FRIENDLY,
    NEUTRAL, ## Neutral characters will become enemies if attacked
    ENEMY
}

enum EAffinityElement {
    PHYS,
    FIRE,
    ICE,
    ELEC,
    WIND,
    LIGHT,
    DARK,
    HEAL,
    MANA,
    ALMIGHTY
}

enum EPlayerCombatAction {
    CA_ATTACK, ## Choose a target to attack
    CA_DEFEND, ## Defend self (no target selection)
    CA_EFFECT_SELF, ## Choose self to buff/debuff (no target selection)
    CA_EFFECT_ALLY, ## Choose an ally to buff/debuff
    CA_EFFECT_ENEMY, ## Choose an enemy to buff/debuff
    CA_DRAW_AND_STOCK, ## Draw a spell and end turn
    CA_DRAW_AND_CAST, ## Draw a spell and then choose a target to cast it on
    CA_SPECIAL_SKILL, ## Use a special skill and choose target
    CA_CAST_SPELL, ## Immediately cast a spell from inventory
    CA_USE_ITEM ## Use an item from inventory
}

enum ESkillResult {
    SR_SUCCESS, ## Generic success
    SR_CRITICAL, ## Critical hit
    SR_RESISTED, ## An attack was successful but not as effective as expected
    SR_EVADED, ## An attack was evaded by the target
    SR_ABSORBED, ## An attack was absorbed by the target
    SR_REFLECTED, ## An attack was reflected back at the attacker
    SR_IMMUNE, ## An attack had no effect on the target
    SR_FAIL, ## Generic failure
    SR_NOT_ENOUGH_HP,
    SR_NOT_ENOUGH_SP
}

enum EAffinityType {
    WEAK,
    RESIST,
    IMMUNE,
    REFLECT,
    ABSORB,
    UNKNOWN
}