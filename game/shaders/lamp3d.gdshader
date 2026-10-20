shader_type spatial;
render_mode unshaded;
// Lamp heads and porch lights: a pale bulb by day, a hot warm one at night.
uniform float night : hint_range(0.0, 1.0) = 0.0;
uniform vec3 lit_col : source_color = vec3(1.0, 0.82, 0.45);
varying vec3 vcol;
vec3 s2l(vec3 c) { return mix(pow((c + 0.055) / 1.055, vec3(2.4)), c / 12.92, step(c, vec3(0.04045))); }
void vertex() { vcol = COLOR.rgb; }
void fragment() {
	ALBEDO = mix(s2l(vcol) * 0.8, lit_col * 1.4, night);
}
