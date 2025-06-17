class_name ActionData extends RefCounted


var name: String
var weight_calculator: Callable
var executor: Callable
var can_execute_checker: Callable
var current_weight: float = 0.0
var aggression_change: float = 0.0

func _init(
    action_name: String, 
    weight_calc: Callable,
    exec_func: Callable, 
    can_exec_func: Callable,
    aggression_change_value: float = 0.0
):
    name = action_name
    weight_calculator = weight_calc
    executor = exec_func
    can_execute_checker = can_exec_func
    aggression_change = aggression_change_value

func calculate_weight(context) -> float:
    current_weight = weight_calculator.call(context) if weight_calculator.is_valid() else 0.0
    return current_weight

func can_execute(context) -> bool:
    return can_execute_checker.call(context) if can_execute_checker.is_valid() else true

func execute() -> void:
    if executor.is_valid():
        executor.call()
    else:
        print("Invalid executor for action: ", name)