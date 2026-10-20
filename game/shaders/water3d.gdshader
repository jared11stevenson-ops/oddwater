shader_type spatial;
render_mode cull_back, specular_schlick_ggx;
// The lake: teal shallows deepening to a dark blue-green, layered ripples that catch the light, a capped fresnel that reflects the
// sky's own horizon colour (never white), glitter that follows the sun or moon, soft foam at the shore and around posts.
uniform vec3 shallow : source_color = vec3(0.17, 0.40, 0.42);
uniform vec3 deep : source_color = vec3(0.02, 0.09, 0.15);
uniform vec3 foam_col : source_color = vec3(0.9, 0.95, 0.93);
uniform vec3 sky_col : source_color = vec3(0.62, 0.78, 0.9);
uniform vec3 glint_col : source_color = vec3(1.0, 0.95, 0.85);
uniform float shore_z = -123.0;
uniform float night : hint_range(0.0, 1.0) = 0.0;
uniform float wet : hint_range(0.0, 1.0) = 0.0;       // rain roughens the lake
uniform float calm : hint_range(0.0, 1.0) = 1.0;      // 1 = glassy, 0 = choppy
uniform float haze : hint_range(0.0, 1.0) = 0.0;      // fog lifts the water toward the sky colour

float h21(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vnoise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h21(i), h21(i + vec2(1, 0)), f.x), mix(h21(i + vec2(0, 1)), h21(i + vec2(1, 1)), f.x), f.y);
}
float ripple(vec2 p, float t) {
	return vnoise(p * 0.7 + vec2(t * 0.11, t * 0.07)) * 0.55 + vnoise(p * 1.9 - vec2(t * 0.17, -t * 0.09)) * 0.3 + vnoise(p * 5.3 + vec2(t * 0.3, t * 0.2)) * 0.15;
}

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float amp = mix(0.05, 0.16, 1.0 - calm);
	VERTEX.y += (sin(wpos.x * 0.21 + TIME * 0.9) * 0.05 + sin(wpos.z * 0.17 + TIME * 0.7) * 0.05) * (amp / 0.05) * 0.5;
}

void fragment() {
	vec2 uv = wpos.xz;
	float t = TIME;
	float e = 0.35;
	float r0 = ripple(uv, t);
	float rx = ripple(uv + vec2(e, 0.0), t);
	float rz = ripple(uv + vec2(0.0, e), t);
	float rough_k = mix(0.55, 1.2, 1.0 - calm) + wet * 0.6;
	vec3 nrm_w = normalize(vec3((r0 - rx) * rough_k * 1.3, 1.0, (r0 - rz) * rough_k * 1.3));
	NORMAL = normalize((VIEW_MATRIX * vec4(nrm_w, 0.0)).xyz);
	float dist = clamp((shore_z - wpos.z) / 70.0, 0.0, 1.0);
	float dd = smoothstep(0.0, 0.85, dist + (r0 - 0.5) * 0.12);
	vec3 col = mix(shallow, deep, pow(dd, 0.7));
	// sandy, lighter water in the first few metres
	float edge = clamp((shore_z - wpos.z) / 7.0, 0.0, 1.0);
	col = mix(vec3(0.5, 0.66, 0.58), col, smoothstep(0.0, 1.0, edge));
	// light and dark bands, like brush strokes
	col *= 0.92 + 0.16 * smoothstep(0.4, 0.8, vnoise(uv * vec2(0.09, 0.31) + vec2(t * 0.02, 0.0)));
	col += vec3(0.05, 0.08, 0.07) * smoothstep(0.55, 0.8, r0);
	// foam at the shore, with a pulse
	float fz = shore_z - wpos.z;
	float pulse = 0.5 + 0.5 * sin(t * 1.1 + wpos.x * 0.21);
	float foam = smoothstep(2.0 + pulse * 0.7, 0.2, fz + (r0 - 0.5) * 2.4);
	foam *= smoothstep(-1.5, 0.3, fz);
	col = mix(col, foam_col, clamp(foam, 0.0, 1.0) * 0.85);
	// fresnel, capped so the far lake never washes to white
	float fres = pow(1.0 - clamp(dot(nrm_w, normalize((INV_VIEW_MATRIX * vec4(VIEW, 0.0)).xyz)), 0.0, 1.0), 4.0);
	col = mix(col, sky_col, clamp(fres, 0.0, 0.4) * mix(0.55, 0.4, night));
	// glitter
	float glit = smoothstep(0.88, 1.0, vnoise(uv * 3.1 + vec2(t * 0.4, -t * 0.3))) * smoothstep(0.45, 0.8, r0);
	col += glint_col * glit * 0.2 * (1.0 - 0.4 * night) * calm;
	col = mix(col, sky_col * 0.9, haze * smoothstep(0.1, 0.8, dist) * 0.45);
	col *= 1.0 - 0.45 * night;
	ALBEDO = col;
	ROUGHNESS = mix(0.14, 0.4, wet + (1.0 - calm) * 0.5);
	SPECULAR = 0.3;
	METALLIC = 0.0;
}
