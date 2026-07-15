// Always-on presentation pass: light film grain + small vignette,
// per the art direction ("premium, cinematic, avoid excessive effects").
// `boost` is punched briefly by the HUD on a MAX POWER kick.
shader_type canvas_item;

uniform float grain_amount : hint_range(0.0, 0.2) = 0.05;
uniform float vignette_amount : hint_range(0.0, 0.5) = 0.05;
uniform float boost : hint_range(0.0, 1.0) = 0.0;

float rand(vec2 co) {
	return fract(sin(dot(co, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	// Noise centered on mid-gray so blending adds speckle without brightening.
	float noise = rand(SCREEN_UV * 913.0 + vec2(fract(TIME) * 71.0, 0.0));
	vec3 grain_color = vec3(noise);
	float grain_alpha = grain_amount;

	vec2 centered = SCREEN_UV - 0.5;
	float vignette_alpha = (vignette_amount + boost * 0.35)
		* smoothstep(0.15, 0.75, dot(centered, centered) * 2.0);

	// Composite the two overlays: vignette (black) dominates at the edges,
	// grain (gray noise) elsewhere.
	float total = grain_alpha + vignette_alpha + 0.0001;
	COLOR = vec4(grain_color * (grain_alpha / total), clamp(total, 0.0, 1.0));
}
