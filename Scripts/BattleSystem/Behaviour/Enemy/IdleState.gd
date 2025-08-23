extends State
class_name IdleState

const DEBUG_PRINT: bool = false

func enter() -> void:

    if not DEBUG_PRINT:
        return

    var root := self.owner
    if root:
        print(root.name + " is idle")

func exit() -> void: pass
func _state_process(_delta: float) -> void: pass
func _state_physics_process(_delta: float) -> void: pass
func _state_input(_event: InputEvent) -> void: pass
func _state_unhandled_input(_event: InputEvent) -> void: pass