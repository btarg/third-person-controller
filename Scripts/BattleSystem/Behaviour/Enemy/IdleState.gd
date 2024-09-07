extends State
class_name IdleState

func enter() -> void:
    var root := self.owner
    if root:
        print(root.name + " is idle")
func exit() -> void: pass
func update(_delta: float) -> void: pass
func physics_update(_delta: float) -> void: pass
func input_update(_event: InputEvent) -> void: pass
func unhandled_input_update(_event: InputEvent) -> void: pass