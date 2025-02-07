extends State
class_name BattleLostState

func wait(seconds: float) -> void:
    await get_tree().create_timer(seconds).timeout

func enter() -> void:
    print(">>> LOST THE BATTLE")
    await wait(1.5)
    Transitioned.emit(self, "ExplorationState")

func exit() -> void: pass
func _state_process(_delta: float) -> void: pass
func _state_physics_process(_delta: float) -> void: pass
func _state_input(_event: InputEvent) -> void: pass
func _state_unhandled_input(_event: InputEvent) -> void: pass