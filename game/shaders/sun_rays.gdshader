shader_type canvas_item;

// Vệt nắng — posterized diagonal sun shafts. Continuous noise is
// skewed into 2.5D projection and chopped into pixel-locked bands so
// the light reads as authored pixel art, not a smooth gradient.

uniform sampler2D screen_texture : hint_screen_texture, filter_nearest;
uniform sampler2D noise_tex : hint_default_black, repeat_enable, filter_nearest;

uniform vec4 ray_color : source_color = vec4(1.0, 0.88, 0.65, 0.2);
uniform float ray_speed : hint_range(0.0, 0.2) = 0.03;
uniform float ray_angle : hint_range(-1.5, 1.5) = -0.4;
uniform vec2 ray_density = vec2(0.3, 0.05);
uniform float posterize_steps : hint_range(2.0, 16.0) = 5.0;
uniform float intensity : hint_range(0.0, 1.0) = 1.0;

void fragment() {
	vec4 base = texture(screen_texture, SCREEN_UV);
	if (intensity <= 0.001) {
		COLOR = base;
	} else {
		vec2 skewed_uv = SCREEN_UV;
		skewed_uv.x += skewed_uv.y * ray_angle;
		skewed_uv.x -= TIME * ray_speed;
		skewed_uv.y += TIME * (ray_speed * 0.2);
		float noise = texture(noise_tex, skewed_uv * ray_density).r;
		float pixelated = floor(noise * posterize_steps) / posterize_steps;
		float ray_mask = smoothstep(0.2, 0.8, pixelated);
		vec3 light_mix = base.rgb
			+ (ray_color.rgb * ray_mask * ray_color.a * intensity);
		COLOR = vec4(light_mix, base.a);
	}
}
