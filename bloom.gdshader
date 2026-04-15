shader_type canvas_item;

// Simple Bloom/Glow effect for arcade-style visuals

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;

uniform float bloom_intensity : hint_range(0.0, 3.0) = 0.8;
uniform float bloom_threshold : hint_range(0.0, 1.0) = 0.6;

void fragment() {
	// Get original color
	vec4 color = texture(SCREEN_TEXTURE, SCREEN_UV);
	
	// Simple 9-sample bloom
	vec3 bloom = vec3(0.0);
	float pixel_size = 0.002;  // Adjust for blur radius
	
	// Sample in a 3x3 grid
	for (float x = -1.0; x <= 1.0; x += 1.0) {
		for (float y = -1.0; y <= 1.0; y += 1.0) {
			vec2 offset = vec2(x, y) * pixel_size;
			vec4 sample_color = texture(SCREEN_TEXTURE, SCREEN_UV + offset);
			
			// Check if pixel is bright enough to glow
			float brightness = max(sample_color.r, max(sample_color.g, sample_color.b));
			
			if (brightness > bloom_threshold) {
				bloom += sample_color.rgb;
			}
		}
	}
	
	// Average and apply bloom
	bloom /= 9.0;
	color.rgb += bloom * bloom_intensity;
	
	COLOR = color;
}