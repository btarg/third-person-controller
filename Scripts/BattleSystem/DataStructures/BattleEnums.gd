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
    CA_DRAW, ## Draw a spell - whether to cast or end turn is decided in the state
    CA_SPECIAL_SKILL, ## Use a special skill and choose target
    CA_CAST_SELF, ## Cast a spell from inventory on self
    CA_CAST_ALLY, ## Cast a spell from inventory on an ally
    CA_CAST_ENEMY, ## Cast a spell from inventory on an enemy
    CA_CAST_ANY, ## Cast a spell from inventory on any target
    CA_USE_ITEM ## Use an item from inventory
}

static func get_combat_action_selection(chosen_action: EPlayerCombatAction) -> Dictionary:
    var can_select_enemies := false
    var can_select_allies := false

    match chosen_action:
        (BattleEnums.EPlayerCombatAction.CA_ATTACK
        or BattleEnums.EPlayerCombatAction.CA_CAST_ENEMY
        or BattleEnums.EPlayerCombatAction.CA_EFFECT_ENEMY
        or BattleEnums.EPlayerCombatAction.CA_DRAW):
            can_select_enemies = true
        (BattleEnums.EPlayerCombatAction.CA_CAST_ALLY
        or BattleEnums.EPlayerCombatAction.CA_EFFECT_ALLY):
            can_select_allies = true
        BattleEnums.EPlayerCombatAction.CA_CAST_ANY:
            can_select_enemies = true
            can_select_allies = true
        _:
            pass

    return { "can_select_enemies": can_select_enemies, "can_select_allies": can_select_allies }

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