class_name SpellArea extends MeshInstance3D

const ENABLE_DEBUG_PRINT := false

# TODO: prevent Z-fighting with other spell areas
@export var radius_visual_shader := preload("res://Assets/Shaders/spell_area_visual.gdshader") as Shader
@export var ground_layer: int = 1  # Layer mask for ground collision
@export var target_group_name: StringName = &"BattleCharacter"  # Group name for target nodes

var area_type := AreaUtils.SpellAreaType.CIRCLE

var radius: float = 5.0
var cone_angle_degrees: float = 60.0
var target_position: Vector3 = Vector3.ZERO

# Line indicator width (length uses radius)
var line_width: float = 2.0

# Direction for cone and line indicators
var aim_direction: Vector3 = Vector3.FORWARD

# Used for tracking changes in selection
var last_selected_nodes: Array[Node3D] = []

var min_height: float = INF  # Minimum height for node selection
var max_height: float = INF  # Maximum height for node selection

var caster: BattleCharacter = null

func _init(p_caster: BattleCharacter, p_area_type: AreaUtils.SpellAreaType, p_radius: float, p_cone_angle_degrees: float = 60.0, p_line_width: float = 2.0, p_aim_direction: Vector3 = Vector3.FORWARD) -> void:
    self.caster = p_caster
    self.area_type = p_area_type
    self.radius = p_radius
    self.cone_angle_degrees = p_cone_angle_degrees
    self.line_width = p_line_width
    self.aim_direction = p_aim_direction.normalized()
    

func _ready() -> void:
    visible = false
    
    mesh = PlaneMesh.new()
    mesh.material = ShaderMaterial.new()
    mesh.material.shader = radius_visual_shader

    update_shader_params()
    set_ring_properties()


func get_nodes_in_area() -> Array[Node3D]:
    var nodes_in_area: Array[Node3D] = []
    var all_battle_characters := get_tree().get_nodes_in_group(target_group_name)
    
    # Get the parent nodes of BattleCharacter components
    for battle_char in all_battle_characters:
        if battle_char is BattleCharacter:
            var parent_node := battle_char.get_parent()
            if parent_node is Node3D and parent_node != self:
                if is_node_in_area(parent_node):
                    nodes_in_area.append(parent_node)
    
    if ENABLE_DEBUG_PRINT:
        print("Total nodes in spell area: ", nodes_in_area.size())
    
    return nodes_in_area

func is_node_in_area(node: Node3D) -> bool:
    var area_center := global_position
    var node_pos := node.global_position
    
    # Check height restrictions first
    if min_height != INF and max_height != INF:
        var relative_height := node_pos.y - area_center.y
        if relative_height < min_height or relative_height > max_height:
            print("  -> Node at height ", relative_height, " is outside height range [", min_height, ", ", max_height, "]")
            return false
    
    match area_type:
        AreaUtils.SpellAreaType.CIRCLE:
            return AreaUtils.is_point_in_circle(node_pos, area_center, radius)
        AreaUtils.SpellAreaType.CONE:
            return AreaUtils.is_point_in_cone(node_pos, area_center, radius, cone_angle_degrees, aim_direction)
        AreaUtils.SpellAreaType.LINE:
            return AreaUtils.is_point_in_line(node_pos, area_center, radius, line_width, aim_direction)
        _:
            return false

func update_shader_params() -> void:
    if not mesh or not mesh.material:
        print("Mesh or material not set, cannot update shader parameters")
        return

    mesh.set("size", Vector2(radius * 2.0, radius * 2.0))

    var material := mesh.material as ShaderMaterial
    material.set_shader_parameter("area_type", area_type)
    material.set_shader_parameter("radius", radius)
    material.set_shader_parameter("cone_angle_rad", deg_to_rad(cone_angle_degrees))
    material.set_shader_parameter("line_length", radius)  # Use radius as line length
    material.set_shader_parameter("line_width", line_width)
    material.set_shader_parameter("aim_direction", aim_direction)


func set_ring_properties(thickness: float = 0.95, speed: float = 1.0) -> void:
    if not mesh or not mesh.material:
        return
    
    var material := mesh.material as ShaderMaterial
    material.set_shader_parameter("thickness", thickness)
    material.set_shader_parameter("speed", speed)


func set_area_colors(inner: Color = Color.GREEN * 0.5, outer: Color = Color.WHITE, lerp_col: Color = Color.GREEN) -> void:
    if not mesh:
        return
    
    var material := mesh.material as ShaderMaterial
    
    if not material:
        return

    material.set_shader_parameter("inner_color", inner)
    material.set_shader_parameter("outer_color", outer)
    material.set_shader_parameter("lerp_color", lerp_col)


func update_fixed_target(target_pos: Vector3) -> void:
    if visible:
        target_position = target_pos
        aim_direction = Vector3((target_pos - global_position).normalized().x, 0.0, (target_pos - global_position).normalized().z).normalized()
        update_shader_params()

func update_free_select_direction(from_pos: Vector3, to_pos: Vector3) -> void:
    if visible:
        aim_direction = Vector3((to_pos - from_pos).normalized().x, 0.0, (to_pos - from_pos).normalized().z).normalized()
        update_shader_params()

func tween_area_colors(inner: Color, outer: Color, lerp_col: Color, duration: float = 1.0, transition_type: Tween.TransitionType = Tween.TRANS_LINEAR) -> void:
    if not mesh:
        return
    
    var material := mesh.material as ShaderMaterial
    
    if not material:
        return

    var tween := create_tween()
    tween.tween_property(material, "inner_color", inner, duration).set_trans(transition_type)
    tween.tween_property(material, "outer_color", outer, duration).set_trans(transition_type)
    tween.tween_property(material, "lerp_color", lerp_col, duration).set_trans(transition_type)

func set_oscillate_color(enabled: bool) -> void:
    if not mesh or not mesh.material:
        return
    
    var material := mesh.material as ShaderMaterial
    material.set_shader_parameter("oscillate_colour", enabled)