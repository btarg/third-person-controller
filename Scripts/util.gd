class_name Util

static func print_rainbow(text: String) -> void:
    print_rich("[rainbow freq=1.0 sat=0.8 val=0.8]%s[/rainbow]" % text)

## Calculates a quadratic bezier curve
static func _quadratic_bezier(p0: Vector3, p1: Vector3, p2: Vector3, t: float) -> Vector3:
    var q0 := p0.lerp(p1, t)
    var q1 := p1.lerp(p2, t)
    var r := q0.lerp(q1, t)
    return r

## Returns an intersect_ray dictionary
static func raycast_from_center_or_mouse(cam: Camera3D, exclude: Array[RID]) -> Dictionary:
    # center the raycast origin position if using controller
    var viewport := cam.get_viewport()
    var viewport_center := Vector2(viewport.get_visible_rect().size.x / 2, viewport.get_visible_rect().size.y / 2)
    var raycast_start_pos := (viewport.get_mouse_position() if not ControllerHelper.is_using_controller
    else viewport_center)

    # BUG: using a separate thread for 3d physics will cause a crash
    # due to the space not being accessible
    var space := cam.get_world_3d().direct_space_state


    var ray_query := PhysicsRayQueryParameters3D.new()
    ray_query.from = cam.project_ray_origin(raycast_start_pos)
    ray_query.to = cam.project_ray_normal(raycast_start_pos) * 1000
    ray_query.exclude = exclude
    var result := space.intersect_ray(ray_query)

    return result

static func round_to_dec(num: float, digit: int) -> float:
    return round(num * pow(10.0, digit)) / pow(10.0, digit)

static func string_contains_any(text: String, substrings: Array[String]) -> bool:
    for substring in substrings:
        if text.find(substring) > -1:
            return true
    return false

static func get_enum_name(enum_dict: Dictionary, value: int) -> String:
    for key: String in enum_dict.keys():
        if enum_dict[key] == value:
            return key
    return "[ERR no enum key %d]" % value

static func get_letter(index: int) -> String:
    var alphabet: String = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
    if index >= 0:
        if index < alphabet.length():
            return alphabet.substr(index, 1)
        else:
            return str(index - alphabet.length() + 1)
    return ""
