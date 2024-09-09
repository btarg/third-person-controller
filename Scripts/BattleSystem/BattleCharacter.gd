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

@onready var current_hp: int = stats.get_stat(CharacterStatEntry.ECharacterStat.MaxHP)

signal OnLeaveBattle
signal OnTakeDamage(amount: int)
signal OnDeath

var active := false
var initiative: int = 0

func _ready() -> void:
    print("%s internal name %s" % [character_name, character_internal_name])

    battle_state.TurnStarted.connect(_on_turn_started)
    print(character_name + " CURRENT HP: " + str(current_hp))

    # TODO: set affinities in editor once typed dictionaries are supported in Godot 4.4
    affinities = CharacterAffinities.affinities_test_enemy

func on_leave_battle() -> void:
    character_name = default_character_name
    OnLeaveBattle.emit()

func _on_turn_started(character: BattleCharacter) -> void:
    if character == self:
        start_turn()
    elif active:
        active = false

func start_turn() -> void:
    print("========")
    print(character_name + " is starting their turn")
    print("========")
    active = true

    behaviour_state_machine.set_state("ThinkState")


func roll_initiative() -> int:
    var vitality := stats.get_stat(CharacterStatEntry.ECharacterStat.Vitality)
    if vitality < 0:
        vitality = 0

    # make sure to set the initiative value on our character for later reference
    initiative = DiceRoller.roll_flat(20, 1) + ceil(vitality)
    return initiative

func heal(amount: int) -> void:
    print(character_name + " healed for " + str(amount) + " HP")
    current_hp += amount
    var max_hp := stats.get_stat(CharacterStatEntry.ECharacterStat.MaxHP)
    if current_hp > max_hp:
        # We expect HP to be an int
        current_hp = ceil(max_hp)

func take_damage(attacker, damage: int, damage_type: BattleEnums.EAffinityElement = BattleEnums.EAffinityElement.PHYS, dice_status: DiceRoller.DiceStatus = DiceRoller.DiceStatus.ROLL_SUCCESS) -> BattleEnums.ESkillResult:
    if damage <= 0:
        print(character_name + " took no damage")
        return BattleEnums.ESkillResult.SR_FAIL

    var result := BattleEnums.ESkillResult.SR_SUCCESS

    # Use get_or_add to prevent null values breaking this
    var affinity_type := affinities.get_or_add(damage_type, BattleEnums.EAffinityType.UNKNOWN) as BattleEnums.EAffinityType

    if (affinity_type != BattleEnums.EAffinityType.UNKNOWN):
        var enum_string := Util.get_enum_name(BattleEnums.EAffinityElement, damage_type)

        if not AffinityLog.is_affinity_logged(character_internal_name, damage_type):
            print("[AL] " + character_name + " has not logged " + enum_string)
            AffinityLog.log_affinity(character_internal_name, damage_type, affinity_type)
        else:
            print("[AL] " + character_name + " has logged " + enum_string)


        if (affinity_type == BattleEnums.EAffinityType.WEAK
        or dice_status == DiceRoller.DiceStatus.ROLL_CRIT_SUCCESS):
            var crit_multiplier := (attacker as BattleCharacter).stats.get_stat(CharacterStatEntry.ECharacterStat.CritMultiplier)
            print("[CRIT] Original damage: " + str(damage))
            print("[CRIT] Crit multiplier: " + str(crit_multiplier))
            damage = ceil(damage * crit_multiplier)
            result = BattleEnums.ESkillResult.SR_CRITICAL

        elif ((affinity_type == BattleEnums.EAffinityType.RESIST
        or dice_status == DiceRoller.DiceStatus.ROLL_FAIL)
        and damage_type != BattleEnums.EAffinityElement.ALMIGHTY):
            print(character_name + " resists " + enum_string)


            # use defense stat to reduce damage
            var defense := stats.get_stat(CharacterStatEntry.ECharacterStat.Defense)
            print("[RESIST] Defense: " + str(defense))

            damage = ceil(damage * (1.0 - defense));

            print ("[RESIST] Damage reduced to " + str(damage))
            result = BattleEnums.ESkillResult.SR_RESISTED

        elif ((affinity_type == BattleEnums.EAffinityType.IMMUNE
        or dice_status == DiceRoller.DiceStatus.ROLL_CRIT_FAIL)
        and damage_type != BattleEnums.EAffinityElement.ALMIGHTY):
            print(character_name + " is immune to " + enum_string)
            damage = 0
            result = BattleEnums.ESkillResult.SR_IMMUNE

    # only apply attacker strength when the attack was not a crit, resisted, absorbed, or immune
    # (aka normal damage)
    elif attacker != null and attacker is BattleCharacter:
        var attacker_strength := (attacker as BattleCharacter).stats.get_stat(CharacterStatEntry.ECharacterStat.Strength)
        print("[Attack] Original Damage: " + str(damage))
        print((attacker as BattleCharacter).character_name + " has strength: " + str(attacker_strength))
        damage = ceil(damage * attacker_strength)
        print("[Attack] Damage with strength: " + str(damage))
    
    print(character_name + " took " + str(damage) + " damage")
    
    if damage > 0:
        current_hp -= damage
        OnTakeDamage.emit(damage)
        if current_hp <= 0:
            current_hp = 0
            OnDeath.emit()
            print(character_name + " has died")
            battle_state.leave_battle(self)

            # destroy parent object
            get_parent().queue_free()

    return result


func battle_input(_event) -> void: pass