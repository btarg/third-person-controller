extends Node
class_name BattleCharacter

@export var character_type : BattleEnums.CharacterType = BattleEnums.CharacterType.PLAYER
@export var default_character_name: String = "Test Enemy"
@onready var character_name := default_character_name
@onready var character_internal_name := get_parent().get_name()

# Key = EAffinityElement, Value = EAffinityType
@export var affinities: Dictionary = {}
@export var basic_attack_element: BattleEnums.EAffinityElement = BattleEnums.EAffinityElement.PHYS

@onready var battle_state := get_node("/root/GameModeStateMachine/BattleState") as BattleState
@onready var exploration_state := get_node("/root/GameModeStateMachine/ExplorationState") as ExplorationState
@onready var behaviour_state_machine := self.get_node("StateMachine") as StateMachine

@onready var stats := $CharacterStats as CharacterStats
@onready var current_hp: int = ceil(stats.get_stat(CharacterStatEntry.ECharacterStat.MaxHP))

signal OnLeaveBattle
signal OnTakeDamage(amount: int)
signal OnHeal(amount: int)
signal OnDeath

var character_active := false
var initiative: int = 0

func _ready() -> void:
    print("%s internal name %s" % [character_name, character_internal_name])

    battle_state.TurnStarted.connect(_on_battle_turn_started)
    print(character_name + " CURRENT HP: " + str(current_hp))

    # TODO: set affinities in editor once typed dictionaries are supported in Godot 4.4
    affinities = CharacterAffinities.affinities_test_enemy

    Console.add_command("print_modifiers", _print_modifiers, 1)
    Console.add_command("get_stat", _get_stat_command, 2)


func _get_stat_command(character: String, stat_int_string: String) -> void:
    
    if character != character_internal_name:
        return

    var stat := int(stat_int_string) as CharacterStatEntry.ECharacterStat
    var stat_value := stats.get_stat(stat)
    Console.print_line("Stat %s: %s" % [Util.get_enum_name(CharacterStatEntry.ECharacterStat, stat), str(stat_value)])

func _print_modifiers(character_to_print: String) -> void:
    if character_to_print == character_internal_name:
        if stats.stat_modifiers.size() == 0:
            Console.print_line("No modifiers active")
   
        for modifier in stats.stat_modifiers:
            var enum_name := Util.get_enum_name(CharacterStatEntry.ECharacterStat, modifier.stat)
            Console.print_line(modifier.name + " - " + enum_name + ": " + str(modifier.stat_value))

func on_leave_battle() -> void:
    character_name = default_character_name
    OnLeaveBattle.emit()

func _on_battle_turn_started(character: BattleCharacter) -> void:
    if character == self:
        start_turn()
    elif character_active:
        character_active = false

func start_turn() -> void:
    print("========")
    print(character_name + " is starting their turn")
    print("========")
    character_active = true

    behaviour_state_machine.set_state("ThinkState")


func roll_initiative() -> int:
    var vitality := ceili(stats.get_stat(CharacterStatEntry.ECharacterStat.Vitality))
    if vitality < 0:
        vitality = 0

    # make sure to set the initiative value on our character for later reference
    initiative = DiceRoller.roll_flat(20, 1) + vitality
    return initiative

func heal(amount: int, from_absorb: bool = false) -> void:
    var heal_string := "[HEAL] %s healed %s HP" % [character_name, str(amount)]
    if from_absorb:
        heal_string += " from ABSORB"
    print(heal_string)
    current_hp += amount
    var max_hp := stats.get_stat(CharacterStatEntry.ECharacterStat.MaxHP)
    if current_hp > max_hp:
        # We expect HP to be an int
        current_hp = ceili(max_hp)
    
    # always emit heal signal for animations
    OnHeal.emit(amount)

func _calculate_crit_damage(attacker: BattleCharacter, damage: int) -> int:
    var crit_multiplier := attacker.stats.get_stat(CharacterStatEntry.ECharacterStat.AttackCritMultiplier)
    var calculated_damage := ceili(damage * crit_multiplier)
    print("[CRIT] Crit multiplier: " + str(crit_multiplier))
    print("[CRIT] Calculated damage: " + str(calculated_damage))
    return calculated_damage
    
func _calculate_resist_damage(damage: int) -> int:
    # use defense stat to reduce damage
    var defense := stats.get_stat(CharacterStatEntry.ECharacterStat.Defense)
    var calculated_damage := ceili(damage * (1.0 - defense))
    print("[RESIST] Defense: " + str(defense))
    print("[RESIST] Calculated damage: " + str(calculated_damage))
    return calculated_damage




func take_damage(attacker: BattleCharacter, damage: int, damage_type: BattleEnums.EAffinityElement = BattleEnums.EAffinityElement.PHYS, dice_status: DiceRoller.DiceStatus = DiceRoller.DiceStatus.ROLL_SUCCESS, reflected: bool = false) -> BattleEnums.ESkillResult:
    if damage <= 0:
        print(character_name + " took no damage")
        return BattleEnums.ESkillResult.SR_FAIL

    var result := BattleEnums.ESkillResult.SR_SUCCESS

    # Use get_or_add to prevent null values breaking this
    var affinity_type := affinities.get_or_add(damage_type, BattleEnums.EAffinityType.UNKNOWN) as BattleEnums.EAffinityType
    
    if (not (affinity_type == BattleEnums.EAffinityType.IMMUNE
    or affinity_type == BattleEnums.EAffinityType.ABSORB
    or affinity_type == BattleEnums.EAffinityType.REFLECT)
    and damage_type != BattleEnums.EAffinityElement.ALMIGHTY):
        # crits only apply to UNKNOWN and RESIST affinities
        if dice_status == DiceRoller.DiceStatus.ROLL_CRIT_SUCCESS:
            affinity_type = BattleEnums.EAffinityType.WEAK
        elif dice_status == DiceRoller.DiceStatus.ROLL_CRIT_FAIL:
            affinity_type = BattleEnums.EAffinityType.IMMUNE
        elif dice_status == DiceRoller.DiceStatus.ROLL_FAIL:
            affinity_type = BattleEnums.EAffinityType.RESIST


    if (affinity_type != BattleEnums.EAffinityType.UNKNOWN):
        var enum_string := Util.get_enum_name(BattleEnums.EAffinityElement, damage_type)

        if not AffinityLog.is_affinity_logged(character_internal_name, damage_type):
            print("[AL] " + character_name + " has not logged " + enum_string)
            AffinityLog.log_affinity(character_internal_name, damage_type, affinity_type)
        else:
            print("[AL] " + character_name + " has logged " + enum_string)

        if (affinity_type == BattleEnums.EAffinityType.WEAK):
            damage = _calculate_crit_damage(attacker as BattleCharacter, damage)
            result = BattleEnums.ESkillResult.SR_CRITICAL

        elif affinity_type == BattleEnums.EAffinityType.REFLECT:
            # Prevent infinite reflection loops by just resisting an already reflected attack
            # TODO: attack mirrors and magic mirrors should have a counter for how many reflections they can do before breaking
            if reflected:
                print(character_name + " resisted reflected " + enum_string)
                damage = _calculate_resist_damage(damage)
                result = BattleEnums.ESkillResult.SR_RESISTED
            else:
                print(character_name + " reflected " + enum_string)
                # Reflect damage back at attacker
                attacker.take_damage(self, damage, damage_type, dice_status, true)
                result = BattleEnums.ESkillResult.SR_REFLECTED
                damage = 0

        elif (affinity_type == BattleEnums.EAffinityType.RESIST
        and damage_type != BattleEnums.EAffinityElement.ALMIGHTY):
            # basic attacks even with affinities do 0 damage on fail
            # this obviously does not apply to weaknesses since they are
            # handled in the crit block above
            if (dice_status == DiceRoller.DiceStatus.ROLL_FAIL
            and attacker.basic_attack_element == damage_type):
                print(character_name + " resisted " + enum_string)
                damage = 0
                result = BattleEnums.ESkillResult.SR_FAIL
            else:
                damage = _calculate_resist_damage(damage)
                result = BattleEnums.ESkillResult.SR_RESISTED

        elif (affinity_type == BattleEnums.EAffinityType.IMMUNE
        and damage_type != BattleEnums.EAffinityElement.ALMIGHTY):
            print(character_name + " is immune to " + enum_string)
            damage = 0
            result = BattleEnums.ESkillResult.SR_IMMUNE

        elif (affinity_type == BattleEnums.EAffinityType.ABSORB
        and damage_type != BattleEnums.EAffinityElement.ALMIGHTY):
            print(character_name + " absorbed " + enum_string)
            # Absorb damage and heal
            heal(damage)
            result = BattleEnums.ESkillResult.SR_ABSORBED
            damage = 0

        

    # only apply attacker strength when the attack was not a crit, resisted, absorbed, or immune
    # (aka normal damage - doesn't apply to almighty)
    elif attacker and damage_type != BattleEnums.EAffinityElement.ALMIGHTY:
        # Regular failed rolls don't do damage for basic melee attacks (non spell attacks)
        if ((dice_status == DiceRoller.DiceStatus.ROLL_FAIL
        or dice_status == DiceRoller.DiceStatus.ROLL_CRIT_FAIL)
        and attacker.basic_attack_element == damage_type):
            damage = 0
            result = BattleEnums.ESkillResult.SR_FAIL
        else:
            var attacker_strength := attacker.stats.get_stat(CharacterStatEntry.ECharacterStat.Strength)
            print("[Attack] Original Damage: " + str(damage))
            print(attacker.character_name + " has strength: " + str(attacker_strength))
            damage = ceil(damage * attacker_strength)
            print("[Attack] Damage with strength: " + str(damage))
    
    if damage > 0:
        current_hp -= damage
        OnTakeDamage.emit(damage)
        print(character_name + " took " + str(damage) + " damage")
        if current_hp <= 0:
            current_hp = 0
            OnDeath.emit()
            print(character_name + " has died")
            battle_state.leave_battle(self)

            # destroy parent object
            get_parent().queue_free()

    return result


func battle_input(_event) -> void: pass