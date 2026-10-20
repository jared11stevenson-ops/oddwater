shader_type sky;
// Sky v2: a gradient with a warm band at the horizon, a sun disc and glow, a moon with a soft halo, twinkling stars at night,
// layered drifting clouds lit from the sun's side, and layered far hills in a blue haze so the horizon is never a hard line.
// Everything is driven by uniforms the SkyCycle sets (no TIME, so the radiance map never needs a realtime update).
uniform vec3 top_col : source_color = vec3(0.24, 0.55, 0.9);
uniform vec3 mid_col : source_color = vec3(0.5, 0.75, 0.95);
uniform vec3 horizon_col : source_color = vec3(0.8, 0.9, 0.96);
uniform vec3 ground_col : source_color = vec3(0.4, 0.5, 0.5);
uniform vec3 glow_col : source_color = vec3(1.0, 0.6, 0.35);
uniform vec3 sun_col : source_color = vec3(1.0, 0.95, 0.8);
uniform vec3 sun_dir = vec3(0.3, 0.6, -0.7);
uniform vec3 moon_dir = vec3(-0.3, 0.6, 0.7);
uniform float sun_vis : hint_range(0.0, 1.0) = 1.0;
uniform float night : hint_range(0.0, 1.0) = 0.0;
uniform float cover : hint_range(0.0, 1.0) = 0.25;       // cloud coverage
uniform float dark : hint_range(0.0, 1.0) = 0.0;         // how grey and heavy the clouds are
uniform float glow_amt : hint_range(0.0, 1.0) = 0.0;     // dusk/dawn glow at the horizon
uniform vec2 scroll = vec2(0.0, 0.0);
uniform vec3 hill_col : source_color = vec3(0.45, 0.58, 0.7);

float h21(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vnoise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h21(i), h21(i + vec2(1, 0)), f.x), mix(h21(i + vec2(0, 1)), h21(i + vec2(1, 1)), f.x), f.y);
}
float fbm(vec2 p) {
	float a = 0.5; float s = 0.0;
	for (int i = 0; i < 4; i++) { s += a * vnoise(p); p = p * 2.07 + 11.3; a *= 0.5; }
	return s;
}
float hash3(vec3 p) { return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453); }

float ridge(float az, float scale, float seed) {
	return vnoise(vec2(az * scale + seed, seed)) * 0.6 + vnoise(vec2(az * scale * 2.3 + seed * 2.0, seed + 3.0)) * 0.3 + vnoise(vec2(az * scale * 5.7, seed + 8.0)) * 0.1;
}

void sky() {
	vec3 d = normalize(EYEDIR);
	float up = d.y;
	float hor = 1.0 - clamp(abs(up), 0.0, 1.0);
	// gradient: horizon -> mid -> top
	vec3 col;
	if (up >= 0.0) {
		float t1 = pow(clamp(up, 0.0, 1.0), 0.45);
		col = mix(horizon_col, mid_col, smoothstep(0.0, 0.5, t1));
		col = mix(col, top_col, smoothstep(0.35, 1.0, t1));
	} else {
		col = mix(horizon_col, ground_col, smoothstep(0.0, 0.35, -up));
	}
	// dusk / dawn glow around the sun and along the horizon on its side
	vec3 sd = normalize(sun_dir);
	float sdot = dot(d, sd);
	float glow = pow(clamp(sdot * 0.5 + 0.5, 0.0, 1.0), 6.0) * pow(hor, 3.0);
	col += glow_col * glow * glow_amt * 1.3;
	col = mix(col, glow_col, glow_amt * 0.18 * pow(hor, 6.0));
	// sun
	float sd_ang = acos(clamp(sdot, -1.0, 1.0));
	float disc = smoothstep(0.045, 0.036, sd_ang) * sun_vis * (1.0 - cover * 0.85);
	float halo = pow(clamp(1.0 - sd_ang / 0.55, 0.0, 1.0), 3.0) * sun_vis * (1.0 - dark * 0.7);
	col += sun_col * (disc * 4.0 + halo * 0.35);
	// moon
	vec3 md = normalize(moon_dir);
	float mdot = dot(d, md);
	float m_ang = acos(clamp(mdot, -1.0, 1.0));
	float mvis = night * (1.0 - cover * 0.8);
	float mdisc = smoothstep(0.052, 0.045, m_ang);
	vec3 mcol = vec3(0.92, 0.93, 0.85);
	// craters: a few darker blotches inside the disc
	vec3 ml = d - md * mdot;
	float cr = vnoise(ml.xz * 70.0 + ml.y * 60.0);
	mcol *= 0.82 + 0.25 * cr;
	col += mcol * mdisc * mvis * 2.2;
	col += vec3(0.5, 0.6, 0.9) * pow(clamp(1.0 - m_ang / 0.5, 0.0, 1.0), 3.0) * mvis * 0.35;
	// stars
	if (night > 0.02 && up > 0.0) {
		vec3 sp = d * 160.0;
		vec3 cell = floor(sp);
		float rnd = hash3(cell);
		vec3 fp = fract(sp) - 0.5;
		float star = step(0.987, rnd) * smoothstep(0.35, 0.0, length(fp));
		float tw = 0.6 + 0.4 * hash3(cell + 7.0);
		float vis = night * smoothstep(0.02, 0.25, up) * (1.0 - cover);
		col += vec3(0.85, 0.9, 1.0) * star * tw * vis * 1.6;
		// a faint milky band
		float band = smoothstep(0.35, 0.0, abs(dot(d, normalize(vec3(0.3, 0.8, -0.5)))));
		col += vec3(0.1, 0.12, 0.2) * band * fbm(d.xz * 9.0 + d.y * 4.0) * vis * 1.2;
	}
	// clouds on a dome: project onto a plane so they thin and flatten toward the horizon
	if (up > 0.015) {
		vec2 cp = d.xz / (up + 0.18) * 1.15 + scroll;
		float base = fbm(cp * 0.9);
		float detail = fbm(cp * 3.1 + 5.0);
		float thresh = mix(0.78, 0.2, cover);
		float dens = smoothstep(thresh, thresh + 0.22, base * 0.78 + detail * 0.28);
		float fade = smoothstep(0.015, 0.22, up);
		dens *= fade;
		// shade: lit on the sun side, grey underneath, tinted at dusk
		float lit = clamp(0.5 + 0.5 * (fbm(cp * 0.9 + sd.xz * 0.15) - base) * 6.0, 0.0, 1.0);
		vec3 lit_c = mix(vec3(1.0), glow_col * 1.15, glow_amt * 0.8);
		vec3 shade_c = mix(vec3(0.62, 0.68, 0.78), vec3(0.3, 0.33, 0.4), dark);
		vec3 cc = mix(shade_c, lit_c, lit * (1.0 - dark * 0.7));
		float sun_edge = pow(clamp(sdot, 0.0, 1.0), 12.0) * sun_vis * (1.0 - dark);
		cc += sun_col * sun_edge * 0.5;
		cc = mix(cc, cc * vec3(0.18, 0.2, 0.32) + vec3(0.02, 0.025, 0.05), night * 0.9);
		col = mix(col, cc, dens * mix(0.92, 0.98, dark));
	}
	// far hills in two layers of haze, sitting on the horizon
	if (up > -0.02 && up < 0.2) {
		float az = atan(d.x, d.z);
		float h1 = 0.012 + ridge(az, 3.0, 4.0) * 0.07;
		float h2 = 0.004 + ridge(az, 5.5, 17.0) * 0.045;
		vec3 far_c = mix(hill_col, horizon_col, 0.55);
		vec3 near_c = mix(hill_col * 0.8, horizon_col, 0.3);
		float m1 = smoothstep(h1 + 0.004, h1 - 0.004, up);
		float m2 = smoothstep(h2 + 0.003, h2 - 0.003, up);
		col = mix(col, far_c, m1 * 0.9);
		col = mix(col, near_c, m2 * 0.9);
	}
	COLOR = col;
}
