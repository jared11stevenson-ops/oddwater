shader_type spatial;
// The ground: vertex colour from the land (sand, grass, forest, rock, snow), broken up with soft patches and a fine speckle so
// big flat areas still read as grass. Matte, no specular.
varying vec3 wp;

float h21(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vnoise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h21(i), h21(i + vec2(1, 0)), f.x), mix(h21(i + vec2(0, 1)), h21(i + vec2(1, 1)), f.x), f.y);
}

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 c = COLOR.rgb;
	float n = vnoise(wp.xz * 0.045) * 0.55 + vnoise(wp.xz * 0.21) * 0.3 + vnoise(wp.xz * 1.1) * 0.15;
	c *= 0.8 + n * 0.4;
	c = mix(c, c * vec3(1.08, 0.98, 0.78), smoothstep(0.55, 0.8, vnoise(wp.xz * 0.09 + 7.0)) * 0.55);   // dry, warmer patches
	c *= 0.955 + h21(floor(wp.xz * 2.2)) * 0.09;      // speckle
	ALBEDO = c;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}
