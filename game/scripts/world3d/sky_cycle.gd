extends Node3D
## The sky, the sun and moon and the mood of the light, following the town's clock. A shader sky (gradient, sun disc, moon, stars,
## clouds, far hills), a sun that becomes a cool moon at night, ambient light taken from the sky itself, and four distinct weathers
## (clear, cloudy, rain, fog) that change the sky, the fog, the light, the water and how wet the ground looks.

const SKY_SHADER = preload("res://shaders/sky3d.gdshader")

# hour, sky top, mid, horizon, glow colour, glow amount, light colour, light energy, ambient energy, fog density
const KEYS := [
	[4.0, "070b26", "0f1740", "1f2a5a", "6a6fb0", 0.0, "7f90e0", 0.30, 0.55, 0.0014],
	[5.0, "1c2a5c", "3d4f8a", "c5809a", "ff9a7a", 0.9, "ff9f7a", 0.35, 0.5, 0.0016],
	[6.0, "3f6ab8", "9db4d8", "f7b98a", "ffb070", 1.0, "ffc78f", 0.65, 0.62, 0.0013],
	[7.5, "4a8ad8", "86bae8", "ead9c4", "ffd0a0", 0.35, "ffe6c0", 1.0, 0.82, 0.0010],
	[9.5, "3f8fe4", "79b8ee", "cfe6f4", "ffffff", 0.0, "fff3dc", 1.25, 0.95, 0.0008],
	[13.0, "2f82de", "6fb1ea", "c6e3f6", "ffffff", 0.0, "fffaf0", 1.4, 1.0, 0.0007],
	[16.5, "3d84d6", "83b4e0", "ecdcbc", "ffe0a0", 0.12, "ffe6bc", 1.2, 0.92, 0.0009],
	[18.2, "4558a0", "d98a8a", "ffa066", "ff8a50", 0.95, "ff9a68", 0.75, 0.7, 0.0012],
	[19.3, "29306c", "7a5a98", "e8805e", "ff7a60", 0.85, "8a8fd8", 0.26, 0.62, 0.0014],
	[20.5, "141b4a", "2c3a74", "55528a", "8a70b0", 0.3, "7f90e0", 0.3, 0.6, 0.0014],
	[22.0, "0a1034", "141c4c", "232c5e", "6a6fb0", 0.0, "7f90e0", 0.32, 0.58, 0.0014],
	[24.0, "070b26", "0f1740", "1f2a5a", "6a6fb0", 0.0, "7f90e0", 0.30, 0.55, 0.0014]]

const WEATHER := {
	"clear": {"cover": 0.2, "dark": 0.0, "fog": 1.0, "light": 1.0, "sat": 1.16, "wet": 0.0, "wind": 0.6, "haze": 0.0, "fogh": 0.0, "calm": 1.0, "grey": 0.0, "amb": 1.0, "vig": 0.22},
	"cloudy": {"cover": 0.72, "dark": 0.35, "fog": 1.5, "light": 0.55, "sat": 0.98, "wet": 0.0, "wind": 0.95, "haze": 0.25, "fogh": 0.004, "calm": 0.6, "grey": 0.55, "amb": 1.1, "vig": 0.3},
	"rain": {"cover": 1.0, "dark": 0.9, "fog": 2.4, "light": 0.3, "sat": 0.8, "wet": 1.0, "wind": 1.5, "haze": 0.55, "fogh": 0.012, "calm": 0.2, "grey": 0.85, "amb": 1.2, "vig": 0.42},
	"fog": {"cover": 0.6, "dark": 0.1, "fog": 11.0, "light": 0.45, "sat": 0.72, "wet": 0.3, "wind": 0.15, "haze": 1.0, "fogh": 0.03, "calm": 0.95, "grey": 0.92, "amb": 1.3, "vig": 0.35}}

var sun: DirectionalLight3D
var env: Environment
var sky_mat: ShaderMaterial
var world_env: WorldEnvironment
var hour := 9.0
var weather := "clear"
var night := 0.0
var wet := 0.0                      # how wet the ground looks right now (eases toward the weather's wetness)
var sun_dir := Vector3(0, 1, 0)     # toward the sun, always (below the horizon at night)
var moon_dir := Vector3(0, -1, 0)
var sky_color := Color(0.6, 0.75, 0.9)    # the horizon colour right now (fog, water and puddles borrow it)
var daylight := 1.0                 # 0..1, how much sun there is
var vignette := 0.22
var _wet_target := 0.0
var _mats: Array = []               # materials with `night`, `wet`, `sky_col`, ... parameters
var _w: Dictionary = WEATHER["clear"]
var _last_push: Dictionary = {}


func build() -> void:
	sky_mat = ShaderMaterial.new()
	sky_mat.shader = SKY_SHADER
	var sky := Sky.new()
	sky.sky_material = sky_mat
	sky.radiance_size = Sky.RADIANCE_SIZE_32
	sky.process_mode = Sky.PROCESS_MODE_AUTOMATIC
	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 0.85
	env.tonemap_white = 6.0
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.16
	env.adjustment_contrast = 1.07
	env.adjustment_brightness = 1.0
	env.fog_enabled = true
	env.fog_aerial_perspective = 0.25
	env.fog_sky_affect = 0.55
	env.fog_height = 0.0
	env.fog_height_density = 0.0
	env.glow_enabled = false
	env.glow_intensity = 0.55
	env.glow_strength = 0.9
	env.glow_bloom = 0.04
	env.glow_hdr_threshold = 1.05
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	world_env = WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)
	sun = DirectionalLight3D.new()
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_split_1 = 0.22
	sun.directional_shadow_max_distance = 90.0
	sun.directional_shadow_fade_start = 0.75
	sun.shadow_blur = 1.3
	sun.shadow_bias = 0.05
	sun.shadow_normal_bias = 1.2
	sun.light_angular_distance = 0.4
	sun.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY
	add_child(sun)
	set_hour(hour)


func register_window_material(m: ShaderMaterial) -> void:
	if m != null and not _mats.has(m):
		_mats.append(m)


## Any material with the sky's uniforms (night, wet, sky_col, haze, calm, wind) is kept in step with the weather and the clock.
func register_material(m: Material) -> void:
	if m != null and not _mats.has(m):
		_mats.append(m)


## Quality knob: how far the sun's shadows reach (metres).
func set_shadow_distance(d: float) -> void:
	sun.directional_shadow_max_distance = d
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS if d > 30.0 else DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.shadow_enabled = d > 4.0


func set_weather(w: String, instant: bool = true) -> void:
	if not WEATHER.has(w):
		w = "clear"
	weather = w
	_w = WEATHER[w]
	_wet_target = float(_w["wet"])
	if instant:
		wet = _wet_target
	set_hour(hour)


func _process(delta: float) -> void:
	if absf(wet - _wet_target) > 0.001:
		wet = move_toward(wet, _wet_target, delta * 0.12)
		_push()


## Direction toward a body in the sky at an azimuth/elevation (degrees), in the same convention the sun light uses.
static func dir_from(az_deg: float, elev_deg: float) -> Vector3:
	return Basis.from_euler(Vector3(deg_to_rad(-elev_deg), deg_to_rad(az_deg + 160.0), 0.0)) * Vector3(0, 0, 1)


func _keyed(h: float) -> Dictionary:
	var a: Array = KEYS[0]
	var b: Array = KEYS[0]
	if h <= float(KEYS[0][0]):
		a = KEYS[0]; b = KEYS[0]
	elif h >= float(KEYS[-1][0]):
		a = KEYS[-1]; b = KEYS[-1]
	else:
		for i in KEYS.size() - 1:
			if h >= float(KEYS[i][0]) and h <= float(KEYS[i + 1][0]):
				a = KEYS[i]; b = KEYS[i + 1]
	var span := float(b[0]) - float(a[0])
	var t := 0.0 if span <= 0.0 else clampf((h - float(a[0])) / span, 0.0, 1.0)
	t = t * t * (3.0 - 2.0 * t)
	return {"top": Color(a[1]).lerp(Color(b[1]), t), "mid": Color(a[2]).lerp(Color(b[2]), t), "hor": Color(a[3]).lerp(Color(b[3]), t),
		"glow": Color(a[4]).lerp(Color(b[4]), t), "glow_amt": lerpf(float(a[5]), float(b[5]), t), "lcol": Color(a[6]).lerp(Color(b[6]), t),
		"lenergy": lerpf(float(a[7]), float(b[7]), t), "amb": lerpf(float(a[8]), float(b[8]), t), "fog": lerpf(float(a[9]), float(b[9]), t)}


func set_hour(h: float) -> void:
	hour = h
	var k := _keyed(h)
	var top: Color = k["top"]
	var mid: Color = k["mid"]
	var hor: Color = k["hor"]
	var lcol: Color = k["lcol"]
	var lenergy: float = k["lenergy"]
	var amb: float = k["amb"]
	var fog: float = k["fog"] * float(_w["fog"])
	var glow_amt: float = k["glow_amt"] * (1.0 - float(_w["grey"]) * 0.8)
	# the sun's path: east at 6, high at 12.5, west at 19; the moon crosses the other half of the night
	var day_t := (h - 6.0) / 13.0
	var elev: float
	var az: float
	if day_t >= 0.0 and day_t <= 1.0:
		elev = sin(day_t * PI) * 68.0
		az = lerpf(-90.0, 90.0, day_t)
	else:
		var nt := (h - 19.0) / 11.0 if h > 19.0 else (h + 5.0) / 11.0
		nt = clampf(nt, 0.0, 1.0)
		elev = -sin(nt * PI) * 42.0
		az = lerpf(90.0, -90.0, nt)
	var moon_elev := (-elev * 0.95 + 4.0) if elev < 0.0 else (-elev * 0.6 - 4.0)
	sun_dir = dir_from(az, elev)
	moon_dir = dir_from(az + 180.0, moon_elev)
	night = clampf((h - 18.6) / 1.8, 0.0, 1.0) if h >= 12.0 else clampf((6.2 - h) / 1.2, 0.0, 1.0)
	daylight = 1.0 - night
	# weather greys the whole sky, scaled to how bright the hour is
	var gr: float = float(_w["grey"])
	if gr > 0.0:
		var lum := clampf((top.get_luminance() + hor.get_luminance()) * 0.5 / 0.5, 0.1, 1.1)
		var gcol := Color(0.64, 0.68, 0.74) * lum
		if weather == "rain":
			gcol = Color(0.42, 0.46, 0.53) * lum
		elif weather == "fog":
			gcol = Color(0.8, 0.82, 0.84) * clampf(lum, 0.12, 1.0)
		gcol.a = 1.0
		top = top.lerp(gcol * 0.92, gr * 0.9)
		mid = mid.lerp(gcol, gr)
		hor = hor.lerp(gcol * 1.08, gr)
	var sun_up := smoothstep(0.0, 10.0, elev)
	var moon_up := smoothstep(0.0, 12.0, -elev)
	# one shadow-casting light: the sun by day, the moon by night
	var use_sun := elev > 0.0
	var le := lenergy * 0.7 * float(_w["light"])
	if use_sun:
		sun.rotation_degrees = Vector3(-maxf(elev, 3.5), az + 160.0, 0.0)
		sun.light_energy = le * sun_up
		sun.light_color = lcol
	else:
		sun.rotation_degrees = Vector3(-maxf(moon_elev, 12.0), az + 340.0, 0.0)
		sun.light_energy = (0.35 + 0.2 * (1.0 - float(_w["grey"]))) * moon_up
		sun.light_color = Color("8fa0e8")
	if not use_sun and elev > -1.0:
		sun.light_energy = 0.0
	# the sun's low energy at dusk keeps the key light's colour; ambient comes from the sky itself
	env.ambient_light_energy = amb * float(_w["amb"]) * (0.78 + 0.5 * night)
	env.ambient_light_sky_contribution = 1.0
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.fog_light_color = hor.lerp(Color.WHITE, 0.08)
	env.fog_density = fog * 0.55
	env.fog_height_density = float(_w["fogh"]) * (0.6 + 0.4 * daylight)
	env.fog_height = 14.0 if weather != "fog" else 40.0
	env.fog_sun_scatter = 0.15 * (1.0 - float(_w["grey"]))
	env.adjustment_saturation = float(_w["sat"]) * lerpf(1.0, 0.92, night)
	env.adjustment_brightness = 1.0 + night * 0.12
	env.tonemap_exposure = lerpf(0.88, 1.05, night) * (1.0 + 0.1 * float(_w["grey"]))
	env.glow_enabled = night > 0.35
	vignette = float(_w["vig"]) + night * 0.12
	sky_color = hor
	# the sky shader
	sky_mat.set_shader_parameter("top_col", top)
	sky_mat.set_shader_parameter("mid_col", mid)
	sky_mat.set_shader_parameter("horizon_col", hor)
	sky_mat.set_shader_parameter("ground_col", hor.darkened(0.25))
	sky_mat.set_shader_parameter("glow_col", k["glow"])
	sky_mat.set_shader_parameter("sun_col", lcol.lerp(Color.WHITE, 0.4))
	sky_mat.set_shader_parameter("sun_dir", sun_dir)
	sky_mat.set_shader_parameter("moon_dir", moon_dir)
	sky_mat.set_shader_parameter("sun_vis", smoothstep(-0.06, 0.03, sun_dir.y))
	sky_mat.set_shader_parameter("night", night)
	sky_mat.set_shader_parameter("cover", float(_w["cover"]))
	sky_mat.set_shader_parameter("dark", float(_w["dark"]))
	sky_mat.set_shader_parameter("glow_amt", glow_amt)
	sky_mat.set_shader_parameter("scroll", Vector2(h * 0.09, h * 0.035))
	sky_mat.set_shader_parameter("hill_col", hor.lerp(Color(0.35, 0.45, 0.62), 0.55 * (1.0 - night * 0.6)).darkened(night * 0.5 + gr * 0.0))
	_push()


func _push() -> void:
	var vals := {"night": night, "wet": wet, "sky_col": sky_color, "haze": float(_w["haze"]), "calm": float(_w["calm"]),
		"wind": float(_w["wind"]), "weather_dark": float(_w["dark"]), "daylight": daylight}
	var changed := false
	for key in vals:
		if not _last_push.has(key) or _last_push[key] != vals[key]:
			changed = true
	if not changed:
		return
	_last_push = vals
	for m in _mats:
		for key in vals:
			(m as ShaderMaterial).set_shader_parameter(key, vals[key])
