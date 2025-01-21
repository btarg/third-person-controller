class_name BattleEnums

enum ECharacterType {
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
    ALMIGHTY,
    BUFF,
    DEBUFF
}
# TODO: Add more object types, e.g. doors or buttons that can be used in combat
enum EAvailableCombatActions {
    NONE, # No actions available
    SELF, # Allows selecting the current character only
    ALLY, # Allows selecting an ally to target for spells or items
    ENEMY, # Allows selecting a target to attack
    GROUND, # Allows selecting a position to move to
    MOVING, # Character is currently moving
}

enum EPlayerCombatAction {
    CA_ATTACK, ## Choose a target to attack
    CA_DEFEND, ## Defend self (no target selection)
    CA_ITEM, ## Use a non-spell item
    CA_DRAW, ## Draw a spell - whether to cast or end turn is decided in the state
    CA_SPECIAL_SKILL, ## Use a special skill and choose target
    CA_CAST, ## Cast a spell item
    CA_MOVE ## Use movement
}

static func get_combat_action_selection(chosen_action: EPlayerCombatAction, spell_or_item: BaseInventoryItem) -> Dictionary:
    var can_select_enemies := false
    var can_select_allies := false

    match chosen_action:
        BattleEnums.EPlayerCombatAction.CA_ATTACK,\
        # TODO: special skill should determine valid targets itself
        BattleEnums.EPlayerCombatAction.CA_SPECIAL_SKILL,\
        BattleEnums.EPlayerCombatAction.CA_DRAW:
            can_select_enemies = true
        BattleEnums.EPlayerCombatAction.CA_CAST,\
        BattleEnums.EPlayerCombatAction.CA_ITEM:
            if spell_or_item != null:
                can_select_enemies = spell_or_item.can_use_on_enemies
                can_select_allies = spell_or_item.can_use_on_allies
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
    SR_NOT_ENOUGH_SP,
    SR_OUT_OF_RANGE,
}

enum EAffinityType {
    WEAK,
    RESIST,
    IMMUNE,
    REFLECT,
    ABSORB,
    UNKNOWN,
    # GENERIC
}