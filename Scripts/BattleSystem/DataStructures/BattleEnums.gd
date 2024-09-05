class_name BattleEnums

enum CharacterType {
    PLAYER,
    FRIENDLY,
    NEUTRAL,
    ENEMY
}
enum ESkillResult {
    SR_Success,
    SR_Critical,
    SR_Resisted,
    SR_Evaded,
    SR_Absorbed,
    SR_Reflected,
    SR_Fail,
    SR_NotEnoughHP,
    SR_NotEnoughSP
}

enum EAffinityType {
    Weak,
    Resist,
    Immune,
    Reflect,
    Absorb
}