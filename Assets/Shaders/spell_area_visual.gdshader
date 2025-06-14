shader_type spatial;
render_mode unshaded, depth_draw_opaque, cull_disabled;

#include "inc/areas.gdshaderinc"

uniform int area_type : hint_enum("Circle", "Cone", "Line") = 0;
/* Radius acts as the "length" of the cone or the radius of the circle (equivalent to metres) */
uniform float radius : hint_range(0.1, 50.0) = 5.0;

uniform float cone_angle_rad : hint_range(0.1, 6.28) = 1.047; // ~60 degrees

// Line indicator uniforms
uniform float line_length : hint_range(0.1, 50.0) = 10.0;
uniform float line_width : hint_range(0.1, 20.0) = 2.0;

uniform vec3 aim_direction = vec3(0.0, 0.0, 1.0);

// Ring shader uniforms
uniform float thickness : hint_range(0.1, 1.0) = 0.95;
uniform float speed : hint_range(0.0, 50.0, 0.1) = 1.0;
uniform float glow_intensity : hint_range(0.0, 1.0, 0.01) = 0.5;
uniform float glow_start : hint_range(0.0, 1.0, 0.01) = 0.7;
uniform vec4 outer_color : source_color = vec4(1.0,1.0,1.0,1.0);
uniform vec4 lerp_color : source_color = vec4(0.0,1.0,0.0,1.0);
uniform vec4 inner_color : source_color = vec4(0.0,1.0,0.0,0.2);
uniform bool oscillate_colour = false;

varying vec3 world_vertex;
varying vec3 local_vertex;
varying vec3 local_aim_direction;

void vertex() {
	world_vertex = VERTEX;
	local_vertex = VERTEX;
	// Transform directions from world space to local space
	local_aim_direction = (inverse(MODEL_MATRIX) * vec4(aim_direction, 0.0)).xyz;
}

float range_lerp(float value, float min1, float min2, float max1, float max2) {
    return min2 + (max2 - min2) * ((value - min1) / (max1 - min1));
}

void fragment() {
	// Use local vertex position relative to the plane's center
	vec2 local_pos_2d = local_vertex.xz;
	vec3 local_pos_3d = vec3(local_vertex.x, 0.0, local_vertex.z);

	bool inside_area = false;

	if (area_type == 0) {
		// Circle indicator - check if point is within radius in local coordinates
		inside_area = length(local_pos_2d) <= radius;
	} else if (area_type == 1) {
		// Cone indicator - use the transformed local cone direction
		inside_area = point_in_cone(local_pos_3d, radius, cone_angle_rad, local_aim_direction);
	} else if (area_type == 2) {
		// Line indicator - use the transformed local line direction
		inside_area = point_in_line(local_pos_3d, line_length, line_width, local_aim_direction);
	}

	if (!inside_area) {
		discard; // Don't render outside the spell area
	}

	// Convert to UV coordinates (0-1 range) for ring shader
	// Normalize by the actual radius to match collision detection
	vec2 uv = (local_pos_2d / radius + 1.0) * 0.5;
	float dist = distance(uv, vec2(0.5, 0.5));
	float o = cos(TIME * speed);

	// Ring calculation
    float ring_radius = 0.5;
	float ring_alpha = step(dist, ring_radius) * step(ring_radius * thickness, dist);

	// Inner circle calculation with edge glow
	float edge_dist = ring_radius * thickness;
	float glow_start_dist = edge_dist * glow_start;
	float base_alpha = inner_color.a;
	float edge_alpha = smoothstep(glow_start_dist, edge_dist, dist) * glow_intensity;
	float inner_alpha = step(dist, edge_dist) * max(base_alpha, edge_alpha);

	// Color mixing for ring
	vec3 ring_color;
	if (oscillate_colour) {
		float w = range_lerp(o, -1.0, 1.0, 1.0, 0.0);
		ring_color = mix(outer_color.rgb, lerp_color.rgb, w);
	} else {
		ring_color = mix(outer_color.rgb, lerp_color.rgb, step(ring_radius, dist));
	}

	// Final color blend with hard transition
	ALBEDO = mix(inner_color.rgb, ring_color, step(ring_radius * thickness, dist));
	ALPHA = ring_alpha > 0.0 ? 1.0 : inner_alpha;
}