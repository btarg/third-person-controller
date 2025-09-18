extends Area3D
class_name ItemProjectile

# Projectile configuration
var item: Item
var caster: BattleCharacter
var target_position: Vector3
var target_character: BattleCharacter = null

# Physics properties
var speed: float = 15.0
var projectile_gravity: float = 9.8
var arc_height: float = 3.0
var acceleration: float = 0.0

# Movement tracking
var start_position: Vector3
var travel_time: float = 0.0
var total_travel_time: float = 2.0
var arc_middle_point: Vector3

# Signals
signal OnHitCharacter(character: BattleCharacter, projectile: ItemProjectile)
signal OnHitGround(position: Vector3, projectile: ItemProjectile)
signal OnProjectileDestroyed(projectile: ItemProjectile)

func _ready() -> void:
    body_entered.connect(_on_body_entered)
    area_entered.connect(_on_area_entered)
    
    # Set up collision detection
    monitoring = true
    monitorable = true

func initialize(spell_item: Item, casting_character: BattleCharacter, target_pos: Vector3, target_char: BattleCharacter = null) -> void:
    """Initialize the projectile with item data and target information"""
    item = spell_item
    caster = casting_character
    target_position = target_pos
    target_character = target_char
    
    # Store starting position after projectile is properly positioned
    start_position = global_position
    
    # Calculate trajectory based on target
    _calculate_trajectory()
    
    # Setup visual appearance based on spell element
    _setup_visual_appearance()

func _setup_visual_appearance() -> void:
    """Setup the projectile's visual appearance based on the spell element"""
    var mesh_instance := get_node("MeshInstance3D") as MeshInstance3D
    if not mesh_instance:
        return
    
    # Create a new material for the projectile
    var material := StandardMaterial3D.new()
    
    # Set color and effects based on spell element
    match item.element:
        BattleEnums.EAffinityElement.FIRE:
            material.albedo_color = Color.RED
            material.emission = Color.RED * 0.8
        BattleEnums.EAffinityElement.ICE:
            material.albedo_color = Color.CYAN
            material.emission = Color.CYAN * 0.6
        BattleEnums.EAffinityElement.ELEC:
            material.albedo_color = Color.YELLOW
            material.emission = Color.YELLOW * 0.9
        BattleEnums.EAffinityElement.HEAL:
            material.albedo_color = Color.GREEN
            material.emission = Color.GREEN * 0.7
        BattleEnums.EAffinityElement.DARK:
            material.albedo_color = Color.PURPLE
            material.emission = Color.PURPLE * 0.5
        BattleEnums.EAffinityElement.LIGHT:
            material.albedo_color = Color.WHITE
            material.emission = Color.WHITE * 0.8
        BattleEnums.EAffinityElement.WIND:
            material.albedo_color = Color.LIGHT_GREEN
            material.emission = Color.LIGHT_GREEN * 0.4
        BattleEnums.EAffinityElement.MANA:
            material.albedo_color = Color.BLUE
            material.emission = Color.BLUE * 0.6
        _:
            material.albedo_color = Color.WHITE
            material.emission = Color.WHITE * 0.3
    
    # Add some glow and transparency
    material.flags_transparent = true
    material.albedo_color.a = 0.8
    
    # Apply the material
    mesh_instance.material_override = material

func _calculate_trajectory() -> void:
    """Calculate trajectory using quadratic bezier curve for guaranteed target hit"""
    # Calculate the arc middle point (halfway between start and target, elevated by arc_height)
    arc_middle_point = start_position.lerp(target_position, 0.5)
    arc_middle_point.y += arc_height
    
    # Calculate travel time based on distance and speed
    var horizontal_distance := Vector2(start_position.x, start_position.z).distance_to(Vector2(target_position.x, target_position.z))
    total_travel_time = max(1.0, horizontal_distance / speed)

func set_travel_time(time: float) -> void:
    """Allow external setting of travel time for consistent timing"""
    total_travel_time = time

func _physics_process(delta: float) -> void:
    if not item:
        return
    
    travel_time += delta
    
    # Check for timeout (using total_travel_time + some buffer)
    if travel_time > total_travel_time + 2.0:
        _destroy_projectile("Timeout")
        return
    
    # Calculate progress along the curve (0.0 to 1.0)
    var progress: float = clamp(travel_time / total_travel_time, 0.0, 1.0)
    
    # Use quadratic bezier to calculate current position
    global_position = Util._quadratic_bezier(start_position, arc_middle_point, target_position, progress)
    
    # Check if we've reached the target
    if progress >= 1.0:
        _handle_target_reached()
        return
    
    # For FIELD items, check if we're close enough to the target to trigger early
    if item.item_type == Item.ItemType.FIELD_ITEM:
        _check_ground_impact_bezier()

func _handle_target_reached() -> void:
    """Handle when projectile reaches its target via bezier curve"""
    if item.item_type == Item.ItemType.FIELD_ITEM:
        _hit_ground()
    else:
        # For BATTLE items, check for character collision at target
        if target_character and target_character.is_alive():
            OnHitCharacter.emit(target_character, self)
            _destroy_projectile("Target reached")
        else:
            _destroy_projectile("No valid target at destination")

func _check_ground_impact_bezier() -> void:
    """Check if projectile should impact the ground early for FIELD items (bezier version)"""
    var target_distance := global_position.distance_to(target_position)
    
    # For bezier movement, we're more lenient about early impacts
    if target_distance < 1.5:
        _hit_ground()

func _hit_ground() -> void:
    """Handle ground impact for FIELD items"""
    OnHitGround.emit(target_position, self)
    _destroy_projectile("Ground impact")

func _on_body_entered(body: Node3D) -> void:
    """Handle collision with characters for BATTLE items"""
    var character: BattleCharacter = body.get_node_or_null("BattleCharacter")
    if not character:
        return
    
    # Don't hit the caster
    if character == caster:
        return
    
    # Only process if character is alive and valid target
    if character.is_alive() and _is_valid_target(character):
        OnHitCharacter.emit(character, self)
        _destroy_projectile("Character hit")

func _on_area_entered(_area: Area3D) -> void:
    """Handle collision with other areas if needed"""
    # Could be used for shields, barriers, etc. in the future
    pass

func _is_valid_target(character: BattleCharacter) -> bool:
    """Check if the character is a valid target for this item"""
    if not item or not caster:
        return false
    
    return item.can_use_on(caster, character)

func _destroy_projectile(_reason: String = "") -> void:
    """Clean up and destroy the projectile"""
    OnProjectileDestroyed.emit(self)
    queue_free()