shader_type canvas_item;

// CRT/Arcade screen effect with barrel distortion

// Screen texture uniform (required for Godot 4)
uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;

uniform float curvature : hint_range(0.0, 10.0) = 2.0;  // Screen curvature amount
uniform float scanline_strength : hint_range(0.0, 1.0) = 0.3;  // Scanline visibility
uniform float vignette_strength : hint_range(0.0, 1.0) = 0.5;  // Edge darkening
uniform float scanline_count : hint_range(100.0, 1000.0) = 400.0;  // Number of scanlines
uniform vec3 screen_tint : source_color = vec3(1.0, 0.95, 0.9);  // Slight warm tint

vec2 curve(vec2 uv) {
    // Apply barrel distortion (convex curvature)
    uv = uv * 2.0 - 1.0;  // Transform to -1 to 1 range
    vec2 offset = abs(uv.yx) / vec2(curvature, curvature);
    uv = uv + uv * offset * offset;
    uv = uv * 0.5 + 0.5;  // Transform back to 0 to 1 range
    return uv;
}

void fragment() {
    vec2 uv = curve(SCREEN_UV);  // Use SCREEN_UV instead of UV
    
    // Check if we're outside the curved screen bounds
    if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) {
        COLOR = vec4(0.0, 0.0, 0.0, 1.0);  // Black borders
    } else {
        // Sample the screen texture with curved UV
        vec4 color = texture(SCREEN_TEXTURE, uv);  // Use SCREEN_TEXTURE
        
        // Scanlines
        float scanline = sin(uv.y * scanline_count * 3.14159) * 0.5 + 0.5;
        scanline = mix(1.0, scanline, scanline_strength);
        
        // Vignette effect (darker edges)
        vec2 vignetteUV = SCREEN_UV * 2.0 - 1.0;
        float vignette = 1.0 - dot(vignetteUV, vignetteUV) * vignette_strength;
        vignette = clamp(vignette, 0.0, 1.0);
        
        // Apply effects
        color.rgb *= scanline;
        color.rgb *= vignette;
        color.rgb *= screen_tint;
        
        COLOR = color;
    }
}