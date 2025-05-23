extends Resource
class_name CharacterStatEntry

enum ECharacterStat { ## Character Stat
    MaxHP, ## Integer
    MaxMP, ## Integer
    
    # Physical stats
    PhysicalStrength, ## Added to physical damage when not resisted, absorbed, or immune
    PhysicalDefense, ## Used to reduce incoming physical damage when resisted
    
    # Magical stats  
    MagicalStrength, ## Added to magical damage when not resisted, absorbed, or immune
    Spirit, ## Used to reduce incoming magical damage when resisted
    
    # Combat stats
    ArmourClass, ## Integer DC for the attacker to hit this character
    Speed, ## Integer bonus for initiative rolls, also represents movement in metres
    Luck, ## Integer bonus for crits, status effects, and draw bonus
    
    # Range stats
    AttackRange, ## Integer number of metres the character can attack from (basic attack)
    DrawRange, ## Integer number of metres the character can draw from
    
    # Beyond this point, we don't include these stats when levelling up.

    # Multipliers
    AttackCritMultiplier, ## Multiplier for damage on crit (float 0-1) 
    MagicCritMultiplier, ## Multiplier for magic damage on crit (float 0-1)
    MagicFailMultiplier, ## Multiplier for magic damage on fail (float 0-1) 
    MagicCritFailMultiplier, ## Multiplier for magic damage on crit fail (float 0-1)

    NONE ## Placeholder for no stat
}

@export var stat_key: ECharacterStat = ECharacterStat.MaxHP
@export var stat_value: float = 0.0
## Dice roll used to increase the stat when levelling up
@export var level_up_roll: DiceRoll:
    get:
        # TODO: PLACEHOLDER, these rolls should be set manually in the editor
        if (stat_key as int) > 10:
            return null
        return level_up_roll if level_up_roll != null else DiceRoll.roll(6)