class_name AggressionSystem extends RefCounted

# Simple aggression value that can be manually adjusted
var aggression: float = 1.0

# Maximum and minimum bounds
var max_aggression: float = 3.0
var min_aggression: float = 0.2

# Track player kills for display purposes
var player_kill_count: int = 0

signal aggression_changed(new_level: float)

func _init(initial_aggression: float = 1.0) -> void:
    aggression = initial_aggression

func update(_delta: float) -> void:
    # Simple system - no automatic updates needed
    pass

func take_damage(amount: float) -> void:
    # Increase aggression when taking damage
    aggression += amount * 0.01  # 1% aggression boost per damage point
    aggression = clamp(aggression, min_aggression, max_aggression)
    
    print("Enemy took ", amount, " damage. Aggression now: ", aggression)

func witness_player_kill() -> void:
    # Increase aggression when seeing player kill allies
    player_kill_count += 1
    aggression += 0.5  # 50% aggression boost per witnessed kill
    aggression = clamp(aggression, min_aggression, max_aggression)
    
    print("Enemy witnessed player kill. Kill count: ", player_kill_count, " Aggression now: ", aggression)

func change_aggression(amount: float) -> void:
    if amount != 0.0:
        aggression += amount
        aggression = clamp(aggression, min_aggression, max_aggression)
        print("Aggression changed by ", amount, ". New level: ", aggression)


func get_aggression_multiplier() -> float:
    return aggression

func get_aggression_level_description() -> String:
    var aggression_value := get_aggression_multiplier()
    
    if aggression_value < 0.5:
        return "Timid"
    elif aggression_value < 0.8:
        return "Cautious"
    elif aggression_value < 1.2:
        return "Neutral"
    elif aggression_value < 1.8:
        return "Aggressive"
    elif aggression_value < 2.5:
        return "Enraged"
    else:
        return "Berserk"

func reset() -> void:
    aggression = 1.0
    player_kill_count = 0