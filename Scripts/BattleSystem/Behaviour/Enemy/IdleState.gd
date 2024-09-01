extends State
class_name IdleState

func go_to_think_state() -> void:
    if active:
        print("Going to think...")
        Transitioned.emit(self, "ThinkState")

func enter() -> void: pass
func exit() -> void: pass
func update(_delta: float) -> void: pass
func physics_update(_delta: float) -> void: pass
func input_update(_event: InputEvent) -> void: pass
func unhandled_input_update(_event: InputEvent) -> void: pass