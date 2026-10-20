shader_type spatial;
// The ground: vertex colour from the land (sand, grass, forest, rock, snow), broken up with soft patches, mown stripes, worn dirt
// and a fine speckle so big flat areas still read as grass. Matte; rain darkens it.
uniform float wet : hint_range(0.0, 1.0) = 0.0;
varying vec3 wp;
varying vec3 wn;

float h21(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vnoise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h21(i), h21(i + vec2(1, 0)), f.x), mix(h21(i + vec2(0, 1)), h21(i + vec2(1, 1)), f.x), f.y);
}

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wn = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 c = COLOR.rgb;
	float dist = -VERTEX.z;
	float n = vnoise(wp.xz * 0.045) * 0.5 + vnoise(wp.xz * 0.21) * 0.3 + vnoise(wp.xz * 1.1) * 0.12 + vnoise(wp.xz * 4.7) * 0.08;
	c *= 0.78 + n * 0.46;
	// dry, warmer patches and lush, bluer ones
	float dry = smoothstep(0.55, 0.8, vnoise(wp.xz * 0.09 + 7.0));
	float lush = smoothstep(0.6, 0.85, vnoise(wp.xz * 0.06 + 31.0));
	c = mix(c, c * vec3(1.1, 0.99, 0.74), dry * 0.55);
	c = mix(c, c * vec3(0.86, 1.03, 0.9), lush * 0.4);
	// long mown stripes on the flat (the town plateau)
	float flat_k = smoothstep(0.96, 1.0, wn.y);
	c *= 1.0 + flat_k * 0.045 * (step(0.5, fract(wp.x / 7.0)) - 0.5);
	// the fine speckle fades with distance so it doesn't shimmer
	float sp = h21(floor(wp.xz * 2.4));
	c *= mix(0.955 + sp * 0.09, 1.0, smoothstep(30.0, 140.0, dist));
	c *= 1.0 - 0.28 * wet;
	ALBEDO = c;
	ROUGHNESS = mix(1.0, 0.7, wet);
	SPECULAR = 0.0;
}
