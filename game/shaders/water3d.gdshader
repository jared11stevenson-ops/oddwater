shader_type spatial;
render_mode cull_disabled, specular_schlick_ggx;
// The lake: soft layered teal, drifting ripples, bright sparkles, foam at the shore. Stylised, not simulated.

uniform vec3 shallow : source_color = vec3(0.36, 0.72, 0.74);
uniform vec3 deep : source_color = vec3(0.09, 0.36, 0.5);
uniform vec3 foam_col : source_color = vec3(0.95, 0.98, 0.97);
uniform float shore_z = -123.0;
uniform float night = 0.0;

float h21(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vnoise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h21(i), h21(i + vec2(1, 0)), f.x), mix(h21(i + vec2(0, 1)), h21(i + vec2(1, 1)), f.x), f.y);
}

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	VERTEX.y += sin(wpos.x * 0.21 + TIME * 0.9) * 0.05 + sin(wpos.z * 0.17 + TIME * 0.7) * 0.05;
}

void fragment() {
	vec2 uv = wpos.xz;
	float n1 = vnoise(uv * 0.18 + vec2(TIME * 0.05, TIME * 0.03));
	float n2 = vnoise(uv * 0.55 - vec2(TIME * 0.09, TIME * 0.04));
	float d = clamp((shore_z - wpos.z) / 90.0, 0.0, 1.0);
	vec3 col = mix(shallow, deep, smoothstep(0.0, 1.0, d + (n1 - 0.5) * 0.25));
	// bands of lighter water, like a painted lake
	col += 0.06 * smoothstep(0.55, 0.75, n2);
	// sparkles
	float sp = smoothstep(0.93, 1.0, vnoise(uv * 2.4 + TIME * 0.35)) * (1.0 - night * 0.7);
	col += vec3(sp) * 0.5;
	// foam where the water meets the shore
	float fz = (shore_z - wpos.z);
	float foam = smoothstep(2.4, 0.0, fz + (n2 - 0.5) * 1.8) * (0.75 + 0.25 * sin(TIME * 1.3 + wpos.x * 0.3));
	col = mix(col, foam_col, clamp(foam, 0.0, 1.0));
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	col = mix(col, vec3(0.75, 0.9, 1.0), fres * 0.35);
	ALBEDO = col;
	ROUGHNESS = 0.18;
	SPECULAR = 0.6;
	ALPHA = 0.93;
}
