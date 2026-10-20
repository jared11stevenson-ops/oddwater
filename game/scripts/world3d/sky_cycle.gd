extends Node3D
## The sky, the sun and the mood of the light, following the town's clock. Soft saturated colour, long shadows at the ends of the day,
## a blue moonlit night with warm windows. Weather darkens and thickens it.

const KEYS := [   # hour, sky top, horizon, light colour, light energy, ambient energy, fog density
	[5.0, "2b3a78", "e79a86", "ff9f7a", 0.35, 0.45, 0.0016],
	[6.5, "5f8fd0", "f5c9a0", "ffd2a0", 0.8, 0.7, 0.0011],
	[9.0, "4e9be3", "cde8f6", "fff3dc", 1.2, 0.9, 0.0008],
	[13.0, "3c8fe0", "bfe2f7", "fffaf0", 1.4, 1.0, 0.0007],
	[17.0, "4f90d8", "f7dcae", "ffe2b4", 1.15, 0.9, 0.0009],
	[18.8, "5a5fa6", "f28f6c", "ff9a68", 0.55, 0.6, 0.0013],
	[20.2, "1f2756", "3d4488", "7f8fd8", 0.22, 0.5, 0.0014],
	[24.0, "0c1130", "1b2250", "6f80d0", 0.2, 0.45, 0.0014]]

var sun: DirectionalLight3D
var env: Environment
var sky_mat: ProceduralSkyMaterial
var world_env: WorldEnvironment
var hour := 9.0
var weather := "clear"
var night := 0.0
var _windows: Array = []       # materials with a `night` parameter


func build() -> void:
	sky_mat = ProceduralSkyMaterial.new()
	sky_mat.sky_curve = 0.18
	sky_mat.ground_curve = 0.05
	sky_mat.sun_angle_max = 25.0
	var sky := Sky.new()
	sky.sky_material = sky_mat
	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 0.8
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.18
	env.adjustment_contrast = 1.06
	env.fog_enabled = true
	env.fog_aerial_perspective = 0.35
	env.fog_sky_affect = 0.9
	world_env = WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)
	sun = DirectionalLight3D.new()
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.directional_shadow_max_distance = 140.0
	sun.shadow_blur = 1.6
	sun.shadow_bias = 0.06
	sun.light_angular_distance = 0.5
	add_child(sun)
	set_hour(hour)


func register_window_material(m: ShaderMaterial) -> void:
	_windows.append(m)


func set_weather(w: String) -> void:
	weather = w
	set_hour(hour)


func set_hour(h: float) -> void:
	hour = h
	var a: Array = KEYS[0]
	var b: Array = KEYS[0]
	if h <= float(KEYS[0][0]):
		a = KEYS[-1]; b = KEYS[0]
	elif h >= float(KEYS[-1][0]):
		a = KEYS[-1]; b = KEYS[-1]
	else:
		for i in KEYS.size() - 1:
			if h >= float(KEYS[i][0]) and h <= float(KEYS[i + 1][0]):
				a = KEYS[i]; b = KEYS[i + 1]
	var span := float(b[0]) - float(a[0])
	var t := 0.0 if span <= 0.0 else clampf((h - float(a[0])) / span, 0.0, 1.0)
	var top := Color(a[1]).lerp(Color(b[1]), t)
	var hor := Color(a[2]).lerp(Color(b[2]), t)
	var lcol := Color(a[3]).lerp(Color(b[3]), t)
	var lenergy := lerpf(float(a[4]), float(b[4]), t)
	var amb := lerpf(float(a[5]), float(b[5]), t)
	var fog := lerpf(float(a[6]), float(b[6]), t)
	var grey := Color(0.62, 0.66, 0.72)
	match weather:
		"cloudy":
			top = top.lerp(grey, 0.35); hor = hor.lerp(grey.lightened(0.15), 0.4); lenergy *= 0.7
		"rain":
			top = top.lerp(grey.darkened(0.2), 0.6); hor = hor.lerp(grey, 0.6); lenergy *= 0.45; fog *= 1.8
		"fog":
			top = top.lerp(Color(0.8, 0.84, 0.88), 0.55); hor = hor.lerp(Color(0.85, 0.88, 0.9), 0.8); lenergy *= 0.6; fog *= 3.2
	sky_mat.sky_top_color = top
	sky_mat.sky_horizon_color = hor
	sky_mat.ground_horizon_color = hor.darkened(0.1)
	sky_mat.ground_bottom_color = top.darkened(0.4)
	env.ambient_light_color = top.lerp(Color(0.85, 0.82, 0.78), 0.62)
	env.ambient_light_energy = amb * 0.42
	env.fog_light_color = hor.lerp(Color.WHITE, 0.15)
	env.fog_density = fog * 0.55
	sun.light_color = lcol
	sun.light_energy = lenergy * 0.7
	# the sun climbs from the east at 6 to its peak at 12.5 and sets in the west at 19; after dark it is a dim moon from the other side
	var day_t := clampf((h - 6.0) / 13.0, 0.0, 1.0)
	var elev := sin(day_t * PI) * 68.0
	var az := lerpf(-90.0, 90.0, day_t)
	if h < 6.0 or h > 19.0:
		var nt := (h - 19.0) / 11.0 if h > 19.0 else (h + 5.0) / 11.0
		elev = sin(clampf(nt, 0.0, 1.0) * PI) * 45.0
		az = lerpf(90.0, -90.0, clampf(nt, 0.0, 1.0))
	sun.rotation_degrees = Vector3(-maxf(elev, 6.0), az + 160.0, 0.0)
	night = clampf((h - 18.6) / 1.8, 0.0, 1.0) if h >= 12.0 else clampf((6.2 - h) / 1.2, 0.0, 1.0)
	for m in _windows:
		(m as ShaderMaterial).set_shader_parameter("night", night)
