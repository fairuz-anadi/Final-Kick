// Full-screen rewind overlay (Samprity). Shown while the player holds R and
// scrubs the timeline: desaturates toward a cold blue, adds faint scanlines
// and a vignette — the "watching a replay on the busted leg-device" look.
shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float intensity : hint_range(0.0, 1.0) = 1.0;

void fragment() {
	vec4 screen = texture(screen_tex, SCREEN_UV);
	float grey = dot(screen.rgb, vec3(0.299, 0.587, 0.114));
	vec3 desaturated = mix(screen.rgb, vec3(grey) * vec3(0.8, 0.9, 1.05), 0.75 * intensity);
	float scanline = 1.0 - 0.08 * intensity * step(0.5, fract(SCREEN_UV.y * 120.0));
	vec2 centered = SCREEN_UV - 0.5;
	float vignette = 1.0 - 0.9 * intensity * dot(centered, centered);
	COLOR = vec4(desaturated * scanline * vignette, 1.0);
}
