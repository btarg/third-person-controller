extends Label

# func _ready() -> void:
# 	Engine.max_fps = 30

func _process(_delta: float) -> void:
	text = str(Engine.get_frames_per_second()) + " FPS\n"
