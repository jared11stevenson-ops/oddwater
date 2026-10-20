shader_type canvas_item;
// A soft dark vignette: no screen read, so it costs almost nothing on a phone. Strength follows the weather and the hour.
uniform float strength : hint_range(0.0, 1.0) = 0.25;
uniform vec3 tint : source_color = vec3(0.02, 0.02, 0.05);
void fragment() {
	vec2 p = (UV - 0.5) * vec2(1.25, 1.0);
	float d = length(p) * 1.35;
	float v = smoothstep(0.35, 1.0, d);
	COLOR = vec4(tint, v * v * strength);
}
