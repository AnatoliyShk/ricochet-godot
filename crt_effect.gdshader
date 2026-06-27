shader_type canvas_item;

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;

uniform float curvature : hint_range(0.0, 10.0) = 6.0;
uniform float scanline_strength : hint_range(0.0, 1.0) = 0.3;
uniform float vignette_strength : hint_range(0.0, 1.0) = 0.5;
uniform float scanline_count : hint_range(100.0, 1000.0) = 400.0;
uniform vec3 screen_tint : source_color = vec3(1.0, 0.95, 0.9);
uniform float tv_off : hint_range(0.0, 1.0) = 0.0;

vec2 curve(vec2 uv) {
    uv = uv * 2.0 - 1.0;
    vec2 offset = abs(uv.yx) / vec2(curvature, curvature);
    uv = uv + uv * offset * offset;
    uv = uv * 0.5 + 0.5;
    return uv;
}

void fragment() {
    vec2 uv = curve(SCREEN_UV);

    if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) {
        // Metal panel perspective depth effect
        float panel_size = 48.0;
        float line_width = 2.0;
        float rivet_radius = 3.5;

        // Direction pointing toward screen boundary
        vec2 screen_dir = vec2(0.0);
        if (uv.x < 0.0)      screen_dir.x =  1.0;
        else if (uv.x > 1.0) screen_dir.x = -1.0;
        if (uv.y < 0.0)      screen_dir.y =  1.0;
        else if (uv.y > 1.0) screen_dir.y = -1.0;
        if (length(screen_dir) > 0.001) screen_dir = normalize(screen_dir);

        // Distance outside screen bounds (0 = at screen edge, grows outward)
        float dist_from_screen = 0.0;
        if (uv.x < 0.0)      dist_from_screen = max(dist_from_screen, -uv.x);
        else if (uv.x > 1.0) dist_from_screen = max(dist_from_screen,  uv.x - 1.0);
        if (uv.y < 0.0)      dist_from_screen = max(dist_from_screen, -uv.y);
        else if (uv.y > 1.0) dist_from_screen = max(dist_from_screen,  uv.y - 1.0);

        // t: 0 at screen edge, 1 at max depth
        float t = clamp(dist_from_screen / 0.4, 0.0, 1.0);

        // Perspective division — grid lines converge toward screen center as depth grows
        float persp_scale = 1.0 / (1.0 + t * 5.0);
        vec2 vp_center  = 0.5 / SCREEN_PIXEL_SIZE;
        vec2 grid_coord = FRAGCOORD.xy;
        if (abs(screen_dir.x) > 0.5 && abs(screen_dir.y) > 0.5) {
            grid_coord = vp_center + (FRAGCOORD.xy - vp_center) * persp_scale;
        } else if (abs(screen_dir.x) > abs(screen_dir.y)) {
            grid_coord.y = vp_center.y + (FRAGCOORD.y - vp_center.y) * persp_scale;
        } else {
            grid_coord.x = vp_center.x + (FRAGCOORD.x - vp_center.x) * persp_scale;
        }

        vec2 cell = mod(grid_coord, panel_size);

        // Strong depth attenuation — near-black at far corners
        float depth_atten = pow(1.0 - t, 1.8);

        // Bright rim right at the screen boundary (screen light spill)
        float edge_glow = smoothstep(0.08, 0.0, dist_from_screen) * 0.45;

        // Per-panel directional shading (face tilted toward screen)
        vec2 local_norm = (cell / panel_size) * 2.0 - 1.0;
        float dir_shade = dot(local_norm, screen_dir) * 0.5 + 0.5;
        float light = clamp((mix(0.25, 1.0, dir_shade) + edge_glow) * depth_atten, 0.0, 1.0);

        vec3 metal_base   = vec3(0.18, 0.20, 0.24);
        vec3 metal_groove = vec3(0.05, 0.06, 0.08);
        vec3 rivet_mid    = vec3(0.50, 0.53, 0.60);
        vec3 rivet_hi     = vec3(0.72, 0.75, 0.82);

        // Smooth groove mask
        float gx = smoothstep(line_width + 0.8, line_width - 0.8, cell.x);
        float gy = smoothstep(line_width + 0.8, line_width - 0.8, cell.y);
        float groove_mask = max(gx, gy);

        // Smooth rivet: distance to nearest cell corner
        float dist_corner = min(
            min(length(cell), length(cell - vec2(panel_size, 0.0))),
            min(length(cell - vec2(0.0, panel_size)), length(cell - vec2(panel_size, panel_size)))
        );
        float rivet_outer = smoothstep(rivet_radius + 1.0, rivet_radius - 1.0, dist_corner);
        float rivet_inner = smoothstep(rivet_radius * 0.45 + 0.6, rivet_radius * 0.45 - 0.6, dist_corner);

        // Layer: panel -> groove -> rivet body -> rivet highlight
        vec3 border_color = metal_base * light;
        border_color = mix(border_color, metal_groove * depth_atten, groove_mask);
        border_color = mix(border_color, rivet_mid * depth_atten, rivet_outer);
        border_color = mix(border_color, rivet_hi * clamp(depth_atten + edge_glow, 0.0, 1.0), rivet_inner);

        COLOR = vec4(border_color, 1.0);
    } else {
        if (tv_off > 0.0) {
            // TV turn-off: vertical squish toward center line
            float band_half = max(0.002, (1.0 - tv_off) * 0.5);
            float dist_y = abs(uv.y - 0.5);

            if (dist_y >= band_half) {
                COLOR = vec4(0.0, 0.0, 0.0, 1.0);
            } else {
                // Remap Y so the full game image squishes into the band
                vec2 sample_uv = vec2(uv.x, 0.5 + (uv.y - 0.5) / (band_half * 2.0));
                vec4 color = texture(SCREEN_TEXTURE, sample_uv);

                // Scanlines and vignette still apply
                float scanline = sin(sample_uv.y * scanline_count * 3.14159) * 0.5 + 0.5;
                scanline = mix(1.0, scanline, scanline_strength);
                vec2 vignetteUV = uv * 2.0 - 1.0;
                float vignette = 1.0 - dot(vignetteUV, vignetteUV) * vignette_strength;
                vignette = clamp(vignette, 0.0, 1.0);
                color.rgb *= scanline * vignette * screen_tint;

                // Turn content white as band gets very thin (phosphor line)
                float line_white = smoothstep(0.55, 0.9, tv_off);
                color.rgb = mix(color.rgb, vec3(1.0), line_white);

                // Fade the white line out at the very end
                float line_fade = smoothstep(1.0, 0.92, tv_off);
                color.rgb *= line_fade;

                COLOR = color;
            }
        } else {
            vec4 color = texture(SCREEN_TEXTURE, uv);

            float scanline = sin(uv.y * scanline_count * 3.14159) * 0.5 + 0.5;
            scanline = mix(1.0, scanline, scanline_strength);

            vec2 vignetteUV = SCREEN_UV * 2.0 - 1.0;
            float vignette = 1.0 - dot(vignetteUV, vignetteUV) * vignette_strength;
            vignette = clamp(vignette, 0.0, 1.0);

            color.rgb *= scanline;
            color.rgb *= vignette;
            color.rgb *= screen_tint;

            COLOR = color;
        }
    }
}
