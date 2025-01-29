extends Node
class_name BattleCharacter

@export var character_type : BattleEnums.ECharacterType = BattleEnums.ECharacterType.PLAYER
@export var default_character_name: String = "Test Enemy"
@onready var character_name := default_character_name
@onready var character_internal_name := get_parent().get_name()

# Key = EAffinityElement, Value = EAffinityType
@export var affinities: Dictionary = {}
@export var basic_attack_element: BattleEnums.EAffinityElement = BattleEnums.EAffinityElement.PHYS

@export var debug_always_crit: bool = false

# TODO: replace this draw list for every character
@export var draw_list: Array[SpellItem] = [
    preload("res://Scripts/Inventory/Resources/Spells/test_fire_spell.tres"),
    preload("res://Scripts/Inventory/Resources/Spells/test_healing_spell.tres"),
    preload("res://Scripts/Inventory/Resources/Spells/test_almighty_spell.tres")
]

@onready var battle_state := get_node("/root/GameModeStateMachine/BattleState") as BattleState
@onready var exploration_state := get_node("/root/GameModeStateMachine/ExplorationState") as ExplorationState
@onready var behaviour_state_machine := self.get_node("StateMachine") as StateMachine

@onready var stats := $CharacterStats as CharacterStats
@onready var inventory := get_node_or_null("../Inventory") as Inventory

@onready var current_hp: int = ceil(stats.get_stat(CharacterStatEntry.ECharacterStat.MaxHP))
# The third person player controller extends from the BattleCharacterController to make this possible
@onready var character_controller := get_parent() as BattleCharacterController

signal OnLeaveBattle
signal OnCharacterTurnStarted

var character_active := false
var initiative: int = 0

## How many turns this character should be "down" for (when crit - ONE MORE system)
var down_turns := 0
## How many turns this character has left before moving to the next character in the turn order
var turns_left := 0

## Used for effects like Silence
var can_use_spells := true

func _ready() -> void:
    print("%s internal name %s" % [character_name, character_internal_name])

    BattleSignalBus.OnTurnStarted.connect(_on_battle_turn_started)

    print(character_name + " CURRENT HP: " + str(current_hp))

    # TODO: set affinities in editor once typed dictionaries are supported in Godot 4.4
    if character_internal_name == "TestEnemy":
        affinities = CharacterAffinities.affinities_test_enemy
    elif character_internal_name == "Player":
        affinities = CharacterAffinities.affinities_test_player

func print_stat(stat_int_string: String) -> void:
    var stat := int(stat_int_string) as CharacterStatEntry.ECharacterStat
    var stat_value := stats.get_stat(stat)
    Console.print_line("Stat %s: %s" % [Util.get_enum_name(CharacterStatEntry.ECharacterStat, stat), str(stat_value)])

func print_modifiers() -> void:
    if stats.stat_modifiers.size() == 0:
        Console.print_line("No modifiers active")
    else:
        for modifier in stats.stat_modifiers:
            var enum_name := Util.get_enum_name(CharacterStatEntry.ECharacterStat, modifier.stat)
            var stat_value_string := "x" if modifier.is_multiplier else "+"
            stat_value_string += str(modifier.stat_value)
            Console.print_line(modifier.name + " - " + enum_name + ": " + stat_value_string, true)

func on_join_battle() -> void:
    # We can reset the silence effect here since all combat buffs/debuffs are reset anyway
    can_use_spells = true
    BattleSignalBus.OnCharacterJoinedBattle.emit(self)

func on_leave_battle() -> void:
    character_name = default_character_name
    behaviour_state_machine.set_state("IdleState")

    stats.reset_modifiers()
    
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
    OnCharacterTurnStarted.emit()

    stats.active_modifiers_start_turn()

    if down_turns > 0:
        behaviour_state_machine.set_state("DownedState")
    else:
        behaviour_state_machine.set_state("ThinkState")
        down_turns = 0

func roll_initiative() -> int:
    var vitality := ceili(stats.get_stat(CharacterStatEntry.ECharacterStat.Vitality))
    if vitality < 0:
        vitality = 0

    # make sure to set the initiative value on our character for later reference
    initiative = DiceRoll.create(20, 1, vitality).roll_flat()
    return initiative

func heal(amount: int, from_absorb: bool = false, spell_status: BaseInventoryItem.UseStatus = BaseInventoryItem.UseStatus.SPELL_FAIL) -> void:
    var heal_string := "[HEAL] %s healed %s HP" % [character_name, str(amount)]
    if from_absorb:
        heal_string += " from ABSORB"
    print(heal_string)
    current_hp += amount
    var max_hp := stats.get_stat(CharacterStatEntry.ECharacterStat.MaxHP)
    if current_hp > max_hp:
        # We expect HP to be an int
        current_hp = ceili(max_hp)

    var skill_result := BattleEnums.ESkillResult.SR_FAIL
    match spell_status:
        BaseInventoryItem.UseStatus.SPELL_SUCCESS:
            skill_result = BattleEnums.ESkillResult.SR_SUCCESS
        BaseInventoryItem.UseStatus.SPELL_CRIT_SUCCESS:
            skill_result = BattleEnums.ESkillResult.SR_CRITICAL
        BaseInventoryItem.UseStatus.SPELL_CRIT_FAIL:
            skill_result = BattleEnums.ESkillResult.SR_FAIL

    var heal_number := DamageNumber.create_damage_number(
        amount, BattleEnums.EAffinityElement.HEAL, skill_result,
        self.get_parent(),
        battle_state.top_down_player.camera)
    add_child(heal_number)
    
    # always emit heal signal for animations
    BattleSignalBus.OnHeal.emit(self, amount)

func _on_downed() -> void:
    # TODO: play an animation for being downed
    down_turns = randi() % 3 + 1
    print("[DOWN] " + character_name + " is downed for " + str(down_turns) + " turns")

func _on_down_recovery() -> void:
    down_turns = 0
    # TODO  play an animation for recovering from being downed
    print("[DOWN] " + character_name + " has recovered from being downed")

func award_turns(turns: int) -> void:
    turns_left += turns
    print("[ONE MORE] " + character_name + " has been awarded " + str(turns) + " turns")
    BattleSignalBus.OnTurnsAwarded.emit(self, turns)

func take_damage(attacker: BattleCharacter, damage_rolls: Array[DiceRoll], damage_type: BattleEnums.EAffinityElement = BattleEnums.EAffinityElement.PHYS, dice_status: DiceRoll.DiceStatus = DiceRoll.DiceStatus.ROLL_SUCCESS, reflected: bool = false) -> BattleEnums.ESkillResult:
    # We've already decided whether we crit or not in the attack roll d20,
    # so we roll flat for the attacks themselves
    return take_damage_flat(attacker, DiceRoll.roll_all_flat(damage_rolls), damage_type, dice_status, reflected)

func take_damage_flat(attacker: BattleCharacter, damage: int, damage_type: BattleEnums.EAffinityElement = BattleEnums.EAffinityElement.PHYS, dice_status: DiceRoll.DiceStatus = DiceRoll.DiceStatus.ROLL_SUCCESS, reflected: bool = false) -> BattleEnums.ESkillResult:
    if damage <= 0:
        print(character_name + " took no damage")
        return BattleEnums.ESkillResult.SR_FAIL

    var result := BattleEnums.ESkillResult.SR_SUCCESS

    # Use get_or_add to prevent null values breaking this
    var affinity_type := affinities.get_or_add(damage_type, BattleEnums.EAffinityType.UNKNOWN) as BattleEnums.EAffinityType
    var enum_string := Util.get_enum_name(BattleEnums.EAffinityElement, damage_type)
    
    # log affinities first, since the dice roll status can override the affinity type
    if (affinity_type != BattleEnums.EAffinityType.UNKNOWN):
        if not AffinityLog.is_affinity_logged(character_internal_name, damage_type):
            print("[AL] " + character_name + " has not logged " + enum_string)
            AffinityLog.log_affinity(character_internal_name, damage_type, affinity_type)
        else:
            print("[AL] " + character_name + " has logged " + enum_string)

    if debug_always_crit:
        affinity_type = BattleEnums.EAffinityType.WEAK
    
    elif (affinity_type not in [
    BattleEnums.EAffinityType.IMMUNE,
    BattleEnums.EAffinityType.ABSORB,
    BattleEnums.EAffinityType.REFLECT]

    and damage_type != BattleEnums.EAffinityElement.ALMIGHTY):
        # dice crits only apply to UNKNOWN, (generic) and RESIST affinities
        match dice_status:
            DiceRoll.DiceStatus.ROLL_CRIT_SUCCESS:
                affinity_type = BattleEnums.EAffinityType.WEAK
            DiceRoll.DiceStatus.ROLL_CRIT_FAIL:
                affinity_type = BattleEnums.EAffinityType.IMMUNE
            DiceRoll.DiceStatus.ROLL_FAIL:
                affinity_type = BattleEnums.EAffinityType.RESIST

    #### HANDLE CRIT DAMAGE ####
    if (affinity_type != BattleEnums.EAffinityType.UNKNOWN):
        if (affinity_type == BattleEnums.EAffinityType.WEAK):
            # Handle down status for crits
            if down_turns == 0:
                BattleSignalBus.OnDowned.emit(self, down_turns)
                _on_downed()
                # Give the attacker a ONE MORE turn
                attacker.award_turns(1)

            # More crits will wake the enemy up rather than keeping them down
            # TODO: this event should be calulated based on a stat like vitality
            # else:
            #     BattleSignalBus.OnDownRecovery.emit(self)
            #     _on_down_recovery()

            damage = _calculate_crit_damage(attacker, damage)
            result = BattleEnums.ESkillResult.SR_CRITICAL
            
        elif affinity_type == BattleEnums.EAffinityType.REFLECT:
            # Prevent infinite reflection loops by just resisting an already reflected attack
            # TODO: attack mirrors and magic mirrors should have a counter for how many reflections they can do before breaking
            if reflected:
                print("[REFLECT] " + character_name + " resisted reflected " + enum_string)
                damage = _calculate_resist_damage(damage)
                result = BattleEnums.ESkillResult.SR_RESISTED
            else:
                print(character_name + " reflected " + enum_string)
                # Reflect damage back at attacker (true flag to prevent infinite loops)
                attacker.take_damage_flat(self, damage, damage_type, dice_status, true)
                result = BattleEnums.ESkillResult.SR_REFLECTED
                # Set damage to 0 so we don't apply it to the character who reflected
                damage = 0

        elif (affinity_type == BattleEnums.EAffinityType.RESIST
        and damage_type != BattleEnums.EAffinityElement.ALMIGHTY):
            # basic attacks even with affinities do 0 damage on fail
            # this obviously does not apply to weaknesses since they are
            # handled in the crit block above
            if (dice_status == DiceRoll.DiceStatus.ROLL_FAIL
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
            heal(damage, true)
            result = BattleEnums.ESkillResult.SR_ABSORBED
            damage = 0


    # only apply attacker strength when the attack was not a crit, resisted, absorbed, or immune
    # (aka normal damage - doesn't apply to almighty)
    elif attacker and damage_type != BattleEnums.EAffinityElement.ALMIGHTY:
        # Regular failed rolls don't do damage for basic melee attacks (non spell attacks)
        if ((dice_status == DiceRoll.DiceStatus.ROLL_FAIL
        or dice_status == DiceRoll.DiceStatus.ROLL_CRIT_FAIL)
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
        BattleSignalBus.OnTakeDamage.emit(self, damage)
        if current_hp <= 0:
            current_hp = 0
            BattleSignalBus.OnDeath.emit(self)
            print("[DEATH] " + character_name + " has died!!")
            
            if character_type != BattleEnums.ECharacterType.PLAYER:
                battle_state.leave_battle(self)
                # destroy parent object
                get_parent().queue_free()
            else:
                # Players are able to be revived once "dead"
                behaviour_state_machine.set_state("DeadState")

    var damage_number := DamageNumber.create_damage_number(damage, damage_type, result, self.get_parent(), battle_state.top_down_player.camera)
    add_child(damage_number)
    
    print("[DAMAGE] %s did %s damage to %s (%s)" % [attacker.character_name, damage, character_name, Util.get_enum_name(BattleEnums.ESkillResult, result)])
    
    return result

func _calculate_crit_damage(attacker: BattleCharacter, damage: int) -> int:
    var crit_multiplier := attacker.stats.get_stat(CharacterStatEntry.ECharacterStat.AttackCritMultiplier)
    var calculated_damage := ceili(damage * crit_multiplier)
    print("[CRIT] Crit multiplier: " + str(crit_multiplier))
    print("[CRIT] Calculated damage: " + str(calculated_damage))
    return calculated_damage
    
func _calculate_resist_damage(initial_damage: int) -> int:
    # use defense stat to reduce damage
    var defense := stats.get_stat(CharacterStatEntry.ECharacterStat.Defense)
    var calculated_damage := ceili(initial_damage * (1.0 - defense))
    print("[RESIST] Defense: " + str(defense) + " (" + str(defense * 100) + "%)")
    print("[RESIST] Calculated damage: %s (original: %s)" % [str(calculated_damage), initial_damage])
    return calculated_damage