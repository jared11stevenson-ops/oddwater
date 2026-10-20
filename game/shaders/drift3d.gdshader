shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled;
// Things that float about near the camera, animated entirely in the vertex shader inside a box that follows the player:
// mode 0 = falling leaves, 1 = fireflies, 2 = birds circling high over the lake, 3 = dust motes.
uniform int mode = 0;
uniform float amount : hint_range(0.0, 1.0) = 1.0;
uniform float box = 36.0;
uniform vec3 tint : source_color = vec3(0.8, 0.5, 0.2);
uniform float time_scale = 1.0;
varying float a;
varying vec3 col;

float h11(float x) { return fract(sin(x * 91.3458) * 47453.5453); }

void vertex() {
	float id = float(INSTANCE_ID);
	float r1 = h11(id + 1.0); float r2 = h11(id * 1.7 + 3.0); float r3 = h11(id * 2.3 + 7.0); float r4 = h11(id * 3.1 + 11.0);
	vec3 centre = MODEL_MATRIX[3].xyz;
	float t = TIME * time_scale;
	vec3 p;
	vec3 local = VERTEX;
	a = amount;
	col = tint;
	if (mode == 0) {
		float fall = mod(t * (0.5 + r4 * 0.5) + r3 * 20.0, 14.0);
		p = vec3((r1 - 0.5) * box + sin(t * 0.7 + r2 * 20.0) * 1.4 + fall * 0.9, 9.0 - fall, (r2 - 0.5) * box + cos(t * 0.6 + r1 * 20.0) * 1.2);
		float s = sin(t * 3.0 + r3 * 40.0);
		local = vec3(local.x * (0.6 + 0.4 * s), local.y, local.z * (0.6 + 0.4 * cos(t * 2.0 + r2 * 9.0)));
		col = mix(tint, tint * vec3(1.2, 1.3, 0.5), r4);
		a *= step(0.0, p.y + 0.2);
		a *= smoothstep(0.0, 0.8, 14.0 - fall);
	} else if (mode == 1) {
		p = vec3((r1 - 0.5) * box + sin(t * 0.5 + r2 * 30.0) * 2.0, 0.6 + r3 * 2.6 + sin(t * 0.9 + r4 * 30.0) * 0.5, (r2 - 0.5) * box + cos(t * 0.45 + r1 * 30.0) * 2.0);
		a *= 0.4 + 0.6 * smoothstep(0.55, 1.0, sin(t * 2.0 + r3 * 40.0) * 0.5 + 0.5);
	} else if (mode == 2) {
		float ang = t * (0.12 + r1 * 0.1) + r2 * 6.283;
		float rad = 40.0 + r3 * 140.0;
		p = vec3(cos(ang) * rad, 28.0 + r4 * 30.0 + sin(t * 0.7 + r1 * 9.0) * 2.0, sin(ang) * rad * 0.7);
		float flap = sin(t * 9.0 + r2 * 30.0);
		local.y += abs(local.x) * 0.9 * flap;
		float c = cos(ang + 1.5708); float s = sin(ang + 1.5708);
		local = vec3(local.x * c - local.z * s, local.y, local.x * s + local.z * c);
		col = vec3(0.07, 0.07, 0.09);
	} else {
		p = vec3((r1 - 0.5) * box, 0.8 + r3 * 5.0, (r2 - 0.5) * box) + vec3(sin(t * 0.3 + r4 * 9.0), sin(t * 0.4 + r1 * 9.0), cos(t * 0.35 + r2 * 9.0)) * 1.2;
		a *= 0.25;
	}
	// wrap into a box around the follower so there are always some about
	vec3 rel = p;
	if (mode != 2) {
		rel.x = mod(rel.x + box * 0.5, box) - box * 0.5;
		rel.z = mod(rel.z + box * 0.5, box) - box * 0.5;
	}
	vec3 world = centre + rel;
	// face the camera (a camera-facing quad), except birds which stay flat-ish
	if (mode == 2) {
		VERTEX = rel + local;
	} else {
		vec3 right = INV_VIEW_MATRIX[0].xyz; vec3 up = INV_VIEW_MATRIX[1].xyz;
		VERTEX = rel + right * local.x + up * local.y;
	}
	// MODEL_MATRIX position is already `centre`; undo it so VERTEX is relative
	a *= 1.0;
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float shape = (mode == 1 || mode == 3) ? clamp(1.0 - length(p), 0.0, 1.0) : 1.0;
	ALBEDO = (mode == 1) ? vec3(0.9, 1.0, 0.45) : col;
	ALPHA = a * shape * smoothstep(1.5, 6.0, -VERTEX.z);
	if (mode == 1) { EMISSION = vec3(0.7, 1.0, 0.4); }
}
