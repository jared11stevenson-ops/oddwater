shader_type spatial;
render_mode ambient_light_disabled, specular_disabled;
// INK side of the style: flat spot colour, hard cel step, Ben-Day halftone in the half-shadow,
// and a wet-wash rim that grows with `truth` (the lake bleeding through).

uniform vec4 albedo : source_color = vec4(0.9, 0.5, 0.4, 1.0);
uniform vec4 shadow_tint : source_color = vec4(0.35, 0.30, 0.55, 1.0);
uniform vec4 ink_tint : source_color = vec4(0.08, 0.07, 0.11, 1.0);
uniform float halftone_px : hint_range(3.0, 24.0) = 9.0;
uniform float halftone_strength : hint_range(0.0, 1.0) = 0.85;
uniform vec4 wash_color : source_color = vec4(0.18, 0.56, 0.62, 1.0);
uniform float truth : hint_range(0.0, 1.0) = 0.0;

float dots(vec2 frag, float px, float coverage) {
	// 45-degree Ben-Day screen
	vec2 p = mat2(vec2(0.7071, -0.7071), vec2(0.7071, 0.7071)) * frag / px;
	float d = length(fract(p) - 0.5);
	return 1.0 - smoothstep(coverage * 0.62 - 0.05, coverage * 0.62 + 0.05, d);
}

void fragment() {
	ALBEDO = albedo.rgb;
	// wet rim: the lake showing through at grazing angles
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	ALBEDO = mix(ALBEDO, wash_color.rgb, rim * truth * 0.8);
}

void light() {
	float lit = clamp(dot(NORMAL, LIGHT), 0.0, 1.0) * ATTENUATION;
	float full = smoothstep(0.48, 0.52, lit);
	float mid = smoothstep(0.12, 0.16, lit);
	vec3 shade = mix(shadow_tint.rgb, vec3(1.0), full);
	float half_band = mid * (1.0 - full);
	float d = dots(FRAGCOORD.xy, halftone_px, 1.0 - lit * 1.4);
	shade = mix(shade, ink_tint.rgb * 1.6, d * half_band * halftone_strength);
	// deepest shadow: solid ink-leaning colour
	shade = mix(ink_tint.rgb * 2.0, shade, mid);
	DIFFUSE_LIGHT += shade * LIGHT_COLOR / PI;
}
