extends Resource
class_name CharacterStatEntry

enum ECharacterStat { ## Character Stat
    MaxHP, ## Integer
    MaxSP, ## Integer
    
    # Physical stats
    PhysicalStrength, ## Added to physical damage when not resisted, absorbed, or immune (float 0-1)
    PhysicalDefense, ## Used to reduce incoming physical damage (float 0-1) 
    
    # Magical stats  
    MagicalStrength, ## Added to magical damage when not resisted, absorbed, or immune (float 0-1)
    Spirit, ## Used to reduce incoming magical damage (float 0-1)
    
    # Combat stats
    ArmourClass, ## Integer DC for the attacker to hit this character
    Speed, ## Integer bonus for initiative rolls, also represents movement in metres
    Luck, ## Integer bonus for crits, status effects, and draw bonus
    AttackCritMultiplier, ## Multiplier for damage on crit (float 0-1) 
    
    # Range stats
    AttackRange, ## Integer number of metres the character can attack from (basic attack)
    DrawRange, ## Integer number of metres the character can draw from
    
    # Magic multipliers
    MagicCritMultiplier, ## Multiplier for magic damage on crit (float 0-1)
    MagicFailMultiplier, ## Multiplier for magic damage on fail (float 0-1) 
    MagicCritFailMultiplier, ## Multiplier for magic damage on crit fail (float 0-1)

    NONE ## Placeholder for no stat
}

@export var stat_key: ECharacterStat = ECharacterStat.MaxHP
@export var stat_value: float = 0.0