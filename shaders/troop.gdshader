shader_type spatial;

// 'depth_draw_opaque' ensures they don't vanish behind each other
render_mode unshaded, depth_draw_opaque, cull_back;

uniform sampler2DArray flags;
uniform sampler2D numbers_atlas;

// Colors
uniform vec4 plate_color : source_color = vec4(0.08, 0.08, 0.08, 0.9);
uniform vec4 border_color : source_color = vec4(0.18, 0.18, 0.18, 1.0);
uniform vec4 hp_green : source_color = vec4(0.15, 0.85, 0.25, 1.0);
uniform vec4 hp_red   : source_color = vec4(0.85, 0.15, 0.15, 1.0);
uniform vec4 text_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);

// UI Design
uniform float corner_radius = 0.1;
uniform float border_size = 0.02;

// --- VARYINGS: The bridge between Vertex and Fragment ---
varying vec4 troop_data; 

void vertex() {
	// 1. Pass Custom Data to Fragment (Keep this!)
	troop_data = INSTANCE_CUSTOM;

	// 2. THE FIX: Spherical Billboarding
	// We extract the origin (position) from the Model Matrix
	vec3 world_pos = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	
	// We get the distance/size from the model matrix scale
	// This ensures your 'marker_size' from GDScript still works!
	float scale_x = length(MODEL_MATRIX[0].xyz);
	float scale_y = length(MODEL_MATRIX[1].xyz);

	// Reconstruct the View Matrix for this specific instance
	// This forces the quad to face the camera regardless of its rotation
	mat4 billboard_matrix = VIEW_MATRIX;
	billboard_matrix[0] = vec4(1.0, 0.0, 0.0, 0.0);
	billboard_matrix[1] = vec4(0.0, 1.0, 0.0, 0.0);
	billboard_matrix[2] = vec4(0.0, 0.0, 1.0, 0.0);
	
	// Apply the scales back so 'marker_size' isn't lost
	MODELVIEW_MATRIX = billboard_matrix * mat4(
		vec4(scale_x, 0.0, 0.0, 0.0),
		vec4(0.0, scale_y, 0.0, 0.0),
		vec4(0.0, 0.0, 1.0, 0.0),
		vec4(0.0, 0.0, 0.0, 1.0)
	);
	
	// Set the position correctly
	MODELVIEW_MATRIX[3] = (VIEW_MATRIX * vec4(world_pos, 1.0));
}
// Helper for rounded corners
float rounded_box(vec2 uv, vec2 size, float radius) {
	vec2 d = abs(uv - 0.5) - size + vec2(radius);
	return length(max(d, 0.0)) - radius;
}

void fragment() {
    // 1. UNPACK DATA (Keep your current logic)
    float flag_low = round(troop_data.r * 255.0);
    float count    = round(troop_data.g * 255.0);
    float health   = clamp(troop_data.b, 0.0, 1.0); 
    float flag_high = round(troop_data.a * 255.0);
    float flag_idx = flag_low + (flag_high * 256.0);
    
    vec2 uv = UV;

    // 2. ROUNDED PLATE MASK
    float box_dist = rounded_box(uv, vec2(0.48, 0.48), corner_radius);
    if (box_dist > 0.0) { discard; }

    // 3. BORDER & BACKGROUND
    float border_dist = rounded_box(uv, vec2(0.48 - border_size, 0.48 - border_size), corner_radius);
    vec4 final_color = (border_dist > 0.0) ? border_color : plate_color;

    // --- 4. NEW REGION LAYOUT ---
    
    // REGION A: PROGRESS BAR (Bottom 25%)
    // This matches the MarginContainer + ProgressBar at the bottom
    if (uv.y > 0.75) {
        // Horizontal padding for the progress bar (inset slightly)
        float bar_padding = 0.05;
        if (uv.x > bar_padding && uv.x < 1.0 - bar_padding) {
            float bar_progress = (uv.x - bar_padding) / (1.0 - 2.0 * bar_padding);
            final_color = (bar_progress < health) ? hp_green : hp_red;
        }
    }
    // REGION B: TOP CONTENT (Flag + Number side-by-side)
    else {
        // Split top area: Left 65% for Flag, Right 35% for Number
        if (uv.x < 0.65) {
            // FLAG AREA
            vec2 flag_uv = vec2(uv.x / 0.65, uv.y / 0.75);
            // Inset to prevent touching the border
            flag_uv = mix(vec2(0.15), vec2(0.85), flag_uv);
            
            vec4 f_tex = texture(flags, vec3(flag_uv, flag_idx));
            final_color = mix(final_color, f_tex, f_tex.a);
        } 
        else {
            // NUMBER AREA
            float tens = floor(count / 10.0);
            float ones = mod(count, 10.0);
            
            // Remap UV to the small square on the right
            vec2 num_uv = vec2((uv.x - 0.65) / 0.35, uv.y / 0.75);
            
            float digit;
            vec2 digit_uv;
            // Split this tiny area vertically to stack numbers? 
            // Usually, side-by-side is better for "99"
            if (num_uv.x < 0.5) {
                digit = tens;
                digit_uv = vec2(num_uv.x * 2.0, num_uv.y);
            } else {
                digit = ones;
                digit_uv = vec2((num_uv.x - 0.5) * 2.0, num_uv.y);
            }
            
            digit_uv = mix(vec2(0.2), vec2(0.8), digit_uv);

            if (!(num_uv.x < 0.5 && count < 10.0)) {
                vec2 atlas_uv = vec2((digit * 0.1) + (digit_uv.x * 0.1), digit_uv.y);
                vec4 t_tex = texture(numbers_atlas, atlas_uv);
                final_color = mix(final_color, text_color, t_tex.a);
            }
        }
    }

    ALBEDO = final_color.rgb;
    ALPHA = final_color.a;
}