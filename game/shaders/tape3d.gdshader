shader_type spatial;
render_mode unshaded, cull_disabled;
// Crime-scene tape: diagonal yellow and black stripes along the ribbon, fluttering a little in the wind.
uniform float flutter = 0.03;
varying float along;
void vertex() {
	along = UV.x;
	VERTEX.y += sin(TIME * 2.2 + UV.x * 18.0) * flutter * (1.0 - abs(UV.x - 0.5) * 1.6) * (UV.y - 0.5);
	VERTEX.z += sin(TIME * 1.7 + UV.x * 11.0) * flutter * 0.6;
}
void fragment() {
	float s = fract((UV.x * 60.0) + UV.y * 1.2);
	vec3 c = mix(vec3(0.96, 0.78, 0.08), vec3(0.08, 0.07, 0.1), step(0.5, s));
	ALBEDO = c;
}
