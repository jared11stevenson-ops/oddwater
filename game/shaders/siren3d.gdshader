shader_type spatial;
render_mode unshaded;
// A police light bar: red and blue taking turns.
uniform vec3 col_a : source_color = vec3(1.0, 0.1, 0.1);
uniform vec3 col_b : source_color = vec3(0.15, 0.3, 1.0);
uniform float side = 0.0;
void fragment() {
	float on = step(0.5, fract(TIME * 2.2 + side * 0.5));
	vec3 c = side < 0.5 ? col_a : col_b;
	ALBEDO = c * (0.25 + 0.9 * on);
	EMISSION = c * on * 1.6;
}
