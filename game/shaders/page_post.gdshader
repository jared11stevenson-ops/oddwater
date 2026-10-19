shader_type canvas_item;
// The whole screen is a printed page. Full-screen post, one pass, mobile-cheap.
//   hush  1.0 = plates in perfect register, clean offset print (the town's surface)
//         0.0 = CMYK plates drift, halftone shows, paper shows through
//   truth 0.0 = pure comic ink       1.0 = the lake's anime wash bleeds into the ink
//   impact    comic burst speed lines (hits, reveals, the 4:12 Take)

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float hush : hint_range(0.0, 1.0) = 1.0;
uniform float truth : hint_range(0.0, 1.0) = 0.0;
uniform float impact : hint_range(0.0, 1.0) = 0.0;
uniform vec4 paper : source_color = vec4(0.953, 0.914, 0.824, 1.0);
uniform vec4 ink : source_color = vec4(0.08, 0.07, 0.11, 1.0);
uniform vec4 water : source_color = vec4(0.18, 0.56, 0.62, 1.0);
uniform float grain : hint_range(0.0, 0.2) = 0.06;
uniform float levels : hint_range(2.0, 12.0) = 6.0;
uniform float vignette : hint_range(0.0, 1.0) = 0.35;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

vec3 sample_misreg(vec2 uv, vec2 px, float amt) {
	// separate "plates": each channel is printed with a slight offset
	float r = texture(screen_tex, uv + vec2(amt, -amt * 0.5) * px).r;
	float g = texture(screen_tex, uv).g;
	float b = texture(screen_tex, uv + vec2(-amt * 0.7, amt) * px).b;
	return vec3(r, g, b);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 px = SCREEN_PIXEL_SIZE;
	float drift = (1.0 - hush) * 7.0;
	vec3 col = sample_misreg(uv, px, drift);

	// wash: soft mip-blurred colour bleeding past the lines, tinted by the water
	vec3 soft = textureLod(screen_tex, uv, 3.0).rgb;
	soft = mix(soft, soft * vec3(0.8, 1.05, 1.1) + water.rgb * 0.15, 0.6);
	float lum = dot(col, vec3(0.299, 0.587, 0.114));
	float ink_edge = 1.0 - smoothstep(0.08, 0.22, lum);   // keep the black lines crisp
	col = mix(col, mix(col, soft, 0.75), truth * (1.0 - ink_edge));
	col = mix(vec3(dot(col, vec3(0.333))), col, 1.0 + truth * 0.35);

	// offset-print posterisation, softened as the truth comes out
	float lv = mix(levels, 24.0, truth);
	float pl = dot(col, vec3(0.299, 0.587, 0.114));
	float ql = floor(pl * lv + 0.5) / lv;
	col *= (ql + 0.0001) / (pl + 0.0001);   // posterise brightness only: keeps hue honest

	// paper
	vec2 gp = FRAGCOORD.xy;
	float n = hash(floor(gp / 2.0)) - 0.5;
	col *= mix(vec3(1.0), paper.rgb, 0.3);
	col += n * grain * (1.0 + (1.0 - hush) * 1.5);

	// vignette toward ink
	float v = smoothstep(0.35, 1.05, length(uv - 0.5) * 1.35);
	col = mix(col, ink.rgb, v * vignette * 0.55);

	// speed lines
	vec2 c = uv - 0.5;
	c.x *= 1.0 / (SCREEN_PIXEL_SIZE.x / SCREEN_PIXEL_SIZE.y);
	float ang = atan(c.y, c.x);
	float rays = step(0.62, hash(vec2(floor(ang * 60.0), 3.0)));
	float rad = smoothstep(0.22, 0.75, length(c));
	col = mix(col, ink.rgb, rays * rad * impact * 0.9);

	COLOR = vec4(col, 1.0);
}
