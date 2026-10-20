shader_type spatial;
// The town's solid stuff in one material: vertex colour is the paint, vertex alpha says what the surface is made of.
// ids (alpha * 10): 10 plain, 9 siding, 8 brick, 7 plaster, 6 roof shingle, 5 asphalt, 4 paving, 3 lawn, 2 planks, 1 metal.
// Everything gets a dirty skirt near the ground, and rain wets it (darker, shinier, puddles on the road).
uniform float wet : hint_range(0.0, 1.0) = 0.0;
uniform vec3 sky_col : source_color = vec3(0.7, 0.8, 0.9);
uniform float night : hint_range(0.0, 1.0) = 0.0;

varying vec3 wp;
varying vec3 wn;
varying vec3 vcol;
varying float pid;

float h21(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vnoise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h21(i), h21(i + vec2(1, 0)), f.x), mix(h21(i + vec2(0, 1)), h21(i + vec2(1, 1)), f.x), f.y);
}
vec3 s2l(vec3 c) { return mix(pow((c + 0.055) / 1.055, vec3(2.4)), c / 12.92, step(c, vec3(0.04045))); }

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wn = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vcol = COLOR.rgb;
	pid = COLOR.a;
}

void fragment() {
	int id = int(pid * 10.0 + 0.5);
	vec3 c = s2l(vcol);
	float rough = 0.92;
	float spec = 0.12;
	bool vert = abs(wn.y) < 0.5;
	vec2 hz = normalize(vec2(-wn.z, wn.x) + vec2(0.0001, 0.0));       // along the wall
	float along = dot(wp.xz, hz);
	float grain = vnoise(wp.xz * 7.0 + wp.y * 5.0);
	if (id == 0) {
		float u = fract(along / 0.2);
		float picket = step(u, 0.62) * step(wp.y, 0.97);
		float rail = step(abs(wp.y - 0.26), 0.05) + step(abs(wp.y - 0.66), 0.05);
		if (picket + rail < 0.5) { discard; }
		c *= 0.95 + 0.07 * h21(vec2(floor(along / 0.2), 3.0));
	} else if (id == 9 && vert) {
		float u = wp.y * 3.4;
		float f = fract(u);
		float board = floor(u);
		c *= 0.93 + 0.1 * h21(vec2(board, floor(along * 0.45)));
		c *= 1.0 - 0.22 * (1.0 - smoothstep(0.0, 0.16, f)) ;
		c *= 1.0 + 0.06 * smoothstep(0.7, 1.0, f);
	} else if (id == 8 && vert) {
		float row = floor(wp.y / 0.095);
		float u = along / 0.24 + 0.5 * mod(row, 2.0);
		vec2 bf = vec2(fract(u), fract(wp.y / 0.095));
		float mortar = step(bf.x, 0.06) + step(bf.y, 0.1);
		vec2 bid = vec2(floor(u), row);
		c *= 0.82 + 0.3 * h21(bid);
		c = mix(c, vec3(0.62, 0.6, 0.56), clamp(mortar, 0.0, 1.0) * 0.8);
		rough = 0.95;
	} else if (id == 7) {
		c *= 0.9 + 0.2 * vnoise(wp.xz * 3.0 + wp.y * 3.0) + 0.06 * (grain - 0.5);
	} else if (id == 6) {
		float row = floor(wp.y * 4.2 + wp.x * 0.0 + wp.z * 0.0);
		float f = fract(wp.y * 4.2);
		float u = along * 1.7 + 0.5 * mod(row, 2.0);
		c *= 0.88 + 0.2 * h21(vec2(floor(u), row));
		c *= 1.0 - 0.18 * (1.0 - smoothstep(0.0, 0.2, f));
		if (!vert && wn.y > 0.95) {   // flat roofs: gravel
			c *= 0.9 + 0.2 * grain;
		}
	} else if (id == 5) {
		float n = vnoise(wp.xz * 0.9) * 0.5 + vnoise(wp.xz * 5.0) * 0.3 + vnoise(wp.xz * 21.0) * 0.2;
		c *= 0.82 + 0.3 * n;
		c *= 1.0 + 0.1 * (smoothstep(0.6, 0.66, vnoise(wp.xz * 0.15 + 9.0)) - 0.5);       // patched, repaired stretches
		float pud = smoothstep(0.52, 0.64, vnoise(wp.xz * 0.28 + 3.0)) * wet;
		c = mix(c * (1.0 - 0.35 * wet), c * 0.45, pud);
		rough = mix(0.9, 0.12, max(pud, wet * 0.45));
		spec = mix(0.08, 0.9, max(pud, wet * 0.4));
	} else if (id == 4) {
		vec2 g = fract(wp.xz / 1.5);
		float line = step(g.x, 0.025) + step(g.y, 0.025);
		c *= 0.9 + 0.12 * h21(floor(wp.xz / 1.5));
		c *= 1.0 - 0.14 * clamp(line, 0.0, 1.0);
		c *= 1.0 - 0.1 * wet;
		rough = mix(0.9, 0.45, wet);
	} else if (id == 3) {
		float n = vnoise(wp.xz * 0.35) * 0.6 + vnoise(wp.xz * 1.9) * 0.4;
		float lum = dot(c, vec3(0.299, 0.587, 0.114));
		c = mix(vec3(lum), c, 0.72) * 0.78;
		float drift = vnoise(wp.xz * 0.06 + 5.0);
		c = mix(c * vec3(0.82, 0.92, 0.76), c * vec3(1.14, 1.04, 0.82), smoothstep(0.3, 0.7, drift));
		c *= 0.8 + 0.4 * n;
		c *= 0.94 + 0.12 * h21(floor(wp.xz * 3.0));
	} else if (id == 2) {
		float across = wp.z;
		float u = fract(along * 1.0 / 0.28);
		c *= 0.9 + 0.12 * h21(floor(vec2(along / 0.28, wp.y * 2.0)));
		c *= 1.0 - 0.28 * (1.0 - smoothstep(0.0, 0.06, u)) * (vert ? 0.0 : 1.0);
		c *= 0.95 + 0.1 * vnoise(vec2(along * 9.0, wp.y * 2.0 + wp.x * 0.1));
		rough = 0.8;
	} else if (id == 1) {
		rough = 0.5; spec = 0.5;
	}
	// dirt at the foot of everything, and a little ambient occlusion in the corners near the ground
	float foot = 1.0 - smoothstep(0.0, 0.9, wp.y);
	if (vert && id != 5 && id != 4) {
		c = mix(c, c * vec3(0.62, 0.58, 0.5), foot * 0.55);
	}
	c *= 1.0 - 0.18 * wet * (id <= 9 ? 1.0 : 0.0);
	ALBEDO = c;
	EMISSION = c * 0.22 * (1.0 - night) * (1.0 - 0.5 * wet);       // a soft sky fill so the shaded side of anything is never pitch black
	ROUGHNESS = mix(rough, rough * 0.55, wet);
	SPECULAR = spec;
}
