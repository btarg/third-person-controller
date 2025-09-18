shader_type spatial;
render_mode depth_draw_never, cull_disabled;

uniform sampler2D albedo : source_color;
uniform sampler2D normal : hint_normal;
uniform vec3 projector_size = vec3(1.0);
uniform sampler2D depth_tex : hint_depth_texture;
uniform float projection_fade = 10.0; // Controls fade distance for Y projection
uniform bool bidirectional = true; // Toggle between one-way and two-way projection

void fragment() {
    float depth = texture(depth_tex, SCREEN_UV).x;
    vec4 ndc = vec4(SCREEN_UV * 2.0 - 1.0, depth, 1.0);
    vec4 view = INV_PROJECTION_MATRIX * ndc;
    view /= view.w;
    
    vec3 local_pos = (inverse(MODEL_MATRIX) * INV_VIEW_MATRIX * view).xyz;
    
    // For bidirectional projection, we ignore the Y component for bounds checking
    // but still use it for fading
    vec3 uvw = local_pos / projector_size + 0.5;
    
    if (bidirectional) {
        // Check only X and Z bounds, ignore Y for visibility
        if (uvw.x < 0.0 || uvw.x > 1.0 || uvw.z < 0.0 || uvw.z > 1.0) {
            discard;
        }
        
        // Optional: Add fade based on Y distance from projector
        float y_fade = 1.0;
        if (projection_fade > 0.0) {
            float y_dist = abs(local_pos.y);
            y_fade = 1.0 - smoothstep(0.0, projector_size.y * projection_fade, y_dist);
            if (y_fade <= 0.0) discard;
        }
        
        vec4 color = texture(albedo, uvw.xz);
        ALBEDO = color.rgb;
        ALPHA = color.a * y_fade;
        NORMAL_MAP = texture(normal, uvw.xz).rgb;
        ROUGHNESS = 0.5;
        
    } else {
        // Original one-directional behavior
        if (any(lessThan(uvw, vec3(0.0))) || any(greaterThan(uvw, vec3(1.0)))) {
            discard;
        }
        
        vec4 color = texture(albedo, uvw.xz);
        ALBEDO = color.rgb;
        ALPHA = color.a;
        NORMAL_MAP = texture(normal, uvw.xz).rgb;
        ROUGHNESS = 0.5;
    }
}