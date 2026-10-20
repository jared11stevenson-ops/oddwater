shader_type spatial;
// The ground: vertex colour from the land (sand, grass, forest, rock, snow), broken up with soft patches, mown stripes, worn dirt
// and a fine speckle so big flat areas still read as grass. Matte; rain darkens it.
uniform float wet : hint_range(0.0, 1.0) = 0.0;
uniform float night : hint_range(0.0, 1.0) = 0.0;
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
	// grass: darker and less saturated, with slow olive / straw drifts so a big lawn is never one flat green
	float grassy = clamp((c.g - max(c.r, c.b)) * 7.0, 0.0, 1.0);
	float lum = dot(c, vec3(0.299, 0.587, 0.114));
	vec3 g = mix(vec3(lum), c, 0.74) * 0.8;
	float drift = vnoise(wp.xz * 0.022 + 11.0) * 0.6 + vnoise(wp.xz * 0.075 + 3.0) * 0.4;
	g = mix(g * vec3(0.8, 0.9, 0.72), g * vec3(1.14, 1.03, 0.8), smoothstep(0.3, 0.7, drift));
	g *= 0.9 + 0.2 * vnoise(wp.xz * 0.5 + 19.0);
	// outside the streets: a patchwork of small fields (pasture, stubble, plough, crop rows) with dark hedge lines between them
	float out_k = max(smoothstep(430.0, 500.0, abs(wp.x)), smoothstep(405.0, 450.0, wp.z)) * (1.0 - smoothstep(14.0, 50.0, wp.y)) * smoothstep(0.9, 0.99, wn.y);
	if (out_k > 0.001) {
		vec2 q = wp.xz / vec2(46.0, 38.0) + vec2(h21(floor(wp.xz / 300.0)) * 3.0);
		vec2 fid = floor(q);
		vec2 ff = fract(q);
		float hf = h21(fid);
		vec3 crop = g;
		if (hf < 0.22) { crop = vec3(0.27, 0.215, 0.085); }                  // wheat stubble
		else if (hf < 0.4) { crop = vec3(0.15, 0.1, 0.065); }                // ploughed earth
		else if (hf < 0.58) { crop = vec3(0.11, 0.2, 0.06); }                // young crop
		else if (hf < 0.72) { crop = g * vec3(1.15, 1.1, 0.85); }            // hay meadow
		float rows = step(0.5, fract((wp.z + hf * 9.0) / 1.7));
		float row_fade = 1.0 - smoothstep(25.0, 90.0, dist);
		crop *= 1.0 + (rows - 0.5) * 0.16 * row_fade * step(0.22, hf) * step(hf, 0.58);
		float edge = min(min(ff.x * 46.0, (1.0 - ff.x) * 46.0), min(ff.y * 38.0, (1.0 - ff.y) * 38.0));
		crop = mix(vec3(0.07, 0.13, 0.05), crop, smoothstep(0.7, 2.6, edge));
		crop *= 0.92 + 0.16 * vnoise(wp.xz * 0.3);
		g = mix(g, crop, 0.85 * out_k);
	}
	c = mix(c, g, grassy);
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
	EMISSION = c * 0.16 * (1.0 - night);
	ROUGHNESS = mix(1.0, 0.7, wet);
	SPECULAR = 0.0;
}
