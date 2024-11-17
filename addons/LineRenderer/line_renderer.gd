@tool
class_name LineRenderer3D
extends MeshInstance3D

@export var points: Array[Vector3] = [Vector3(0, 0, 0), Vector3(0, 5, 0)]
@export var start_thickness := 0.1
@export var end_thickness := 0.1
@export var corner_resolution := 5
@export var cap_resolution := 5
@export var draw_caps := true
@export var draw_corners := true
@export var use_global_coords := true
@export var tile_texture := true

var camera: Camera3D
var cameraOrigin: Vector3

func _enter_tree() -> void:
    mesh = ImmediateMesh.new()

func remove_line() -> void:
    points.clear()
    mesh.clear_surfaces()

func _process(_delta) -> void:
    if points.size() < 2:
        return
    camera = get_viewport().get_camera_3d()
    if camera == null:
        return
    cameraOrigin = to_local(camera.get_global_transform().origin)
    
    var progressStep: float = 1.0 / points.size();
    var progress: float = 0;
    var thickness: float = lerp(start_thickness, end_thickness, progress);
    var nextThickness: float = lerp(start_thickness, end_thickness, progress + progressStep);
    
    mesh.clear_surfaces()
    mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
    
    for i in range(points.size() - 1):
        var A: Vector3 = points[i]
        var B: Vector3 = points[i + 1]
    
        if use_global_coords:
            A = to_local(A)
            B = to_local(B)
    
        var AB: Vector3 = B - A;
        var orthogonalABStart: Vector3 = (cameraOrigin - ((A + B) / 2)).cross(AB).normalized() * thickness;
        var orthogonalABEnd: Vector3 = (cameraOrigin - ((A + B) / 2)).cross(AB).normalized() * nextThickness;
        
        var AtoABStart := A + orthogonalABStart
        var AfromABStart := A - orthogonalABStart
        var BtoABEnd := B + orthogonalABEnd
        var BfromABEnd := B - orthogonalABEnd
        
        if i == 0:
            if draw_caps:
                cap(A, B, thickness, cap_resolution)
        
        if tile_texture:
            var ABLen = AB.length()
            var ABFloor = floor(ABLen)
            var ABFrac = ABLen - ABFloor
            
            mesh.surface_set_uv(Vector2(ABFloor, 0))
            mesh.surface_add_vertex(AtoABStart)
            mesh.surface_set_uv(Vector2(-ABFrac, 0))
            mesh.surface_add_vertex(BtoABEnd)
            mesh.surface_set_uv(Vector2(ABFloor, 1))
            mesh.surface_add_vertex(AfromABStart)
            mesh.surface_set_uv(Vector2(-ABFrac, 0))
            mesh.surface_add_vertex(BtoABEnd)
            mesh.surface_set_uv(Vector2(-ABFrac, 1))
            mesh.surface_add_vertex(BfromABEnd)
            mesh.surface_set_uv(Vector2(ABFloor, 1))
            mesh.surface_add_vertex(AfromABStart)
        else:
            mesh.surface_set_uv(Vector2(1, 0))
            mesh.surface_add_vertex(AtoABStart)
            mesh.surface_set_uv(Vector2(0, 0))
            mesh.surface_add_vertex(BtoABEnd)
            mesh.surface_set_uv(Vector2(1, 1))
            mesh.surface_add_vertex(AfromABStart)
            mesh.surface_set_uv(Vector2(0, 0))
            mesh.surface_add_vertex(BtoABEnd)
            mesh.surface_set_uv(Vector2(0, 1))
            mesh.surface_add_vertex(BfromABEnd)
            mesh.surface_set_uv(Vector2(1, 1))
            mesh.surface_add_vertex(AfromABStart)
        
        if i == points.size() - 2:
            if draw_caps:
                cap(B, A, nextThickness, cap_resolution)
        else:
            if draw_corners:
                var C := points[i + 2]
                if use_global_coords:
                    C = to_local(C)
                
                var BC := C - B;
                var orthogonalBCStart = (cameraOrigin - ((B + C) * 0.5)).cross(BC).normalized() * nextThickness;
                
                var angleDot := AB.dot(orthogonalBCStart)
                
                if angleDot > 0 and not angleDot == 1:
                    corner(B, BtoABEnd, B + orthogonalBCStart, corner_resolution)
                elif angleDot < 0 and not angleDot == -1:
                    corner(B, B - orthogonalBCStart, BfromABEnd, corner_resolution)
        
        progress += progressStep;
        thickness = lerp(start_thickness, end_thickness, progress);
        nextThickness = lerp(start_thickness, end_thickness, progress + progressStep);
    
    mesh.surface_end()

func cap(center: Vector3, pivot: Vector3, thickness: float, cap_resolution: int) -> void:
    var orthogonal := (cameraOrigin - center).cross(center - pivot).normalized() * thickness;
    var axis := (center - cameraOrigin).normalized();
    
    var vertex_array: Array[Vector3] = []
    for i in range(cap_resolution + 1):
        vertex_array.append(Vector3.ZERO)
    vertex_array[0] = center + orthogonal;
    vertex_array[cap_resolution] = center - orthogonal;
    
    for i in range(1, cap_resolution):
        vertex_array[i] = center + (orthogonal.rotated(axis, lerp(0.0, PI, float(i) / cap_resolution)));
    
    for i in range(1, cap_resolution + 1):
        mesh.surface_set_uv(Vector2(0, (i - 1) / cap_resolution))
        mesh.surface_add_vertex(vertex_array[i - 1]);
        mesh.surface_set_uv(Vector2(0, (i - 1) / cap_resolution))
        mesh.surface_add_vertex(vertex_array[i]);
        mesh.surface_set_uv(Vector2(0.5, 0.5))
        mesh.surface_add_vertex(center);
        
func corner(center: Vector3, start: Vector3, end: Vector3, cap_resolution: int) -> void:
    var vertex_array: Array = []
    for i in range(cap_resolution + 1):
        vertex_array.append(Vector3.ZERO)
    vertex_array[0] = start;
    vertex_array[cap_resolution] = end;
    
    var axis := start.cross(end).normalized()
    var offset := start - center
    var angle := offset.angle_to(end - center)
    
    for i in range(1, cap_resolution):
        vertex_array[i] = center + offset.rotated(axis, lerp(0.0, angle, float(i) / cap_resolution));
    
    for i in range(1, cap_resolution + 1):
        mesh.surface_set_uv(Vector2(0, (i - 1) / cap_resolution))
        mesh.surface_add_vertex(vertex_array[i - 1]);
        mesh.surface_set_uv(Vector2(0, (i - 1) / cap_resolution))
        mesh.surface_add_vertex(vertex_array[i]);
        mesh.surface_set_uv(Vector2(0.5, 0.5))
        mesh.surface_add_vertex(center);
