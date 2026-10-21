extends RefCounted
## Procedural sound: every sample the game plays is synthesised here from noise and sines, once, at a low sample rate, into a short
## AudioStreamWAV. Loops are cross-faded at the seam so they never click. Nothing is generated per frame; playback is the engine's.


static func _wav(data: PackedFloat32Array, rate: int, loop: bool = false) -> AudioStreamWAV:
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = rate
	w.stereo = false
	var bytes := PackedByteArray()
	bytes.resize(data.size() * 2)
	for i in data.size():
		bytes.encode_s16(i * 2, int(clampf(data[i], -1.0, 1.0) * 32000.0))
	w.data = bytes
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = data.size()
	return w


## Cross-fade the tail of `raw` (length n + fade) into its head so the n-sample loop is seamless.
static func _seam(raw: PackedFloat32Array, n: int, fade: int) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		out[i] = raw[i]
	for i in fade:
		var t := float(i) / float(fade)
		out[i] = raw[i] * t + raw[n + i] * (1.0 - t)
	return out


static func _rng(seed_value: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = seed_value
	return r


## A short click or beep: a sine with a noise grain and a fast decay.
static func tone_blip(freq: float, dur: float, amp: float = 0.5, grain: float = 0.2) -> AudioStreamWAV:
	var rate := 22050
	var n := int(dur * rate)
	var r := _rng(5)
	var d := PackedFloat32Array()
	d.resize(n)
	for i in n:
		var t := float(i) / float(rate)
		var env := exp(-t * (5.0 / maxf(dur, 0.01))) * minf(1.0, float(i) / 40.0)
		d[i] = (sin(TAU * freq * t) * (1.0 - grain) + r.randf_range(-1.0, 1.0) * grain) * env * amp
	return _wav(d, rate)


## Steady rain on a town: hiss, a little body, and sparse drips. Two seconds, looping.
static func rain_loop() -> AudioStreamWAV:
	var rate := 16000
	var n := rate * 2
	var fade := 1600
	var r := _rng(11)
	var raw := PackedFloat32Array()
	raw.resize(n + fade)
	var lp := 0.0
	var lp2 := 0.0
	var drip := 0.0
	for i in n + fade:
		var x := r.randf_range(-1.0, 1.0)
		lp += (x - lp) * 0.55
		lp2 += (x - lp2) * 0.05
		if r.randf() < 0.0035:
			drip = 0.6 + r.randf() * 0.4
		drip *= 0.93
		raw[i] = lp * 0.42 + lp2 * 0.5 + drip * x * 0.5
	return _wav(_seam(raw, n, fade), rate, true)


## Low wind that swells and falls. Four seconds at a low rate; the swell fits whole cycles so it loops.
static func wind_loop() -> AudioStreamWAV:
	var rate := 8000
	var n := rate * 4
	var fade := 800
	var r := _rng(23)
	var raw := PackedFloat32Array()
	raw.resize(n + fade)
	var a := 0.0
	var b := 0.0
	for i in n + fade:
		var x := r.randf_range(-1.0, 1.0)
		a += (x - a) * 0.06
		b += (a - b) * 0.08
		var t := float(i) / float(rate)
		var swell := 0.55 + 0.3 * sin(TAU * t * 0.25) + 0.15 * sin(TAU * t * 0.75 + 1.3)
		raw[i] = b * 3.2 * swell
	return _wav(_seam(raw, n, fade), rate, true)


## Night crickets: two voices, each a train of 4.4 kHz pulses in threes, slightly out of step.
static func crickets_loop() -> AudioStreamWAV:
	var rate := 16000
	var n := rate * 2
	var d := PackedFloat32Array()
	d.resize(n)
	var voices := [[4300.0, 0.0, 0.5], [4650.0, 0.17, 0.4]]
	for v in voices:
		var f: float = v[0]
		var off: float = v[1]
		var amp: float = v[2]
		for i in n:
			var t := float(i) / float(rate) + off
			var phase := fmod(t, 0.5)                      # a chirp group every half second (4 per loop)
			var pulse := fmod(phase, 0.06)                 # three pulses of 60 ms
			var gate := 1.0 if phase < 0.18 else 0.0
			var env := gate * sin(PI * pulse / 0.06) * (0.7 + 0.3 * sin(TAU * t * 1.0))
			d[i] += sin(TAU * f * t) * env * amp * 0.16
	return _wav(d, rate, true)


## A tense low drone: a minor-second pair near 55 Hz with a slow beat. Four seconds, whole cycles, loops.
static func drone_loop() -> AudioStreamWAV:
	var rate := 8000
	var n := rate * 4
	var d := PackedFloat32Array()
	d.resize(n)
	for i in n:
		var t := float(i) / float(rate)
		var s := sin(TAU * 55.0 * t) * 0.5 + sin(TAU * 58.0 * t) * 0.3 + sin(TAU * 82.5 * t) * 0.18 + sin(TAU * 110.0 * t + sin(TAU * 0.5 * t)) * 0.1
		d[i] = s * (0.7 + 0.3 * sin(TAU * 0.25 * t)) * 0.55
	return _wav(d, rate, true)


## One footstep on a surface: "grass", "road", "stone", "wood" or "floor". Three variants so it never machine-guns.
static func footstep(surface: String, variant: int) -> AudioStreamWAV:
	var rate := 16000
	var dur := 0.14
	var n := int(dur * rate)
	var r := _rng(100 + variant * 7 + surface.length())
	var d := PackedFloat32Array()
	d.resize(n)
	var lp := 0.0
	for i in n:
		var t := float(i) / float(rate)
		var x := r.randf_range(-1.0, 1.0)
		var s := 0.0
		match surface:
			"grass":
				lp += (x - lp) * 0.25
				s = lp * exp(-t * 28.0) * 0.5
			"road", "stone":
				lp += (x - lp) * 0.6
				s = (lp * exp(-t * 55.0) + sin(TAU * (180.0 + variant * 25.0) * t) * exp(-t * 45.0) * 0.5) * 0.6
			_:   # wood and floors: a knock with a hollow body
				lp += (x - lp) * 0.35
				s = (lp * exp(-t * 40.0) * 0.5 + sin(TAU * (120.0 + variant * 18.0) * t) * exp(-t * 30.0) * 0.8) * 0.6
		d[i] = s * minf(1.0, float(i) / 30.0)
	return _wav(d, rate)


## A door: a latch tick, then a short wooden thud.
static func door() -> AudioStreamWAV:
	var rate := 16000
	var n := int(0.45 * rate)
	var r := _rng(77)
	var d := PackedFloat32Array()
	d.resize(n)
	var lp := 0.0
	for i in n:
		var t := float(i) / float(rate)
		var s := 0.0
		if t < 0.03:
			s = r.randf_range(-1.0, 1.0) * exp(-t * 150.0) * 0.5
		elif t > 0.18:
			var tt := t - 0.18
			lp += (r.randf_range(-1.0, 1.0) - lp) * 0.2
			s = (sin(TAU * 90.0 * tt) * 0.8 + lp * 0.3) * exp(-tt * 18.0) * 0.8
		d[i] = s
	return _wav(d, rate)


## A rubber stamp coming down: thump plus a papery slap.
static func stamp() -> AudioStreamWAV:
	var rate := 16000
	var n := int(0.22 * rate)
	var r := _rng(41)
	var d := PackedFloat32Array()
	d.resize(n)
	var lp := 0.0
	for i in n:
		var t := float(i) / float(rate)
		lp += (r.randf_range(-1.0, 1.0) - lp) * 0.3
		d[i] = (sin(TAU * 70.0 * t) * exp(-t * 28.0) * 0.9 + lp * exp(-t * 60.0) * 0.5) * 0.8
	return _wav(d, rate)


## A two-note chime for a lab result or a found clue.
static func chime(rising: bool = true) -> AudioStreamWAV:
	var rate := 22050
	var n := int(0.5 * rate)
	var d := PackedFloat32Array()
	d.resize(n)
	var f0 := 660.0 if rising else 880.0
	var f1 := 990.0 if rising else 587.0
	for i in n:
		var t := float(i) / float(rate)
		var f := f0 if t < 0.12 else f1
		var tt := t if t < 0.12 else t - 0.12
		d[i] = (sin(TAU * f * tt) + sin(TAU * f * 2.0 * tt) * 0.25) * exp(-tt * 7.0) * 0.4
	return _wav(d, rate)
