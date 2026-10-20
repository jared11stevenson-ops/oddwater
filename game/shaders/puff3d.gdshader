shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled;
// Chimney smoke: every puff rises on its own timer straight from the vertex shader (zero CPU), widening and fading, drifting with
// the wind. `amount` is how much of it you see (more on cold, wet mornings and evenings).
uniform float amount : hint_range(0.0, 1.0) = 0.6;
uniform vec3 smoke_col : source_color = vec3(0.82, 0.82, 0.84);
uniform vec2 drift = vec2(1.2, 0.4);
uniform float rise = 3.4;
varying float a;

float h11(float x) { return fract(sin(x * 91.3458) * 47453.5453); }

void vertex() {
	vec3 root = MODEL_MATRIX[3].xyz;
	float seed = h11(root.x * 0.37 + root.z * 0.71 + float(INSTANCE_ID % 8) * 0.13);
	float life = 5.0;
	float t = fract(TIME / life + seed + float(INSTANCE_ID % 4) * 0.25);
	vec3 p = VERTEX * (0.5 + t * 2.2);
	p.y += t * rise;
	p.xz += drift * t * t * 4.0 + vec2(sin(t * 6.0 + seed * 9.0), cos(t * 5.0 + seed * 7.0)) * 0.25 * t;
	VERTEX = p;
	a = (1.0 - t) * smoothstep(0.0, 0.12, t) * amount * 0.55;
	if (root.y < -100.0) a = 0.0;
}

void fragment() {
	ALBEDO = smoke_col;
	ALPHA = a;
}
