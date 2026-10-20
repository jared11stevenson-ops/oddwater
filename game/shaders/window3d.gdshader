shader_type spatial;
// Windows and lamps: dull glass by day, warm light at night. Per-instance alpha = "someone is home".
uniform float night : hint_range(0.0, 1.0) = 0.0;
uniform vec3 lit_col : source_color = vec3(1.0, 0.8, 0.38);

void fragment() {
	float on = step(0.5, COLOR.a) * night;
	vec3 day = mix(vec3(0.38, 0.52, 0.62), COLOR.rgb, 0.4);
	ALBEDO = mix(day, lit_col, on);
	EMISSION = lit_col * on * 1.6;
	ROUGHNESS = 0.3;
}
