class_name Item
extends Resource

enum ItemType {
    BATTLE_ITEM, ## Used on another character directly, in battle
    FIELD_ITEM, ## Used on a position in the world, area shape determined by area_type
    
    # Other items which are not used on a character or area in battle
    WEAPON,
    ARMOR,
    CONSUMABLE_MODIFIER, ## e.g. buff or debuff items, for use out of battle
    QUEST,
    MISC
}
enum TargetType {
    NONE, ## This is a battle spell
    AOE_FROM_PLAYER,  ## Aim the AOE from the caster (circles are simply fixed)
    AOE_FROM_TARGET,  ## Aim the AOE from any target's position
    AOE_FREE_SELECT,   ## Aim the AOE from the mouse cursor position (e.g. place a circle somewhere)
}

enum UseStatus {
    FAIL,
    SUCCESS,
    CRIT_FAIL,
    CRIT_SUCCESS,
    CANNOT_USE,
    ALREADY_EQUIPPED
}

@export_group("Inventory")

## item_type should be BATTLE_SPELL or FIELD_SPELL for spell items
@export var item_type: ItemType = ItemType.WEAPON

var item_id := "default_item_id"

@export var item_name: String = "???"
@export var item_description: String = "Test Description"
## If this item has no count, it can be used infinitely (e.g. skills)
@export var has_count := true
@export var max_stack: int = 999

@export_group("Cost")
## TODO: The action cost is only referenced in other classes and not used here.
@export var actions_cost: int = 1
@export var mp_cost: int = 0


## AOE targeting for spells and items
@export_group("Item Targeting")
@export var target_type := TargetType.NONE
@export var area_type := AreaUtils.SpellAreaType.CIRCLE

## How far away a target can be to activate this item (does not apply to self)
@export var effective_range: int = 5

@export var can_use_on_enemies: bool = true
@export var can_use_on_allies: bool = true
@export var only_on_dead_characters: bool = false ## Primarily for revive items

@export_group("AOE Spells")
## Radius also acts as the length for line and cone area types
@export var area_of_effect_radius: float = 0.0
## only applies to line area type
@export var line_width: float = 0.0
## only applies to cone area type
@export var cone_angle_degrees: float = 60.0

## Time to live for AOEs in turns: -1 means sustained spell, 0 means we do the effect once and then remove the spell
@export var ttl_turns: int = -1

@export_group("Spell")
@export var spell_element := BattleEnums.EAffinityElement.FIRE
## The set modifier only applies if the affinity is a buff or debuff
@export var modifier: StatModifier

@export_group("Dice Roll Settings")
## The dice roll used to determine the item's power when used on a target. (This is not the attack roll!)
var _default_spell_power_rolls: Array[DiceRoll] = [DiceRoll.roll(8)]
@export var spell_power_rolls: Array[DiceRoll] = []:
    get:
        return spell_power_rolls if spell_power_rolls.size() > 0 \
        else _default_spell_power_rolls
    set(value):
        spell_power_rolls = value

## Override the spell's use roll (not the damage roll). Set to null to use a d20 vs the target's AC.
@export var use_roll: DiceRoll

var _roll_cache: Dictionary[BattleCharacter, DiceRoll] = {}
const DEFAULT_ROLL_DC: int = 10 # default DC for spell use rolls when the character is invalid

@export_group("Junction system")
## Dictionary with a character stat entry as key and a float as value
@export var junction_table: Dictionary[CharacterStatEntry.ECharacterStat, float] = {
    CharacterStatEntry.ECharacterStat.PhysicalStrength: 1,
    CharacterStatEntry.ECharacterStat.PhysicalDefense: 1,
}


# Preload audio types
var heal_sound := preload("res://Assets/Sounds/heal.wav") as AudioStream
var mana_sound := preload("res://Assets/Sounds/mana.wav") as AudioStream


func _init(_item_name: String = "", _max_stack: int = 999) -> void:
    self.item_name = _item_name
    self.max_stack = _max_stack

func get_spell_use_roll(caster: BattleCharacter, target: BattleCharacter) -> DiceRoll:
    if use_roll:
        return use_roll
    if spell_element == BattleEnums.EAffinityElement.ALMIGHTY:
        return DiceRoll.roll(20, 1, 0) # DC 0: always hits
    
    if not target:
        return DiceRoll.roll(20, 1, DEFAULT_ROLL_DC,
        ceil(caster.stats.get_stat(CharacterStatEntry.ECharacterStat.MagicalStrength)))

    return _roll_cache.get_or_add(target,
    DiceRoll.roll(20, 1, ceil(target.stats.get_stat(CharacterStatEntry.ECharacterStat.ArmourClass)),
    ceil(caster.stats.get_stat(CharacterStatEntry.ECharacterStat.MagicalStrength)))) # NEW: add magical strength to the roll

## This is to be overloaded by child classes
func get_item_description() -> String:
    # For spells, use spell-specific description
    if item_type in [ItemType.BATTLE_ITEM, ItemType.FIELD_ITEM]:
        var description_parts: Array[String] = []

        # Damage/healing effects
        if spell_element == BattleEnums.EAffinityElement.HEAL:
            description_parts.append("Restores %s HP" % [DiceRoll.get_dice_array_as_string(spell_power_rolls)])
        elif spell_element == BattleEnums.EAffinityElement.MANA:
            description_parts.append("Restores %s MP" % [DiceRoll.get_dice_array_as_string(spell_power_rolls)])
        elif spell_element not in [BattleEnums.EAffinityElement.BUFF, BattleEnums.EAffinityElement.DEBUFF]:
            description_parts.append("Deals %s %s damage" % [DiceRoll.get_dice_array_as_string(spell_power_rolls), Util.get_enum_name(BattleEnums.EAffinityElement, spell_element)])

        # Modifier effects
        if modifier:
            description_parts.append("Applies " + modifier.name)

        var description_string := ""
        if description_parts.size() > 1:
            description_string = " and ".join(description_parts) + " "
        elif description_parts.size() == 1:
            description_string = description_parts[0] + " "

        # Target specification
        if can_use_on_enemies and can_use_on_allies:
            if item_type == ItemType.FIELD_ITEM and area_of_effect_radius > 0:
                description_string += "to all targets"
            else:
                description_string += "to any target"
        elif can_use_on_enemies:
            description_string += "to an enemy"
        elif can_use_on_allies:
            description_string += "to an ally"

        # Range specification
        if area_of_effect_radius > 0 and item_type == ItemType.FIELD_ITEM:
            description_string += " within %s units" % [str(int(area_of_effect_radius))]
        else:
            description_string += " at any range"

        # Modifier duration
        if modifier:
            if modifier.turn_duration == -1:
                description_string += ":\n%s indefinitely" % [modifier.description]
            else:
                description_string += ":\n%s for %s turns" % [modifier.description, str(modifier.turn_duration)]
        description_string += "."

        return description_string
    
    # For non-spells, use the basic description
    return item_description

func get_icon_path() -> String:
    # For spells, use element-based icons
    if item_type in [ItemType.BATTLE_ITEM, ItemType.FIELD_ITEM]:
        var element_icon_path := "res://Assets/GUI/Icons/Items/elements/"
        element_icon_path += Util.get_enum_name(BattleEnums.EAffinityElement, spell_element).to_lower()
        return element_icon_path + "_element.png"
    
    # For non-spells, use item type-based icons
    var icon_path := "res://Assets/GUI/Icons/Items/item_"
    icon_path += Util.get_enum_name(Item.ItemType, item_type).to_lower()
    return icon_path + ".png"

func get_rich_name(icon_size: int = 64) -> String:
    var icon_path = get_icon_path()
    return "[hint=%s][img=%s]%s[/img]%s[/hint]" % [get_item_description(), icon_size, icon_path, item_name]

func get_use_sound(_status: UseStatus = UseStatus.SUCCESS) -> AudioStream:
    if (item_type in [ItemType.BATTLE_ITEM, ItemType.FIELD_ITEM]
    and spell_element == BattleEnums.EAffinityElement.HEAL):
            return heal_sound
    return null
    

func check_cost(user: BattleCharacter) -> bool:
    if user == null:
        return false

    if user.actions_left < actions_cost:
        print("%s does not have enough actions left to activate %s" % [user.character_name, item_name])
        return false

    if user.current_mp < mp_cost:
        print("%s does not have enough MP to activate %s" % [user.character_name, item_name])
        return false

    return true

func can_use_on(user: BattleCharacter, target: BattleCharacter, ignore_costs: bool = false) -> bool:
    if not user:
        return false
    if target == null and item_type != ItemType.FIELD_ITEM:
        return false

    if not check_cost(user) and not ignore_costs:
        return false
    
    # we can only activate this on ourselves 
    if (user == target
    and not can_use_on_allies
    and not can_use_on_enemies):
        return true
    
    var same_side := (user.character_type in [BattleEnums.ECharacterType.FRIENDLY, BattleEnums.ECharacterType.PLAYER]) == \
                    (target.character_type in [BattleEnums.ECharacterType.FRIENDLY, BattleEnums.ECharacterType.PLAYER])

    # Revive items can only be used on dead allies
    if only_on_dead_characters:
        return can_use_on_allies and same_side and not target.is_alive()

    return can_use_on_allies if same_side else can_use_on_enemies

func _update_inventory(inv_to_update: Inventory) -> void:
    if inv_to_update and has_count:
        inv_to_update.item_used_callback(self)
    else:
        printerr("No inventory set or item has infinite uses, not updating inventory for %s" % item_name)
    

## MAIN ACTIVATION FUNCTION
## Executes the spell/item's effect. Called when the item "connects" with a target.
func activate(user: BattleCharacter, target: BattleCharacter, update_inventory: bool = true, use_actions: bool = true) -> UseStatus:
    var status: UseStatus

    if mp_cost > 0:
        if user.current_mp < mp_cost:
            print("%s does not have enough MP to activate %s" % [user.character_name, item_name])
            return UseStatus.CANNOT_USE
        user.update_mp(-mp_cost, UseStatus.FAIL)

    if actions_cost > 0 and use_actions:
        if user.actions_left < actions_cost:
            print("%s does not have enough actions left to activate %s" % [user.character_name, item_name])
            return UseStatus.CANNOT_USE
        user.spend_actions(actions_cost)

    # Handle spells
    if item_type in [ItemType.BATTLE_ITEM, ItemType.FIELD_ITEM]:
        print("[SPELL] %s used %s on %s" % [user.character_name, item_name, target.character_name])
        
        var spell_use_status := UseStatus.FAIL
        var dice_status := DiceRoll.DiceStatus.ROLL_SUCCESS

        # Almighty damage never misses, but other attacks roll to hit
        if spell_element != BattleEnums.EAffinityElement.ALMIGHTY:
            
            var spell_use_roll := get_spell_use_roll(user, target).reroll()
            print("[SPELL] Rolling %s for %s total" % [spell_use_roll.to_string(), str(spell_use_roll.total())])
            dice_status = spell_use_roll.get_status()
            print("[SPELL] Roll status: %s" % [Util.get_enum_name(DiceRoll.DiceStatus, dice_status)])

            match dice_status:
                DiceRoll.DiceStatus.ROLL_SUCCESS:
                    spell_use_status = UseStatus.SUCCESS
                DiceRoll.DiceStatus.ROLL_CRIT_SUCCESS:
                    spell_use_status = UseStatus.CRIT_SUCCESS
                DiceRoll.DiceStatus.ROLL_FAIL:
                    spell_use_status = UseStatus.FAIL
                DiceRoll.DiceStatus.ROLL_CRIT_FAIL:
                    spell_use_status = UseStatus.CRIT_FAIL

        
        if target.get_affinity(spell_element) != BattleEnums.EAffinityType.IMMUNE:
            match spell_element:
                BattleEnums.EAffinityElement.HEAL:
                    target.heal(DiceRoll.roll_all(spell_power_rolls), false, spell_use_status)
                    status = spell_use_status
                BattleEnums.EAffinityElement.MANA:
                    target.update_mp(DiceRoll.roll_all(spell_power_rolls), spell_use_status)
                    status = spell_use_status
                    
                # we only apply buffs and debuffs if we are not immune to those.
                # some enemies can be immune to debuffs, and allies could potentially be given immunity to buffs by an enemy
                BattleEnums.EAffinityElement.BUFF,\
                BattleEnums.EAffinityElement.DEBUFF:
                    if modifier and spell_use_status in [UseStatus.SUCCESS, UseStatus.CRIT_SUCCESS]:
                        target.stats.add_modifier(modifier)
                        print("[SPELL] %s applied %s to %s" % [user.character_name, modifier, target.character_name])
                    else:
                        print("[SPELL] No modifier set for %s" % [Util.get_enum_name(BattleEnums.EAffinityElement, spell_element)])

                # other spell affinities deal damage
                # take_damage() doesn't take a spell result, because we use it for basic attacks too
                # FIX: this is now under the default case so we always update inventory instead of returning early
                _:
                    var magic_strength := ceili(user.stats.get_stat(CharacterStatEntry.ECharacterStat.MagicalStrength))

                    var attack_roll := DiceRoll.roll(20, 1, ceil(target.stats.get_stat(CharacterStatEntry.ECharacterStat.ArmourClass)), magic_strength)
                    # TODO: attacks do damage based on a separate spawned node, like a projectile
                    # TODO: calculate damage more randomly
                    target.take_damage(user, spell_power_rolls, attack_roll, spell_element)
                    
                    # reset cached roll so we can roll again
                    _roll_cache.clear()
                    
                    status = spell_use_status


    else:
        print("Item cannot be consumed: %s" % item_name)
        status = UseStatus.CANNOT_USE

    if update_inventory:
        _update_inventory(user.inventory)
    else:
        print("Not updating inventory for %s" % item_name)

    return status
