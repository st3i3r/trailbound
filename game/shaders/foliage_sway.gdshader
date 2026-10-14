shader_type canvas_item;

// Foliage sway — reads the global wind scalar WorldFX declares
// (global_wind_speed: ~0.8 calm baseline .. ~4.2 storm).  Applied to
// tuft/fern/flower/overgrowth sprites: the TOP of the blade sways,
// the root stays planted.  Phase is derived from world position so
// a row of tufts never waves in hive-mind unison.
global uniform float global_wind_speed;
uniform float amp = 1.1;        // local px at the tip on a calm day
uniform float freq = 1.9;

void vertex() {
	float w = global_wind_speed;                  // 0.8 .. 4.2
	// UV.y = 1 at the sprite bottom (the root) -> 0 sway there
	float mask = clamp(1.0 - UV.y, 0.0, 1.0);
	vec2 wp = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
	float ph = wp.x * 0.11 + wp.y * 0.07;         // world-pos phase
	float gust = sin(TIME * freq * (0.6 + w * 0.28) + ph)
	           + 0.5 * sin(TIME * freq * 1.73 + ph * 1.3);
	VERTEX.x += gust * amp * (0.55 + w * 0.55) * mask * 0.5;
}
