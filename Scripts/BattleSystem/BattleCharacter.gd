extends Node
class_name BattleCharacter

@export var character_type : BattleEnums.ECharacterType = BattleEnums.ECharacterType.PLAYER
@export var default_character_name: String = "Test Enemy"
@onready var character_name := default_character_name
@onready var character_internal_name := get_parent().get_name()

# Key = EAffinityElement, Value = EAffinityType
@export var affinities: Dictionary[BattleEnums.EAffinityElement, BattleEnums.EAffinityType] = {}
@export var basic_attack_element: BattleEnums.EAffinityElement = BattleEnums.EAffinityElement.PHYS

@export var mastery_elements: Array[BattleEnums.EAffinityElement] = [
    BattleEnums.EAffinityElement.FIRE,
]

var _familiar_spells: Array[Item] = []

@export var debug_always_crit: bool = false

# TODO: replace this draw list for every character
@export var draw_list: Array[Item] = [
    load("res://Scripts/Data/Items/Spells//test_fire_spell.tres"),
    load("res://Scripts/Data/Items/Spells//test_healing_spell.tres"),
    load("res://Scripts/Data/Items/Spells//test_almighty_spell.tres")
]
@export var draw_list_from_inventory: bool = true

@onready var battle_state := GameModeStateMachine.get_node("BattleState") as BattleState
@onready var behaviour_state_machine := self.get_node("StateMachine") as StateMachine

@onready var stats := $CharacterStats as CharacterStats
@onready var inventory := get_node_or_null("../Inventory") as Inventory

@onready var current_hp: int = ceil(stats.get_stat(CharacterStatEntry.ECharacterStat.MaxHP))
@onready var current_mp: int = ceil(stats.get_stat(CharacterStatEntry.ECharacterStat.MaxMP))


# The third person player controller extends from the BattleCharacterController to make this possible
@onready var character_controller := get_parent() as BattleCharacterController

@export_group("Experience and levelling")
@export var level: int = 1
var experience_to_next_level: int:
    get:
        return floor(1000 * (level ** 1.5))

var _current_xp_total: int = 0

@export var experience: int:
    get:
        return _current_xp_total
    set(value):
        _current_xp_total = value

        # Level up if the total XP has reached the threshold.
        # Do NOT subtract XP so that the total XP remains cumulative.
        while _current_xp_total >= experience_to_next_level:
            level += 1
            stats.level_up_all_stats()
            Console.print_line("[LEVEL UP] " + character_name + " has leveled up to " + str(level), true)
        Console.print_line(str(experience_to_next_level))
        Console.print_line("[XP] " + character_name + " has " + str(_current_xp_total) + " XP (level " + str(level) + ")", true)
        Console.print_line("[XP] " + character_name + " needs " + str(experience_to_next_level - _current_xp_total) + " XP to level up", true)

signal OnLeaveBattle
signal OnCharacterTurnStarted
signal OnSpendActions(character: BattleCharacter)

var character_active := false
var initiative: int = 0

## How many turns this character should be "down" for (when crit - ONE MORE system)
var down_turns := 0
## How many turns this character has left before moving to the next character in the turn order
var actions_left := 0

## Used for effects like Silence
var can_use_spells := true

func _ready() -> void:

    if not inventory:
        draw_list_from_inventory = false
    if draw_list_from_inventory and inventory:
        # TODO: get from inventory instead of hardcoded
        pass

    print("%s internal name %s" % [character_name, character_internal_name])

    BattleSignalBus.OnTurnStarted.connect(_on_battle_turn_started)

    print(character_name + " CURRENT HP: " + str(current_hp))

    # if the player has a spell, they should know what it is when drawing it
    if inventory:
        inventory.inventory_updated.connect(_on_inventory_updated)

    # # DEBUG: halve enemy HP for testing
    # if character_type == BattleEnums.ECharacterType.ENEMY:
    #     current_hp /= 4


func spend_actions(actions: int) -> void:
    actions_left -= actions
    print(character_name + " has spent " + str(actions) + " actions")
    if actions_left <= 0:
        print(character_name + " has no actions left")
        behaviour_state_machine.set_state("IdleState")
    else:
        print(character_name + " has " + str(actions_left) + " actions left")
    battle_state.ready_next_turn()
    OnSpendActions.emit(self)

func _on_inventory_updated(resource: Item, _count: int, is_new_item: bool) -> void:
    if (is_new_item
    and resource.item_type in [Item.ItemType.BATTLE_ITEM, Item.ItemType.FIELD_ITEM]
    and not is_spell_familiar(resource)):
        add_familiar_spell(resource)

func print_stat(stat_int_string: String) -> void:
    var stat := int(stat_int_string) as CharacterStatEntry.ECharacterStat
    var stat_value := stats.get_stat(stat)
    Console.print_line("Stat %s: %s" % [Util.get_enum_name(CharacterStatEntry.ECharacterStat, stat), str(stat_value)], true)

func print_modifiers() -> void:
    if stats.stat_modifiers.size() == 0:
        Console.print_line("No modifiers active")
    else:
        for modifier in stats.stat_modifiers:
            var enum_name := Util.get_enum_name(CharacterStatEntry.ECharacterStat, modifier.stat)
            var stat_value_string := "x" if modifier.is_multiplier else "+"
            stat_value_string += str(modifier.stat_value)
            Console.print_line(modifier.name + " - " + enum_name + ": " + stat_value_string, true)

func is_spell_familiar(spell: Item) -> bool:
    return _familiar_spells.has(spell)

func is_alive() -> bool:
    return current_hp > 0 

func add_familiar_spell(spell: Item) -> void:
    print("[Familiar] " + character_name + " has learned " + spell.item_name)
    _familiar_spells.append(spell)

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
        await start_turn()
    elif character_active:
        character_active = false
        behaviour_state_machine.set_state("IdleState")

func start_turn() -> void:
    print("========")
    print(character_name + " is starting their turn (%d actions, %d HP)" % [actions_left, current_hp])
    print("========")
    character_active = true
    OnCharacterTurnStarted.emit()

    await stats.active_modifiers_on_turn()

    if down_turns > 0:
        behaviour_state_machine.set_state("DownedState")
    elif actions_left > 0:
        behaviour_state_machine.set_state("ThinkState")
        down_turns = 0

func roll_initiative() -> int:
    var initiative_bonus := ceili(stats.get_stat(CharacterStatEntry.ECharacterStat.Speed))
    if initiative_bonus < 0:
        initiative_bonus = 0

    # make sure to set the initiative value on our character for later reference
    initiative = DiceRoll.roll(20, 1, 1, initiative_bonus).total()
    return initiative

func update_mp(amount: int, spell_status: Item.UseStatus = Item.UseStatus.FAIL) -> void:
    print("[RESTORE MP] %s restored %s MP" % [character_name, str(amount)])

    current_mp += amount
    var max_mp := stats.get_stat(CharacterStatEntry.ECharacterStat.MaxMP)
    if current_mp > max_mp:
        # We expect MP to be an int
        current_mp = ceili(max_mp)
    current_mp = max(current_mp, 0)  # Ensure MP doesn't go below 0

    var skill_result := BattleEnums.ESkillResult.SR_FAIL
    match spell_status:
        Item.UseStatus.SUCCESS:
            skill_result = BattleEnums.ESkillResult.SR_SUCCESS
        Item.UseStatus.CRIT_SUCCESS:
            skill_result = BattleEnums.ESkillResult.SR_CRITICAL
        Item.UseStatus.CRIT_FAIL:
            skill_result = BattleEnums.ESkillResult.SR_FAIL

    var restore_number := DamageNumber.create_damage_number(
        amount, BattleEnums.EAffinityElement.MANA, skill_result,
        self.get_parent(),
        battle_state.top_down_player.camera)
    add_child(restore_number)

func heal(amount: int, from_absorb: bool = false, spell_status: Item.UseStatus = Item.UseStatus.FAIL) -> void:
    var heal_string := "[HEAL] %s healed %d -> %d (%d HP)" % [character_name, current_hp, current_hp + amount, amount]
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
        Item.UseStatus.SUCCESS:
            skill_result = BattleEnums.ESkillResult.SR_SUCCESS
        Item.UseStatus.CRIT_SUCCESS:
            skill_result = BattleEnums.ESkillResult.SR_CRITICAL
        Item.UseStatus.CRIT_FAIL:
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
    actions_left += turns
    print("[ONE MORE] " + character_name + " has been awarded " + str(turns) + " turns")
    BattleSignalBus.OnTurnsAwarded.emit(self, turns)

func get_affinity(element: BattleEnums.EAffinityElement) -> BattleEnums.EAffinityType:
    # Use get_or_add to prevent null values breaking this
    return affinities.get_or_add(element, BattleEnums.EAffinityType.NEUTRAL)

## Takes damage from an attacker and calculates the result based on various parameters.
## 
## [br][param attacker]: The BattleCharacter instance that is attacking.
## [br][param damage_rolls]: An array of DiceRoll instances representing the damage rolls.
## [br][param attack_roll]: A DiceRoll instance representing the attack roll: usually a d20 against Armour Class.
## [br][param damage_type]: The type of damage being inflicted, default is PHYS (physical).
## [br][param reflected]: A boolean indicating if the damage is reflected, default is false.
## [br]returns a [enum BattleEnums.ESkillResult] indicating the result of the skill.
func take_damage(attacker: BattleCharacter, damage_rolls: Array[DiceRoll], attack_roll: DiceRoll, damage_type: BattleEnums.EAffinityElement = BattleEnums.EAffinityElement.PHYS, reflected: bool = false) -> BattleEnums.ESkillResult:
    return take_damage_flat(attacker, DiceRoll.roll_all(damage_rolls), damage_type, reflected, attack_roll.get_status())

## Acts like [method take_damage] but takes a flat damage value instead of a DiceRoll array.
## [br]Unlike [method take_damage], this method takes a [enum DiceRoll.DiceStatus] to determine the result of the skill.
## [br]The status will default to SUCCESS, but is overridden by [method take_damage].
func take_damage_flat(attacker: BattleCharacter, damage: int, damage_type: BattleEnums.EAffinityElement = BattleEnums.EAffinityElement.PHYS, reflected: bool = false, dice_status: DiceRoll.DiceStatus = DiceRoll.DiceStatus.ROLL_SUCCESS) -> BattleEnums.ESkillResult:
    if damage <= 0:
        print(character_name + " took no damage")
        return BattleEnums.ESkillResult.SR_FAIL
    var result := BattleEnums.ESkillResult.SR_SUCCESS

    # Use get_or_add to prevent null values breaking this
    var affinity_type := get_affinity(damage_type)
    var enum_string := Util.get_enum_name(BattleEnums.EAffinityElement, damage_type)
    
    # log affinities first, since the dice roll status can override the affinity type
    if (affinity_type != BattleEnums.EAffinityType.NEUTRAL):
        if (not AffinityLog.is_affinity_logged(character_internal_name, damage_type)
        and dice_status in [DiceRoll.DiceStatus.ROLL_SUCCESS, DiceRoll.DiceStatus.ROLL_CRIT_SUCCESS]):
            
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
    if (affinity_type != BattleEnums.EAffinityType.NEUTRAL):
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
                damage = _calculate_resist_damage(damage, damage_type)
                result = BattleEnums.ESkillResult.SR_RESISTED
            else:
                print(character_name + " reflected " + enum_string)
                # Reflect damage back at attacker (true flag to prevent infinite loops)
                attacker.take_damage_flat(self, damage, damage_type, true)
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
                damage = _calculate_resist_damage(damage, damage_type)
                result = BattleEnums.ESkillResult.SR_RESISTED

        elif (affinity_type == BattleEnums.EAffinityType.IMMUNE
        and damage_type != BattleEnums.EAffinityElement.ALMIGHTY):
            print(character_name + " takes no damage from " + enum_string)
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
        if (dice_status in [DiceRoll.DiceStatus.ROLL_FAIL, DiceRoll.DiceStatus.ROLL_CRIT_FAIL]
        and attacker.basic_attack_element == damage_type):
            damage = 0
            result = BattleEnums.ESkillResult.SR_FAIL

        # COMMENTED OUT: Strength is only added to the attack roll now, not the damage roll

        # else:
        #     var attacker_strength := attacker.stats.get_stat(CharacterStatEntry.ECharacterStat.PhysicalStrength)\
        #             if damage_type == BattleEnums.EAffinityElement.PHYS else\
        #                     attacker.stats.get_stat(CharacterStatEntry.ECharacterStat.MagicalStrength)
            
        #     print("[Attack] Original Damage: " + str(damage))
        #     print(attacker.character_name + " has strength: " + str(attacker_strength))
        #     # UPDATE: strength now adds to damage instead of multiplying (rounded up)
        #     damage = ceil(damage + attacker_strength)
        #     print("[Attack] Damage with strength: " + str(damage))
    
    if damage > 0:
        current_hp -= damage
        if current_hp <= 0:
            _on_death(attacker)
            return BattleEnums.ESkillResult.SR_DEATH

    BattleSignalBus.OnTakeDamage.emit(self, damage)
    BattleSignalBus.OnSkillResult.emit(attacker, self, result, damage)
    var damage_number := DamageNumber.create_damage_number(damage, damage_type, result, self.get_parent(), battle_state.top_down_player.camera)
    add_child(damage_number)
    print("[DAMAGE] %s did %s damage to %s (%s)" % [attacker.character_name, damage, character_name, Util.get_enum_name(BattleEnums.ESkillResult, result)])
    
    return result


func _on_death(attacker: BattleCharacter) -> void:
    current_hp = 0
    BattleSignalBus.OnDeath.emit(self)
    print("[DEATH] " + character_name + " has died!!")

    if character_type != BattleEnums.ECharacterType.PLAYER:
        # Award XP to the player that killed the enemy
        if attacker and attacker.character_type == BattleEnums.ECharacterType.PLAYER:
            # Base XP is 100, multiply by level difference (min 1)
            var xp_multiplier := maxf(1.0, level - attacker.level)
            print("[XP] Level difference: " + str(xp_multiplier))
            var xp_reward := ceili(100 * xp_multiplier)
            attacker.experience += xp_reward
            print("[XP] %s gained %d XP for defeating %s" % [
                attacker.character_name, 
                xp_reward,
                character_name
            ])
        
        # enemies are destroyed when they die
        battle_state.leave_battle(self)
        # destroy parent object
        get_parent().queue_free()
    else:
        # Players are able to be revived once "dead"
        behaviour_state_machine.set_state("DeadState")

func _calculate_crit_damage(attacker: BattleCharacter, damage: int) -> int:
    var crit_multiplier := attacker.stats.get_stat(CharacterStatEntry.ECharacterStat.AttackCritMultiplier)
    var calculated_damage := ceili(damage * crit_multiplier)
    print("[CRIT] %s: %d -> %d (mult: %d)" % [attacker.character_name, damage, calculated_damage, crit_multiplier])
    return calculated_damage
    
func _calculate_resist_damage(initial_damage: int, element: BattleEnums.EAffinityElement) -> int:
    # Use defense stat to reduce damage (flat value)
    var defense := stats.get_stat(CharacterStatEntry.ECharacterStat.PhysicalDefense)\
    if element == BattleEnums.EAffinityElement.PHYS else stats.get_stat(CharacterStatEntry.ECharacterStat.Spirit)
    var calculated_damage := ceili(initial_damage - defense)
    print("[RESIST] Defense: " + str(defense))
    print("[RESIST] Calculated damage: %s (original: %s)" % [str(calculated_damage), initial_damage])
    return calculated_damage
