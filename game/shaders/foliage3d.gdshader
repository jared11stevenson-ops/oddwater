shader_type spatial;
render_mode cull_disabled;
// Trees, shrubs, reeds and grass tufts: baked vertex colour (sRGB) times a per-instance tint, swaying in the wind. Sway grows with
// height above the root; tufts and reeds bend more. `wind` is raised by the sky in rain/fog/storms.
uniform float wind : hint_range(0.0, 2.0) = 0.6;
uniform float sway_amp = 0.03;
uniform float wet : hint_range(0.0, 1.0) = 0.0;
varying vec3 vcol;
vec3 s2l(vec3 c) { return mix(pow((c + 0.055) / 1.055, vec3(2.4)), c / 12.92, step(c, vec3(0.04045))); }

void vertex() {
	vec3 root = MODEL_MATRIX[3].xyz;
	float ph = root.x * 0.11 + root.z * 0.17;
	float h = max(VERTEX.y, 0.0);
	float k = sway_amp * wind * h * h * 0.12 + sway_amp * wind * h * 0.25;
	VERTEX.x += sin(TIME * 1.3 + ph + VERTEX.y * 0.4) * k;
	VERTEX.z += cos(TIME * 1.0 + ph * 1.3 + VERTEX.x * 0.3) * k * 0.7;
	vcol = COLOR.rgb;
}

void fragment() {
	vec3 c = s2l(clamp(vcol, 0.0, 1.0)) * (1.0 - 0.15 * wet);
	ALBEDO = c;
	ROUGHNESS = 0.9;
	SPECULAR = 0.1;
	// cull_disabled: make the back face light like the front
	if (!FRONT_FACING) { NORMAL = -NORMAL; }
}
