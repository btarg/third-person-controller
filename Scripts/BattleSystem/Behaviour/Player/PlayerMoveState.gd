extends State
class_name PlayerMoveState

@onready var battle_state := get_node("/root/GameModeStateMachine/BattleState") as BattleState

func enter() -> void:
    print("[MOVE] Entered move state!!!!!")

func _end_targeting() -> void:
    if active:
        Transitioned.emit(self, "IdleState")
        battle_state.ready_next_turn()
func _back_to_think() -> void:
    if active:
        Transitioned.emit(self, "ThinkState")

func exit() -> void: pass
func update(_delta: float) -> void: pass
func physics_update(_delta: float) -> void: pass
func input_update(event: InputEvent) -> void:
    if event.is_action_pressed("ui_cancel"):
        _back_to_think()
    elif event.is_action_pressed("combat_attack"):
        print("[MOVE] confirmed!")
        _end_targeting()

func unhandled_input_update(_event: InputEvent) -> void: pass