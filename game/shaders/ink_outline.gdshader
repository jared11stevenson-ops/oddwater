shader_type spatial;
render_mode cull_front, unshaded;
// Inverted-hull ink line, constant on-screen weight. Use as next_pass of a toon material.
// `wobble` makes the line breathe: understudies and the Held are drawn with a wet, unsteady line.

uniform vec4 line_color : source_color = vec4(0.08, 0.07, 0.11, 1.0);
uniform float width : hint_range(0.0, 0.02) = 0.0035;
uniform float wobble : hint_range(0.0, 1.0) = 0.0;

void vertex() {
	vec4 clip = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	vec3 n = normalize((MODELVIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vec2 dir = normalize((PROJECTION_MATRIX * vec4(n, 0.0)).xy + vec2(0.0001));
	float w = width * (1.0 + wobble * 0.8 * sin(TIME * 3.0 + VERTEX.y * 9.0 + VERTEX.x * 7.0));
	clip.xy += dir * w * clip.w;
	POSITION = clip;
}

void fragment() {
	ALBEDO = line_color.rgb;
}
