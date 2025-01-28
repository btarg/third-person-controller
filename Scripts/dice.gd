class_name DiceRoller

## Enum for the result of a dice roll, in order of increasing success
enum DiceStatus {
    ROLL_CRIT_FAIL,
    ROLL_FAIL,
    ROLL_SUCCESS,
    ROLL_CRIT_SUCCESS,
}

## Returns the sum of all dice rolls plus a bonus as int
static func roll_flat(die_sides: int, num_rolls: int = 1, bonus: int = 0) -> int:
    var total_roll := bonus
    for i in range(num_rolls):
        var die := randi() % die_sides + 1
        total_roll += die
    return total_roll

## Returns a dictionary with the following keys:
## - `total_roll`: The total sum of all dice rolls
## - `crits`: The number of crits rolled
## - `status`: The result of the roll as DiceRoller.DiceStatus
## See [url]https://2e.aonprd.com/Rules.aspx?ID=2286[/url] for more info on dice
static func roll_dc(die_sides: int, difficulty_class: int, num_rolls: int = 1, bonus: int = 0) -> Dictionary:
    var total_roll := bonus
    var crits := 0
    var natural_roll := -1  # Track the result of the first die roll (assume only one die is used for determining nat 1/20)

    # Roll all dice and add together
    for i in range(num_rolls):
        var die := randi() % die_sides + 1
        total_roll += die
        # Capture the first roll as the natural roll,
        # if only one die is rolled
        if i == 0 and num_rolls == 1:
            natural_roll = die
        if die == die_sides:
            crits += 1
        print("[ROLL] Roll no." + str(i + 1) + ": " + str(die))

    print("[ROLL] Roll total: " + str(total_roll) + " Bonus: " + str(bonus))

    var status: DiceStatus

    # Determine base degree of success based on total_roll
    if total_roll <= difficulty_class - 10:
        status = DiceStatus.ROLL_CRIT_FAIL
    elif total_roll < difficulty_class:
        status = DiceStatus.ROLL_FAIL
    elif total_roll >= difficulty_class + 10:
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
            print("[ROLL] Natural 20! adjustment went from " + Util.get_enum_name(DiceStatus, last_status) + " to " + Util.get_enum_name(DiceStatus, status))

    return { "total_roll": total_roll, "crits": crits, "status": status }