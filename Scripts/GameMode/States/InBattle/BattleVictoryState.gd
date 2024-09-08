extends State
class_name BattleVictoryState

func wait(seconds: float) -> void:
    await get_tree().create_timer(seconds).timeout

func enter() -> void:
    print(">>> WON THE BATTLE")
    await wait(1.5)
    Transitioned.emit(self, "ExplorationState")

func exit() -> void: pass
func update(_delta: float) -> void: pass
func physics_update(_delta: float) -> void: pass
func input_update(_event: InputEvent) -> void: pass
func unhandled_input_update(_event: InputEvent) -> void: pass