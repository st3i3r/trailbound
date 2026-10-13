shader_type canvas_item;

// Sương mù — two counter-scrolling noise fields multiplied together
// give fog banks with real structure: pockets that thin out and
// patches that gather. Posterized so the mist edge steps in pixels.

uniform sampler2D screen_texture : hint_screen_texture, filter_nearest;
uniform sampler2D fog_noise_1 : hint_default_black, repeat_enable, filter_nearest;
uniform sampler2D fog_noise_2 : hint_default_black, repeat_enable, filter_nearest;

uniform vec4 fog_color : source_color = vec4(0.8, 0.85, 0.9, 1.0);
uniform vec2 scroll_speed_1 = vec2(0.015, 0.005);
uniform vec2 scroll_speed_2 = vec2(-0.008, 0.012);
uniform float intensity : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec4 base = texture(screen_texture, SCREEN_UV);
	if (intensity <= 0.001) {
		COLOR = base;
	} else {
		vec2 uv1 = SCREEN_UV + TIME * scroll_speed_1;
		float n1 = texture(fog_noise_1, uv1 * 0.4).r;
		vec2 uv2 = SCREEN_UV + TIME * scroll_speed_2;
		float n2 = texture(fog_noise_2, uv2 * 0.6).r;
		float combined = n1 * n2;
		combined = floor(combined * 6.0) / 6.0;
		float a = smoothstep(0.1, 0.7, combined) * intensity * 0.4;
		COLOR = vec4(mix(base.rgb, fog_color.rgb, a), base.a);
	}
}
