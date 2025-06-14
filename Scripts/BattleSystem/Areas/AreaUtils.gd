class_name AreaUtils

## Corresponds exactly to the enum in the shader
enum SpellAreaType {
    CIRCLE,
    CONE,
    LINE
}


static func is_point_in_circle(point: Vector3, center: Vector3, circle_radius: float) -> bool:
    var distance := Vector2(point.x - center.x, point.z - center.z).length()
    return distance <= circle_radius


# Check if a point is within a cone
static func is_point_in_cone(point: Vector3, cone_origin: Vector3, cone_radius: float, cone_angle_degrees: float, cone_dir: Vector3) -> bool:
    var to_point := point - cone_origin
    var distance := to_point.length()
    
    # Check if point is within range
    if distance > cone_radius:
        return false
    
    # For points very close to origin, consider them inside
    if distance < 0.001:
        return true
    
    # Project to 2D (remove Y component for ground-based spells)
    var to_point_2d := Vector3(to_point.x, 0.0, to_point.z)
    var cone_dir_2d := Vector3(cone_dir.x, 0.0, cone_dir.z).normalized()
    
    if to_point_2d.length() < 0.001:
        return true
    
    # Calculate angle between cone direction and point direction
    var to_point_normalized := to_point_2d.normalized()
    var dot_product := to_point_normalized.dot(cone_dir_2d)
    
    # Clamp to avoid floating point errors
    dot_product = clamp(dot_product, -1.0, 1.0)
    
    var angle_to_point := acos(dot_product)
    var half_cone_angle := deg_to_rad(cone_angle_degrees * 0.5)
    
    return angle_to_point <= half_cone_angle


# Check if a point is within a line (rectangular area)
static func is_point_in_line(point: Vector3, line_origin: Vector3, length: float, width: float, line_dir: Vector3) -> bool:
    var to_point := point - line_origin
    
    # Project to 2D (remove Y component for ground-based spells)
    var to_point_2d := Vector3(to_point.x, 0.0, to_point.z)
    var line_dir_2d := Vector3(line_dir.x, 0.0, line_dir.z).normalized()
    
    if to_point_2d.length() < 0.001:
        return true  # At origin
    
    # Calculate the perpendicular direction (for width)
    var perpendicular := Vector3(-line_dir_2d.z, 0.0, line_dir_2d.x)
    
    # Project the point onto the line direction and perpendicular direction
    var along_line := to_point_2d.dot(line_dir_2d)
    var across_line := to_point_2d.dot(perpendicular)
    
    # Check if point is within the rectangular bounds
    var within_length: bool = along_line >= 0.0 and along_line <= length
    var within_width: bool = abs(across_line) <= width * 0.5
    
    return within_length and within_width
