shader_type canvas_item;

// Screen-space storm ripples — warps the pixels drawn BELOW this
// overlay (the painted ground + tint) so rain impacts read on grass,
// paths and pond edges while y-sorted props/actors stay crisp on top.
// Cheap: a few sine-wave lookups per pixel, zero nodes spawned.

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;

uniform float ripple_density : hint_range(0.1, 50.0) = 15.0;
uniform float ripple_speed : hint_range(0.5, 10.0) = 3.5;
uniform float ripple_size : hint_range(0.01, 0.2) = 0.05;
uniform float ripple_strength : hint_range(0.001, 0.05) = 0.008;
uniform float storm_intensity : hint_range(0.0, 1.0) = 0.0;

vec2 hash(vec2 p) {
	p = vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)));
	return fract(sin(p) * 43758.5453123);
}

void fragment() {
	if (storm_intensity <= 0.001) {
		COLOR = texture(screen_texture, SCREEN_UV);
	} else {
		vec2 uv = SCREEN_UV;
		vec2 p = uv * ripple_density;
		vec2 ip = floor(p);
		vec2 fp = fract(p);

		vec2 ripple_offset = vec2(0.0);
		for (int y = -1; y <= 1; y++) {
			for (int x = -1; x <= 1; x++) {
				vec2 cell_offset = vec2(float(x), float(y));
				vec2 cell_id = ip + cell_offset;
				vec2 random_center = hash(cell_id);
				float birth_time = fract(TIME * (0.3 + random_center.x * 0.2) + random_center.y);
				vec2 dist_vec = fp - cell_offset - random_center;
				float d = length(dist_vec);
				float current_wave_front = birth_time * 0.8;
				if (d < current_wave_front && d > current_wave_front - ripple_size) {
					float wave = sin((d - current_wave_front) * 31.415) * 0.5 + 0.5;
					float fade = smoothstep(0.0, 0.1, d)
						* smoothstep(current_wave_front, current_wave_front - ripple_size, d)
						* (1.0 - birth_time);
					ripple_offset += (dist_vec / max(d, 0.001))
						* wave * fade * ripple_strength * storm_intensity;
				}
			}
		}
		COLOR = texture(screen_texture, uv + ripple_offset);
	}
}
