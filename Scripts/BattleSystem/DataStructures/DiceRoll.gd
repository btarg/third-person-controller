extends Resource
class_name DiceRoll

## Enum for the result of a dice total, in order of increasing success
enum DiceStatus {
    ROLL_CRIT_FAIL,
    ROLL_FAIL,
    ROLL_SUCCESS,
    ROLL_CRIT_SUCCESS,
}

@export_range(4, 100) var die_sides: int = 20
@export_range(1, 10) var num_rolls: int = 1
## If set to 1, the total will never be able to critically fail.
## See [url]https://2e.aonprd.com/Rules.aspx?ID=2284[/url]
@export_range(0, 100) var difficulty_class: int = 0
@export var bonus: int = 0

var _current_status: DiceStatus = DiceStatus.ROLL_SUCCESS
var _total_rolled: int = 0

func _ready() -> void:
    assert(die_sides > 0, "Die sides must be positive")
    assert(num_rolls > 0, "Number of rolls must be positive")
    assert(difficulty_class >= 0, "DC cannot be negative")

## Gets the current total of the dice roll, without rerolling.
func total() -> int:
    return _total_rolled

func flat_total() -> int:
    return _total_rolled - bonus

## Returns the maximum possible total this dice roll could achieve (used for comparing against other rolls).
func max_possible() -> int:
    return (num_rolls * die_sides) + bonus

## Rerolls the total and returns the DiceRoll object.
## This will change the status returned by [method get_status()].
## If you just want to get the status without rerolling, use [method get_status()]
func reroll() -> DiceRoll:
    self._internal_roll()
    return self

## Gets the DiceStatus for DC rolls, defaults to SUCCESS for flat rolls
func get_status() -> DiceStatus:
    return _current_status

## Constructs a new DiceRoll object with the given parameters and rolls the dice.
static func roll(_die_sides: int, _num_rolls: int = 1, _difficulty_class: int = 1, _bonus: int = 0) -> DiceRoll:
    var new_roll := DiceRoll.new()
    new_roll.die_sides = _die_sides
    new_roll.difficulty_class = _difficulty_class
    new_roll.num_rolls = _num_rolls
    new_roll.bonus = _bonus
    new_roll._internal_roll()
    return new_roll

func _to_string() -> String:
    var roll_string := "%sd%s" % [str(num_rolls), str(die_sides)]
    if bonus != 0:
        # if bonus is negative, use a minus sign
        if bonus < 0:
            roll_string += " - %s" % str(abs(bonus))
        else:
            roll_string += " + %s" % str(bonus)
    # DC 1 is a flat total, as it's the lowest possible total
    if difficulty_class > 1:
        roll_string += " vs DC %s" % str(difficulty_class)
    return roll_string


## Rolls the dice against the Difficulty Class (DC) and return the total.
## If the difficulty class is 1 or less, the total will be flat.
## See [url]https://2e.aonprd.com/Rules.aspx?ID=2286[/url] for more info on dice
func _internal_roll() -> void:
    if difficulty_class <= 1:
        _current_status = DiceStatus.ROLL_SUCCESS
        _total_rolled = _roll_flat()
        return


    var total_roll := bonus
    var natural_roll := -1  # Track the result of the first die total (assume only one die is used for determining nat 1/20)

    # Roll all dice and add together
    for i in range(num_rolls):
        var die := randi() % die_sides + 1
        total_roll += die
        # Capture the first total as the natural total,
        # if only one die is rolled
        if i == 0 and num_rolls == 1:
            natural_roll = die

    var status: DiceStatus

    # Determine base degree of success based on total_roll
    if total_roll <= difficulty_class - 10:
        status = DiceStatus.ROLL_CRIT_FAIL
    elif total_roll < difficulty_class:
        status = DiceStatus.ROLL_FAIL
    elif total_roll >= difficulty_class + 10:
        # print("[ROLL] Critical hit: rolled 10 above DC")
        status = DiceStatus.ROLL_CRIT_SUCCESS
    else:
        status = DiceStatus.ROLL_SUCCESS

    # Adjust based on natural total
    # If the DC is 1, the total will never be able to critically fail
    if natural_roll != -1 and difficulty_class > 1:
        # var last_status := status
        if natural_roll == 1:
            # Natural 1 worsens the degree of success by one step
            status = max(status - 1, int(DiceStatus.ROLL_CRIT_FAIL)) as DiceStatus
            # print("[ROLL] Natural 1! adjustment went from " + Util.get_enum_name(DiceStatus, last_status) + " to " + Util.get_enum_name(DiceStatus, status))
        elif natural_roll == die_sides:
            # Natural 20 improves the degree of success by one step
            status = min(status + 1, int(DiceStatus.ROLL_CRIT_SUCCESS)) as DiceStatus
            # print("[ROLL] Natural %s! Adjusted from " % str(die_sides) + Util.get_enum_name(DiceStatus, last_status) + " to " + Util.get_enum_name(DiceStatus, status))
    
    _current_status = status
    _total_rolled = total_roll

func _roll_flat() -> int:
    var total_roll := bonus
    for i in range(num_rolls):
        var die := randi() % die_sides + 1
        total_roll += die
    _current_status = DiceStatus.ROLL_SUCCESS
    return total_roll

## Returns a string description of the dice total, e.g. "2d6 + 1d8"
static func get_dice_array_as_string(array: Array[DiceRoll]) -> String:
    var result := ""
    for i in range(array.size()):
        result += array[i].to_string()
        if i < array.size() - 1:
            result += " + "
    return result

static func roll_all(array: Array[DiceRoll], reroll_all: bool = true) -> int:
    var return_total := 0
    for i in range(array.size()):
        return_total += array[i].total() if not reroll_all else array[i].reroll().total()
    return return_total
