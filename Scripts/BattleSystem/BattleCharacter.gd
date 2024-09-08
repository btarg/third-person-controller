extends Node
class_name BattleCharacter

@export var character_type : BattleEnums.CharacterType = BattleEnums.CharacterType.PLAYER
@export var default_character_name: String = "Test Enemy"
@onready var character_name : String = default_character_name:
    get:
        return character_name
    set(value):
        character_name = value
        get_parent().name = character_name

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
    battle_state.TurnStarted.connect(_on_turn_started)
    print(character_name + " CURRENT HP: " + str(current_hp))

    # TODO: set affinities in editor once typed dictionaries are supported in Godot 4.4
    affinities = {
        # BattleEnums.EAffinityElement.PHYS : BattleEnums.EAffinityType.WEAK,
        BattleEnums.EAffinityElement.FIRE : BattleEnums.EAffinityType.RESIST
    }

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

func take_damage(attacker: BattleCharacter, damage: int, damage_type: BattleEnums.EAffinityElement = BattleEnums.EAffinityElement.PHYS, dice_status: DiceRoller.DiceStatus = DiceRoller.DiceStatus.ROLL_SUCCESS) -> BattleEnums.ESkillResult:
    var result := BattleEnums.ESkillResult.SR_SUCCESS

    if damage <= 0:
        print(character_name + " took no damage")
        return result

    var attacker_strength := attacker.stats.get_stat(CharacterStatEntry.ECharacterStat.Strength)
    damage = ceil(damage * attacker_strength)

    if affinities.has(damage_type) and damage_type != BattleEnums.EAffinityElement.ALMIGHTY:
        var affinity_type := affinities[damage_type] as BattleEnums.EAffinityType
        var enum_string := Util.get_enum_name(BattleEnums.EAffinityElement, damage_type)

        if (affinity_type == BattleEnums.EAffinityType.WEAK
        or dice_status == DiceRoller.DiceStatus.ROLL_CRIT_SUCCESS):
            # TODO: add to affinity log 
            print(character_name + " is weak to " + enum_string)

            var crit_multiplier := attacker.stats.get_stat(CharacterStatEntry.ECharacterStat.CritMultiplier)
            print("[CRIT] Original damage: " + str(damage))
            print("[CRIT] Crit multiplier: " + str(crit_multiplier))
            damage = ceil(damage * crit_multiplier)
            result = BattleEnums.ESkillResult.SR_CRITICAL

        elif (affinity_type == BattleEnums.EAffinityType.RESIST
        or dice_status == DiceRoller.DiceStatus.ROLL_FAIL):
            print(character_name + " resists " + enum_string)
            
            # use defense stat to reduce damage
            var defense := stats.get_stat(CharacterStatEntry.ECharacterStat.Defense)
            damage = ceil(damage * (1.0 - defense));

            result = BattleEnums.ESkillResult.SR_RESISTED

        elif (affinity_type == BattleEnums.EAffinityType.IMMUNE
        or dice_status == DiceRoller.DiceStatus.ROLL_CRIT_FAIL):
            print(character_name + " is immune to " + enum_string)
            damage = 0
            result = BattleEnums.ESkillResult.SR_IMMUNE
    
    print(character_name + " took " + str(damage) + " damage")
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