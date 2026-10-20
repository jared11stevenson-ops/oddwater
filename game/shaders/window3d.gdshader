shader_type spatial;
render_mode cull_disabled;
// Windows: a white frame and mullions, dull sky-tinted glass by day, curtains and warm light at night. Vertex alpha is the
// "lights come on when night passes this value" threshold (0 = nobody home). A few have a flickering blue TV. Up close the glow
// fades back so a lit pane never fills the screen with flat yellow.
uniform float night : hint_range(0.0, 1.0) = 0.0;
uniform vec3 lit_col : source_color = vec3(1.0, 0.78, 0.4);
uniform vec3 sky_col : source_color = vec3(0.55, 0.7, 0.85);
// Who is home: a coarse top-down map of the town, one texel per ~1.5 m, red = somebody alive is home in the lot under this window.
// home_rect = (min x, min z, 1/size x, 1/size z). The default (white, 1x1) means "everyone is home", the old behaviour.
uniform sampler2D home_map : filter_nearest, hint_default_white;
uniform vec4 home_rect = vec4(0.0, 0.0, 0.0, 0.0);

varying vec3 wp;
varying vec3 vcol;
varying float thr;

float h21(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
vec3 s2l(vec3 c) { return mix(pow((c + 0.055) / 1.055, vec3(2.4)), c / 12.92, step(c, vec3(0.04045))); }

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vcol = COLOR.rgb;
	thr = COLOR.a;
}

void fragment() {
	vec2 uv = UV;
	float key = h21(floor(wp.xz * 0.5) + floor(wp.y * 0.4));
	// frame + cross
	vec2 e = min(uv, 1.0 - uv);
	float frame = 1.0 - step(0.1, min(e.x, e.y));
	float cross_ = step(abs(uv.x - 0.5), 0.028) + step(abs(uv.y - 0.5), 0.022);
	float bar = clamp(frame + cross_ * step(0.45, key), 0.0, 1.0);
	float home = home_rect.z > 0.0 ? texture(home_map, (wp.xz - home_rect.xy) * home_rect.zw).r : 1.0;
	float on = (thr > 0.04 && night > thr * 0.85 && home > 0.5) ? 1.0 : 0.0;
	float tv = step(0.88, h21(vec2(thr * 91.0, key * 13.0)));
	float flick = tv > 0.5 ? (0.6 + 0.4 * sin(TIME * 7.0 + key * 40.0) * sin(TIME * 3.1 + key * 9.0)) : 1.0;
	vec3 curt = s2l(vcol);
	// curtain: a band over the top third, drawn to one side
	float cm = step(uv.y, 0.28 + 0.2 * key) * 0.8 + step(abs(uv.x - 0.5), 0.5 - 0.2 * key) * 0.0;
	vec3 glass_day = mix(sky_col * 0.55, vec3(0.12, 0.17, 0.22), uv.y * 0.6);
	glass_day += 0.18 * smoothstep(0.55, 0.45, abs(uv.x + uv.y - 1.0));       // a reflected streak
	vec3 room = mix(lit_col, curt * 1.5 + 0.2, cm * 0.55);
	room = mix(room, vec3(0.35, 0.55, 1.0) * (0.7 + 0.3 * flick), tv * 0.7);
	float depth_fade = smoothstep(1.2, 5.0, -VERTEX.z);
	vec3 col = mix(glass_day * (1.0 - 0.5 * night), room * (0.55 + 0.45 * depth_fade), on);
	col = mix(col, vec3(0.88, 0.88, 0.84), bar);
	ALBEDO = col;
	EMISSION = room * on * (1.0 - bar) * mix(0.45, 1.5, depth_fade) * flick;
	ROUGHNESS = mix(0.25, 0.8, bar);
	SPECULAR = mix(0.9, 0.2, bar);
}
