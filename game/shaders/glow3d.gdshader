shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled;
// Halos around lamps (billboards) and the pools of light they throw on the road (flat discs). Only visible at night.
uniform float night : hint_range(0.0, 1.0) = 0.0;
uniform vec3 glow_col : source_color = vec3(1.0, 0.72, 0.36);
uniform bool billboard = true;
uniform float strength = 0.6;
uniform float fade_near = 3.0;
uniform float fade_far = 90.0;

void vertex() {
	if (billboard) {
		MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
		MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0), vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0), vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0), vec4(0.0, 0.0, 0.0, 1.0));
	}
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float d = length(p);
	float g = pow(clamp(1.0 - d, 0.0, 1.0), 2.2);
	float dist = -VERTEX.z;
	float f = smoothstep(fade_near * 0.4, fade_near, dist) * (1.0 - smoothstep(fade_far * 0.6, fade_far, dist));
	ALBEDO = glow_col * g * strength * night * f;
}
