@tool
extends EditorPlugin

func _enter_tree():
	# Initialization of the plugin goes here.
	add_custom_type("LineRenderer3D", "MeshInstance3D", preload("line_renderer.gd"), preload("line_render_icon.svg"))


func _exit_tree():
	# Clean-up of the plugin goes here.
	remove_custom_type("Line Renderer 3D")
