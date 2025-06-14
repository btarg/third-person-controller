shader_type spatial;

uniform float ring_radius : hint_range(0.1, 0.5, 0.01) = 0.4;
uniform float thickness = 0.05;
uniform float speed : hint_range(0.0, 50.0, 0.1) = 1.0;
uniform float glow_intensity : hint_range(0.0, 1.0, 0.01) = 0.5;
uniform float glow_start : hint_range(0.0, 1.0, 0.01) = 0.7; // Controls where glow begins relative to thickness
uniform vec4 outer_color : source_color = vec4(1.0,1.0,1.0,1.0);
uniform vec4 lerp_color : source_color = vec4(1.0,1.0,1.0,1.0);
uniform vec4 inner_color : source_color = vec4(1.0,1.0,1.0,0.2);

uniform bool oscillate_colour = false;

float range_lerp(float value, float min1, float min2, float max1, float max2){
    return min2 + (max2 - min2) * ((value - min1) / (max1 - min1));
}

void fragment() {
    float dist = distance(UV, vec2(0.5, 0.5));
    float o = cos(TIME * speed);

    // Ring calculation - remove smoothstep for hard edge
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