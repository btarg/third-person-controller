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

const _combat_action_selection_map: Dictionary = {
    EPlayerCombatAction.CA_ATTACK: [true, false],
    EPlayerCombatAction.CA_EFFECT_ENEMY: [true, false],
    EPlayerCombatAction.CA_EFFECT_ALLY: [false, true],
    EPlayerCombatAction.CA_DRAW: [true, false],
    EPlayerCombatAction.CA_CAST_SELF: [false, false],
    EPlayerCombatAction.CA_CAST_ALLY: [false, true],
    EPlayerCombatAction.CA_CAST_ENEMY: [true, false],
    EPlayerCombatAction.CA_CAST_ANY: [true, true],
}

static func get_combat_action_selection(chosen_action: EPlayerCombatAction) -> Dictionary:
    var selection := _combat_action_selection_map.get(chosen_action, [false, false]) as Array[bool]
    return { "can_select_enemies": selection[0], "can_select_allies": selection[1] }

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