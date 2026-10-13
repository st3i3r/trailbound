shader_type canvas_item;

// Làn gió — advection gusts. A scrolling noise field nudges the
// ground pixels horizontally so grass and paths shimmer as wind
// waves pass; y-sorted props/actors above this overlay stay crisp.
// Screen-space variant (ours reads screen_texture like ripples —
// there is no per-tile TEXTURE to warp).

uniform sampler2D screen_texture : hint_screen_texture, filter_nearest;
uniform sampler2D noise_tex : hint_default_black, repeat_enable;
uniform float wind_speed : hint_range(0.1, 5.0) = 1.2;
uniform float intensity : hint_range(0.0, 0.1) = 0.0;

void fragment() {
	if (intensity <= 0.0001) {
		COLOR = texture(screen_texture, SCREEN_UV);
	} else {
		vec2 wave_uv = SCREEN_UV;
		wave_uv.x -= TIME * wind_speed;
		float n = texture(noise_tex, wave_uv * vec2(0.2, 1.0)).r;
		vec2 duv = SCREEN_UV;
		duv.x += (n - 0.5) * intensity;
		COLOR = texture(screen_texture, duv);
	}
}
