extends Resource
class_name DiceRoll

## Enum for the result of a dice roll, in order of increasing success
enum DiceStatus {
    ROLL_CRIT_FAIL,
    ROLL_FAIL,
    ROLL_SUCCESS,
    ROLL_CRIT_SUCCESS,
}

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
        roll_string += " vs DC %s" % str(difficulty_class)
    return roll_string

## Rolls the dice against a Difficulty Class (DC) and return a status object.
## Returns a dictionary with the following keys:
## - `total_roll`: The total sum of all dice rolls
## - `dc`: The Difficulty Class used for the roll
## - `status`: The result of the roll as DiceRoll.DiceStatus
## See [url]https://2e.aonprd.com/Rules.aspx?ID=2286[/url] for more info on dice
func roll_dc() -> Dictionary:
    var total_roll := bonus
    var natural_roll := -1  # Track the result of the first die roll (assume only one die is used for determining nat 1/20)

    # Roll all dice and add together
    for i in range(num_rolls):
        var die := randi() % die_sides + 1
        total_roll += die
        # Capture the first roll as the natural roll,
        # if only one die is rolled
        if i == 0 and num_rolls == 1:
            natural_roll = die
        print("[ROLL] Roll no." + str(i + 1) + ": " + str(die))

    print("[ROLL] Roll total: " + str(total_roll) + " Bonus: " + str(bonus))

    var status: DiceStatus

    # Determine base degree of success based on total_roll
    if total_roll <= difficulty_class - 10:
        status = DiceStatus.ROLL_CRIT_FAIL
    elif total_roll < difficulty_class:
        status = DiceStatus.ROLL_FAIL
    elif total_roll >= difficulty_class + 10:
        print("[ROLL] Critical hit: rolled 10 above DC")
        status = DiceStatus.ROLL_CRIT_SUCCESS
    else:
        status = DiceStatus.ROLL_SUCCESS

    # Adjust based on natural roll
    # If the DC is 1, the roll will never be able to critically fail
    if natural_roll != -1 and difficulty_class > 1:
        var last_status := status
        if natural_roll == 1:
            # Natural 1 worsens the degree of success by one step
            status = max(status - 1, int(DiceStatus.ROLL_CRIT_FAIL)) as DiceStatus
            print("[ROLL] Natural 1! adjustment went from " + Util.get_enum_name(DiceStatus, last_status) + " to " + Util.get_enum_name(DiceStatus, status))
        elif natural_roll == die_sides:
            # Natural 20 improves the degree of success by one step
            status = min(status + 1, int(DiceStatus.ROLL_CRIT_SUCCESS)) as DiceStatus
            print("[ROLL] Natural %s! Adjusted from " % str(die_sides) + Util.get_enum_name(DiceStatus, last_status) + " to " + Util.get_enum_name(DiceStatus, status))

    return { "total_roll": total_roll, "dc": difficulty_class, "status": status }

## Rolls the dice without a Difficulty Class (DC) and returns the total sum as an int.
func roll_flat() -> int:
    var total_roll := bonus
    for i in range(num_rolls):
        var die := randi() % die_sides + 1
        total_roll += die
    return total_roll

## Returns a string description of the dice roll, e.g. "2d6 + 1d8"
static func get_dice_array_as_string(array: Array[DiceRoll]) -> String:
    var result := ""
    for i in range(array.size()):
        result += array[i].to_string()
        if i < array.size() - 1:
            result += " + "
    return result

static func roll_all_dc(dice: Array[DiceRoll]) -> Array[Dictionary]:
    var results: Array[Dictionary] = []
    for die in dice:
        results.append(die.roll_dc())
    return results

static func roll_all_flat(dice: Array[DiceRoll]) -> int:
    var result := 0
    for die in dice:
        result += die.roll_flat()
    return result


