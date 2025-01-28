extends Resource
class_name DiceRoll

@export_range(4, 100) var die_sides: int = 20
@export_range(1, 10) var num_rolls: int = 1
## If set to 1, the roll will never be able to critically fail.
## See [url]https://2e.aonprd.com/Rules.aspx?ID=2284[/url]
@export_range(1, 100) var difficulty_class: int = 0
@export var bonus: int = 0

static func create(new_die_sides: int, new_num_rolls: int = 1, new_difficulty_class: int = 1, new_bonus: int = 0) -> DiceRoll:
    var new_roll := DiceRoll.new()
    new_roll.die_sides = new_die_sides
    new_roll.difficulty_class = new_difficulty_class
    new_roll.num_rolls = new_num_rolls
    new_roll.bonus = new_bonus
    return new_roll

func _to_string() -> String:
    var roll_string := "%sd%s" % [str(num_rolls), str(die_sides)]
    if bonus != 0:
        # if bonus is negative, use a minus sign
        if bonus < 0:
            roll_string += " - %s" % str(abs(bonus))
        else:
            roll_string += " + %s" % str(bonus)
    # DC 1 is a flat roll, as it's the lowest possible roll
    if difficulty_class > 1:
        roll_string += " vs Difficulty Class: %s" % str(difficulty_class)
    return roll_string

func roll_dc() -> Dictionary:
    return DiceRoller.roll_dc(die_sides, difficulty_class, num_rolls, bonus)

func roll_flat() -> int:
    return DiceRoller.roll_flat(die_sides, num_rolls, bonus)
