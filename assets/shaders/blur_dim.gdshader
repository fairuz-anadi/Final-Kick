// Menu backdrop (Samprity): cheap background blur (mip sample) + dim, used by
// the pause and result screens so gameplay softens behind the panel.
shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float blur_lod : hint_range(0.0, 5.0) = 2.2;
uniform float dim : hint_range(0.0, 1.0) = 0.55;

void fragment() {
	vec3 blurred = textureLod(screen_tex, SCREEN_UV, blur_lod).rgb;
	COLOR = vec4(blurred * (1.0 - dim), 1.0);
}
