extends Node3D
class_name TopDownPlayerController

@onready var spring_arm := $SpringArm3D
@onready var camera := spring_arm.get_node("TopDownCamera") as Camera3D

@export_group("Rotation")
## How far the camera can rotate up and down in degrees
@export var spring_arm_clamp_degrees: float = 75.0
var spring_arm_clamp := deg_to_rad(spring_arm_clamp_degrees)

@onready var mouse_lock_manager := get_node("/root/MouseLockManager") as MouseLockManager

@export var enabled : bool:
    get:
        return enabled
    set(value):
        enabled = value
        if enabled and camera != null:
            camera.make_current()

func _ready() -> void:
    if enabled:
        camera.make_current()
        print("Hello from TopDownPlayerController")


func unhandled_input_update(event) -> void:
    if enabled:
        if event is InputEventMouseMotion and mouse_lock_manager.mouse_locked:
            rotate_y(-event.relative.x * 0.005)
            spring_arm.rotate_x(-event.relative.y * 0.005)
            spring_arm.rotation.x = clamp(spring_arm.rotation.x, -spring_arm_clamp, spring_arm_clamp)