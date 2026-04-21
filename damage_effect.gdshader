shader_type canvas_item;

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;
uniform float intensity : hint_range(0.0, 1.0) = 0.0;
uniform float time_offset = 0.0;

void fragment() {
	vec2 uv = SCREEN_UV;

	// Horizontal scanline tears on random bands
	float line = floor(uv.y * 90.0);
	float noise = fract(sin(line * 127.1 + time_offset * 41.3) * 43758.5453);
	float tear = step(1.0 - intensity * 0.55, noise);
	uv.x = fract(uv.x + tear * (noise - 0.5) * 0.09);

	// Whole-screen horizontal jolt at peak
	uv.x = fract(uv.x + intensity * sin(time_offset * 80.0) * 0.004);

	// Chromatic aberration — split R left, B right
	float ab = intensity * 0.018;
	float r = texture(SCREEN_TEXTURE, vec2(uv.x + ab, uv.y)).r;
	float g = texture(SCREEN_TEXTURE, uv).g;
	float b = texture(SCREEN_TEXTURE, vec2(uv.x - ab, uv.y)).b;

	COLOR = vec4(r, g, b, 1.0);

	// Red vignette bleeding in from edges
	float dist = length(SCREEN_UV - vec2(0.5)) * 2.1;
	float vignette = smoothstep(0.55, 1.2, dist);
	COLOR.rgb = mix(COLOR.rgb, vec3(1.0, 0.03, 0.03), vignette * intensity * 0.8);

	// Faint red wash over whole screen
	COLOR.r += intensity * 0.07;
}
