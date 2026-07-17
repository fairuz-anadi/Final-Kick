// Shared "in-between levels" backdrop: a slow-drifting diagonal gradient
// (deep navy -> violet -> cyan-edged) plus a vignette and faint scanlines,
// so every menu/interstitial screen reads as part of the same HUD-vision
// language as the in-level film grain/rewind overlays, instead of flat color.
shader_type canvas_item;

uniform vec4 color_a : source_color = vec4(0.016, 0.024, 0.047, 1.0);
uniform vec4 color_b : source_color = vec4(0.086, 0.043, 0.157, 1.0);
uniform vec4 color_edge : source_color = vec4(0.098, 0.35, 0.42, 1.0);
uniform float drift_speed : hint_range(0.0, 0.2) = 0.03;
uniform float scanline_amount : hint_range(0.0, 0.2) = 0.06;
uniform float vignette_amount : hint_range(0.0, 1.0) = 0.55;
uniform float opacity : hint_range(0.0, 1.0) = 1.0;

void fragment() {
	vec2 uv = UV;
	// Diagonal axis, slowly drifting so the gradient never looks static.
	float diag = (uv.x + uv.y) * 0.5 + TIME * drift_speed;
	float wave = sin(diag * 3.14159) * 0.5 + 0.5;

	vec3 base = mix(color_a.rgb, color_b.rgb, wave);

	// Cool accent glow rising from the bottom edge — reads as a horizon glow.
	float edge_glow = smoothstep(1.0, 0.35, uv.y) * 0.35;
	base = mix(base, color_edge.rgb, edge_glow);

	// Vignette: darkens corners so the panel content pops center-frame.
	vec2 centered = uv - 0.5;
	float vign = smoothstep(0.25, 0.9, dot(centered, centered) * 2.0) * vignette_amount;
	base *= (1.0 - vign);

	// Faint horizontal scanlines for the "viewed through a screen" read.
	float scan = sin(uv.y * 480.0) * 0.5 + 0.5;
	base -= scan * scanline_amount;

	COLOR = vec4(base, opacity);
}
