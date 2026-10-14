shader_type canvas_item;

// Post-grade — the single screen pass that shapes tone (research:
// Pixpil lights Eastward with discrete pools + atmosphere and is
// "careful not to destroy the original art" — so this pass never
// tints the frame; it restores contrast, split-tones shadows cool /
// highlights warm, and vignettes the edges).  Exposure stays in
// CanvasModulate (real light change); this pass is tonal shaping.
uniform sampler2D screen_texture : hint_screen_texture,
    repeat_disable, filter_nearest;

uniform float dusk = 0.0;        // WorldFX scalar, driven per-frame
uniform float front = 0.0;       // storm severity (reserved)

uniform vec3 shadow_tint : source_color = vec3(0.16, 0.20, 0.42);
uniform vec3 high_tint   : source_color = vec3(1.0, 0.96, 0.62);
uniform float contrast_amt = 0.13;
uniform float split_amt    = 0.07;
uniform float sat_amt      = 0.97;   // filmic pull-down: authored art
uniform float vignette_amt = 0.16;   // runs ~0.55 sat; Eastward refs
                                     // grade to 0.45-0.53 — the pass
                                     // lands the composite in-band
float luma(vec3 c) { return dot(c, vec3(0.299, 0.587, 0.114)); }

void fragment() {
	vec3 c = textureLod(screen_texture, SCREEN_UV, 0.0).rgb;
	float l = luma(c);
	// gentle S-curve — the contrast a multiply can never add
	vec3 sc = c * c * (3.0 - 2.0 * c);
	c = mix(c, sc, contrast_amt + dusk * 0.10);
	// split-tone: cool indigo shadows, warm lamp highlights;
	// the warm side grows at dusk — golden hour as a HIGHLIGHT
	// response, not a film over the whole frame
	float amt = split_amt * (0.55 + dusk * 0.9);
	c = mix(c, shadow_tint, (1.0 - smoothstep(0.0, 0.55, l)) * amt);
	c = mix(c, high_tint, smoothstep(0.45, 1.0, l) * amt
		* (0.5 + dusk * 0.9));
	// mild saturation floor so midday never reads grey
	c = mix(vec3(luma(c)), c, sat_amt);
	// painted-edge vignette — deeper as dark falls
	vec2 d = SCREEN_UV - 0.5;
	c *= 1.0 - vignette_amt * (0.55 + dusk * 0.9)
		* smoothstep(0.42, 0.92, length(d) * 1.414);
	COLOR = vec4(c, 1.0);
}
