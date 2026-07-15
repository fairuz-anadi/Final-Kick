// Ghost/rewind material. Applied to the ball while scrubbing time
// so the "this is a replay, not the real attempt" state reads instantly —
// translucent body with a bright fresnel rim, like a hologram of the past.
shader_type spatial;
render_mode unshaded, blend_mix, cull_back, depth_draw_opaque;

uniform vec4 ghost_color : source_color = vec4(0.416, 0.549, 0.686, 0.3);
uniform float fresnel_power : hint_range(0.5, 8.0) = 2.5;

void fragment() {
	float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), fresnel_power);
	ALBEDO = ghost_color.rgb;
	ALPHA = clamp(ghost_color.a + fresnel * 0.6, 0.0, 1.0);
	EMISSION = ghost_color.rgb * fresnel * 1.5;
}
