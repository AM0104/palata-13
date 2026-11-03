extends Node
## Procedural audio manager (autoload singleton `Audio`).
##
## Every sound is synthesised in GDScript into PCM16 mono AudioStreamWAV buffers
## the first time it is requested, then cached. No external asset files, no
## AudioStreamGenerator at runtime, deterministic output (fixed RNG seeds).
##
## For speed the generators avoid per-sample function calls: oscillators read a
## 4096-entry sine lookup table, random noise is read from a pre-generated
## deterministic noise bank, and envelopes/windows are precomputed once per
## buffer into PackedFloat32Array arrays.
##
## Public API:
##   Audio.play("pickup")
##   Audio.start_ambient("hospital")
##   Audio.stop_ambient()
##   Audio.set_master_volume(0.7) / Audio.get_master_volume()

const MIX_RATE: int = 22050
const POOL_SIZE: int = 8
const ONE_SHOT_PEAK: float = 0.398   # ~ -8 dBFS
const AMBIENT_PEAK: float = 0.0794   # ~ -22 dBFS
const SILENT_DB: float = -80.0
const AMBIENT_DB: float = 0.0        # ambient buffers are already mixed low
const LOOP_FADE: float = 0.5         # seconds crossfaded at the loop seam
const DEFAULT_AMBIENT_FADE: float = 0.8
const MASTER_SEED: int = 20240222

const SIN_LUT_SIZE: int = 4096
const SIN_LUT_MASK: int = 4095
const NOISE_SIZE: int = 65536
const NOISE_MASK: int = 65535
const NOISE_SEED: int = 987654321

const SOUND_SEEDS: Dictionary = {
	"step": 1100,
	"step_soft": 1101,
	"pickup": 1102,
	"deny": 1103,
	"door": 1104,
	"door_locked": 1105,
	"keypad": 1106,
	"beep": 1107,
	"hit": 1108,
	"hurt": 1109,
	"swing": 1110,
	"death": 1111,
	"heartbeat": 1112,
	"candle": 1113,
	"reveal": 1114,
	"ui": 1115,
	"ui_back": 1116,
	"note": 1117,
	"dig": 1118,
	"save": 1119,
	"boss": 1120,
	"scream": 1121,
}

const AMBIENT_KINDS: PackedStringArray = ["hospital", "cemetery", "prison", "church", "menu"]

var _sin_lut: PackedFloat32Array = PackedFloat32Array()
var _noise: PackedFloat32Array = PackedFloat32Array()
var _cache: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _pool_cursor: int = 0
var _warm_queue: Array = []

var _ambient_a: AudioStreamPlayer = null
var _ambient_b: AudioStreamPlayer = null
var _ambient_active: AudioStreamPlayer = null
var _ambient_idle: AudioStreamPlayer = null
var _ambient_fade: Tween = null
var _current_ambient: String = ""

var _master_linear: float = 1.0
var _master_bus: int = -1
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _init() -> void:
	_sin_lut.resize(SIN_LUT_SIZE)
	for i in SIN_LUT_SIZE:
		_sin_lut[i] = sin(TAU * float(i) / float(SIN_LUT_SIZE))
	var bank := RandomNumberGenerator.new()
	bank.seed = NOISE_SEED
	_noise.resize(NOISE_SIZE)
	for i in NOISE_SIZE:
		_noise[i] = bank.randf_range(-1.0, 1.0)


func _ready() -> void:
	_rng.seed = MASTER_SEED
	_master_bus = AudioServer.get_bus_index("Master")
	_build_players()
	_apply_master()
	_start_prewarm()


## Прогрев звука идёт по одному буферу за кадр, а не одним куском на старте:
## синтез в GDScript в веб-сборке в разы дороже, и всё разом — это замерший
## экран на несколько секунд в начале и на каждой смене этажа (эмбиент этажа).
func _start_prewarm() -> void:
	_warm_queue = SOUND_SEEDS.keys()
	for kind in AMBIENT_KINDS:
		_warm_queue.append("amb:" + kind)
	set_process(true)


func _process(_delta: float) -> void:
	if _warm_queue.is_empty():
		set_process(false)
		return
	var item := str(_warm_queue.pop_front())
	if item.begins_with("amb:"):
		_get_ambient(item.substr(4))
	else:
		_get_one_shot(item)


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

## Plays a one-shot. Unknown names are ignored silently.
func play(sound: String, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	var stream := _get_one_shot(sound)
	if stream == null:
		return
	var player := _next_player()
	if player == null:
		return
	player.stream = stream
	player.volume_db = clampf(volume_db, SILENT_DB, 12.0)
	var p: float = clampf(pitch, 0.05, 4.0)
	if sound == "step" or sound == "step_soft" or sound == "hit" or sound == "hurt":
		p *= _rng.randf_range(0.94, 1.06)
	player.pitch_scale = clampf(p, 0.05, 4.0)
	player.play()


## Crossfades to an ambient loop. Same kind while already playing is a no-op.
func start_ambient(kind: String) -> void:
	if kind == _current_ambient:
		return
	var stream := _get_ambient(kind)
	if stream == null:
		return
	if _ambient_active == null or _ambient_idle == null:
		return
	var old: AudioStreamPlayer = _ambient_active
	var next: AudioStreamPlayer = _ambient_idle
	if old == next:
		return
	_kill_ambient_fade()
	next.stream = stream
	next.volume_db = SILENT_DB
	next.play()
	_ambient_active = next
	_ambient_idle = old
	_current_ambient = kind
	if old == null or not is_inside_tree():
		if old != null:
			old.stop()
		next.volume_db = AMBIENT_DB
		return
	_ambient_fade = create_tween().set_parallel(true)
	_ambient_fade.tween_property(next, "volume_db", AMBIENT_DB, DEFAULT_AMBIENT_FADE) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_ambient_fade.tween_property(old, "volume_db", SILENT_DB, DEFAULT_AMBIENT_FADE) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_ambient_fade.chain().tween_callback(_stop_player.bind(old))


## Fades out and stops the ambient loop.
func stop_ambient(fade: float = 0.8) -> void:
	_current_ambient = ""
	var player: AudioStreamPlayer = _ambient_active
	_kill_ambient_fade()
	if player == null:
		return
	var f: float = maxf(0.0, fade)
	if f <= 0.0 or not is_inside_tree():
		_stop_player(player)
		player.volume_db = SILENT_DB
		if _ambient_idle != null:
			_stop_player(_ambient_idle)
		return
	_ambient_fade = create_tween()
	_ambient_fade.tween_property(player, "volume_db", SILENT_DB, f) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_ambient_fade.tween_callback(_stop_player.bind(player))


## Master volume as a linear 0..1 value.
func set_master_volume(linear: float) -> void:
	_master_linear = clampf(linear, 0.0, 1.0)
	_apply_master()


func get_master_volume() -> float:
	return _master_linear


# ---------------------------------------------------------------------------
# Player / bus plumbing
# ---------------------------------------------------------------------------

func _build_players() -> void:
	for i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.name = "OneShot%d" % i
		p.process_mode = Node.PROCESS_MODE_ALWAYS
		if _master_bus >= 0:
			p.bus = "Master"
		add_child(p)
		_players.append(p)
	_ambient_a = _make_ambient_player("AmbientA")
	_ambient_b = _make_ambient_player("AmbientB")
	_ambient_active = _ambient_a
	_ambient_idle = _ambient_b


func _make_ambient_player(pname: String) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.name = pname
	p.process_mode = Node.PROCESS_MODE_ALWAYS
	p.volume_db = SILENT_DB
	if _master_bus >= 0:
		p.bus = "Master"
	add_child(p)
	return p


func _next_player() -> AudioStreamPlayer:
	var count: int = _players.size()
	if count <= 0:
		return null
	for i in count:
		var idx: int = (_pool_cursor + i) % count
		var p: AudioStreamPlayer = _players[idx]
		if p != null and not p.playing:
			_pool_cursor = (idx + 1) % count
			return p
	var fallback: AudioStreamPlayer = _players[_pool_cursor]
	_pool_cursor = (_pool_cursor + 1) % count
	return fallback


func _stop_player(p: AudioStreamPlayer) -> void:
	if p != null and is_instance_valid(p):
		p.stop()


func _kill_ambient_fade() -> void:
	if _ambient_fade != null and _ambient_fade.is_valid():
		_ambient_fade.kill()
	_ambient_fade = null


func _apply_master() -> void:
	if _master_bus < 0 or _master_bus >= AudioServer.bus_count:
		return
	if _master_linear <= 0.0:
		AudioServer.set_bus_mute(_master_bus, true)
		return
	AudioServer.set_bus_mute(_master_bus, false)
	AudioServer.set_bus_volume_db(_master_bus, linear_to_db(_master_linear))


## Release active playbacks so no stream stays alive after teardown.
func _exit_tree() -> void:
	_kill_ambient_fade()
	for p in _players:
		if p != null and is_instance_valid(p):
			p.stop()
			p.stream = null
	for p in [_ambient_a, _ambient_b]:
		if p != null and is_instance_valid(p):
			p.stop()


# ---------------------------------------------------------------------------
# Cache
# ---------------------------------------------------------------------------

## One-shots are short, ambients are ~6.5 s each. И то, и другое греется заранее
## (см. _start_prewarm), по одному буферу за кадр; здесь только наполнение кэша.
func _get_one_shot(sound: String) -> AudioStreamWAV:
	if _cache.has(sound):
		return _cache[sound] as AudioStreamWAV
	if not SOUND_SEEDS.has(sound):
		return null
	var samples := _gen_one_shot(sound)
	if samples.size() == 0:
		return null
	var stream := _to_stream(samples, false)
	if stream != null:
		_cache[sound] = stream
	return stream


func _get_ambient(kind: String) -> AudioStreamWAV:
	var key := "amb:" + kind
	if _cache.has(key):
		return _cache[key] as AudioStreamWAV
	var samples := _gen_ambient(kind)
	if samples.size() == 0:
		return null
	var stream := _to_stream(samples, true)
	if stream != null:
		_cache[key] = stream
	return stream


# ---------------------------------------------------------------------------
# Buffer helpers
# ---------------------------------------------------------------------------

func _mk(dur: float) -> PackedFloat32Array:
	var n: int = maxi(1, int(dur * float(MIX_RATE)))
	var buf := PackedFloat32Array()
	buf.resize(n)
	return buf


func _rng_seed(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


## Half-sine window over [0, length], 0 at both edges. For short windows only.
func _bump(t: float, length: float) -> float:
	if length <= 0.0 or t < 0.0 or t > length:
		return 0.0
	return _sin_lut[int(2048.0 * t / length) & SIN_LUT_MASK]


## Precomputed attack/release envelope, 0 at both edges.
func _env_buf(n: int, attack: float, release: float) -> PackedFloat32Array:
	var env := PackedFloat32Array()
	env.resize(n)
	if n <= 0:
		return env
	var a: int = clampi(int(attack * float(MIX_RATE)), 1, n)
	var r: int = clampi(int(release * float(MIX_RATE)), 1, n)
	var body: int = maxi(a, n - r)
	var inv_a: float = 1.0 / float(a)
	var inv_r: float = 1.0 / float(r)
	for i in n:
		var g := 1.0
		if i < a:
			g = float(i) * inv_a
		if i >= body:
			var g2: float = float(n - 1 - i) * inv_r
			if g2 < g:
				g = g2
		env[i] = g
	return env


## Precomputed half-sine window across the whole buffer.
func _win_buf(n: int) -> PackedFloat32Array:
	var win := PackedFloat32Array()
	win.resize(n)
	if n <= 1:
		return win
	var d: float = float(n - 1)
	for i in n:
		win[i] = _sin_lut[int(2048.0 * float(i) / d) & SIN_LUT_MASK]
	return win


## Applies a click-guard fade on both edges and normalises the peak.
func _finish(buf: PackedFloat32Array, peak: float) -> void:
	var n: int = buf.size()
	if n <= 0:
		return
	var a: int = maxi(1, int(0.003 * float(MIX_RATE)))
	var r: int = maxi(1, int(0.006 * float(MIX_RATE)))
	for i in n:
		var g := 1.0
		if i < a:
			g = float(i) / float(a)
		var d: int = n - 1 - i
		if d < r:
			var gr := float(d) / float(r)
			if gr < g:
				g = gr
		buf[i] = buf[i] * g
	_normalize(buf, peak)


func _normalize(buf: PackedFloat32Array, peak: float) -> void:
	var n: int = buf.size()
	if n <= 0 or peak <= 0.0:
		return
	var mx := 0.0
	for i in n:
		var v := buf[i]
		if v < 0.0:
			v = -v
		if v > mx:
			mx = v
	if mx < 0.00001:
		return
	var scale: float = peak / mx
	for i in n:
		buf[i] = buf[i] * scale


## Crossfades the tail into the head, then truncates, so start/end match.
func _loopify(buf: PackedFloat32Array, fade: float) -> PackedFloat32Array:
	var n: int = buf.size()
	var f: int = int(fade * float(MIX_RATE))
	if n <= 0 or f <= 1 or f * 2 >= n:
		return buf
	var out := buf
	for i in f:
		var w := float(i) / float(f)
		out[i] = buf[i] * w + buf[n - f + i] * (1.0 - w)
	out.resize(n - f)
	return out


func _to_stream(samples: PackedFloat32Array, loop: bool) -> AudioStreamWAV:
	var count: int = samples.size()
	if count <= 0:
		return null
	var data := PackedByteArray()
	data.resize(count * 2)
	for i in count:
		var s: float = samples[i]
		if s > 1.0:
			s = 1.0
		elif s < -1.0:
			s = -1.0
		data.encode_s16(i * 2, int(round(s * 32767.0)))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = MIX_RATE
	stream.stereo = false
	stream.data = data
	if loop:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = count
	return stream


# ---------------------------------------------------------------------------
# Small additive primitives
# ---------------------------------------------------------------------------

func _add_click(buf: PackedFloat32Array, t0: float, freq: float, amp: float) -> void:
	var n: int = buf.size()
	var start: int = int(t0 * float(MIX_RATE))
	if start < 0 or start >= n:
		return
	var ln: int = mini(n - start, int(0.03 * float(MIX_RATE)))
	var lut := _sin_lut
	var inc: float = freq * float(SIN_LUT_SIZE) / float(MIX_RATE)
	var ph := 0.0
	var dec := amp
	var mul: float = exp(-220.0 / float(MIX_RATE))
	for i in ln:
		buf[start + i] += lut[int(ph) & SIN_LUT_MASK] * dec
		ph += inc
		dec *= mul


func _add_thump(buf: PackedFloat32Array, t0: float, freq: float, amp: float, decay: float) -> void:
	var n: int = buf.size()
	var start: int = int(t0 * float(MIX_RATE))
	if start < 0 or start >= n:
		return
	var ln: int = mini(n - start, int(0.35 * float(MIX_RATE)))
	var lut := _sin_lut
	var inc: float = freq * float(SIN_LUT_SIZE) / float(MIX_RATE)
	var ph := 0.0
	var dec := amp
	var mul: float = exp(-decay / float(MIX_RATE))
	for i in ln:
		buf[start + i] += lut[int(ph) & SIN_LUT_MASK] * dec
		ph += inc
		dec *= mul


func _add_drop(buf: PackedFloat32Array, t0: float, amp: float) -> void:
	var n: int = buf.size()
	var start: int = int(t0 * float(MIX_RATE))
	if start < 0 or start >= n:
		return
	var ln: int = mini(n - start, int(0.12 * float(MIX_RATE)))
	var lut := _sin_lut
	var ph := 0.0
	var dec := amp
	var rel := 1.0
	var mul: float = exp(-38.0 / float(MIX_RATE))
	for i in ln:
		var f: float = 1400.0 + 900.0 * rel
		ph += f * float(SIN_LUT_SIZE) / float(MIX_RATE)
		buf[start + i] += lut[int(ph) & SIN_LUT_MASK] * dec
		dec *= mul
		rel *= mul


func _add_clang(buf: PackedFloat32Array, t0: float, rng: RandomNumberGenerator, amp: float) -> void:
	var n: int = buf.size()
	var start: int = int(t0 * float(MIX_RATE))
	if start < 0 or start >= n:
		return
	var ln: int = mini(n - start, int(0.9 * float(MIX_RATE)))
	var lut := _sin_lut
	var noise := _noise
	var f1: float = rng.randf_range(320.0, 520.0)
	var f2: float = f1 * 2.76
	var f3: float = f1 * 5.4
	var base: int = (int(f1 * 977.0)) & NOISE_MASK
	var p1 := 0.0
	var p2 := 0.0
	var p3 := 0.0
	var i1: float = f1 * float(SIN_LUT_SIZE) / float(MIX_RATE)
	var i2: float = f2 * float(SIN_LUT_SIZE) / float(MIX_RATE)
	var i3: float = f3 * float(SIN_LUT_SIZE) / float(MIX_RATE)
	var d1 := 1.0
	var d2 := 1.0
	var d3 := 1.0
	var nd := 1.0
	var m1: float = exp(-5.0 / float(MIX_RATE))
	var m2: float = exp(-8.5 / float(MIX_RATE))
	var m3: float = exp(-15.0 / float(MIX_RATE))
	var mn: float = exp(-45.0 / float(MIX_RATE))
	for i in ln:
		var v := lut[int(p1) & SIN_LUT_MASK] * d1
		v += lut[int(p2) & SIN_LUT_MASK] * d2 * 0.6
		v += lut[int(p3) & SIN_LUT_MASK] * d3 * 0.35
		v += noise[(base + i) & NOISE_MASK] * nd * 0.5
		buf[start + i] += v * amp
		p1 += i1
		p2 += i2
		p3 += i3
		d1 *= m1
		d2 *= m2
		d3 *= m3
		nd *= mn


# ---------------------------------------------------------------------------
# One-shot generators
# ---------------------------------------------------------------------------

func _gen_one_shot(sound: String) -> PackedFloat32Array:
	var buf := PackedFloat32Array()
	match sound:
		"step":
			buf = _gen_step(false)
		"step_soft":
			buf = _gen_step(true)
		"pickup":
			buf = _gen_pickup()
		"deny":
			buf = _gen_buzz(0.28, 118.0, int(SOUND_SEEDS["deny"]))
		"door":
			buf = _gen_door()
		"door_locked":
			buf = _gen_buzz(0.5, 92.0, int(SOUND_SEEDS["door_locked"]))
		"keypad":
			buf = _gen_keypad()
		"beep":
			buf = _gen_beep()
		"hit":
			buf = _gen_hit()
		"hurt":
			buf = _gen_hurt()
		"swing":
			buf = _gen_swing()
		"death":
			buf = _gen_death()
		"heartbeat":
			buf = _gen_heartbeat()
		"candle":
			buf = _gen_candle()
		"reveal":
			buf = _gen_reveal()
		"ui":
			buf = _gen_blip(0.09, 1046.5, 0.0, 1.0)
		"ui_back":
			buf = _gen_blip(0.11, 784.0, 523.25, 0.8)
		"note":
			buf = _gen_note()
		"dig":
			buf = _gen_dig()
		"save":
			buf = _gen_save()
		"boss":
			buf = _gen_boss()
		"scream":
			buf = _gen_scream()
		_:
			return buf
	if buf.size() == 0:
		return buf
	_finish(buf, ONE_SHOT_PEAK)
	return buf


func _gen_step(soft: bool) -> PackedFloat32Array:
	var dur: float = 0.16 if soft else 0.12
	var buf := _mk(dur)
	var n: int = buf.size()
	var seed_value: int = int(SOUND_SEEDS["step_soft"]) if soft else int(SOUND_SEEDS["step"])
	var env := _env_buf(n, 0.003, dur * 0.8)
	var lut := _sin_lut
	var noise := _noise
	var base: int = (seed_value * 977) & NOISE_MASK
	var lp := 0.0
	var cut: float = 0.085 if soft else 0.19
	var f0: float = 72.0 if soft else 96.0
	var inc: float = f0 * float(SIN_LUT_SIZE) / float(MIX_RATE)
	var ph := 0.0
	var dec := 1.0
	var mul: float = exp(-26.0 / float(MIX_RATE))
	for i in n:
		lp += cut * (noise[(base + i) & NOISE_MASK] - lp)
		buf[i] = (lp * 1.5 + lut[int(ph) & SIN_LUT_MASK] * dec * 0.8) * env[i]
		ph += inc
		dec *= mul
	return buf


func _gen_pickup() -> PackedFloat32Array:
	var buf := _mk(0.24)
	var n: int = buf.size()
	var lut := _sin_lut
	var split: int = int(0.10 * float(MIX_RATE))
	var m1: float = exp(-14.0 / float(MIX_RATE))
	var ph1 := 0.0
	var ph2 := 0.0
	var ph3 := 0.0
	var i1: float = 880.0 * float(SIN_LUT_SIZE) / float(MIX_RATE)
	var i2: float = 1318.5 * float(SIN_LUT_SIZE) / float(MIX_RATE)
	var i3: float = 2637.0 * float(SIN_LUT_SIZE) / float(MIX_RATE)
	var dec := 1.0
	for i in n:
		if i < split:
			buf[i] = lut[int(ph1) & SIN_LUT_MASK] * _bump(float(i) / float(MIX_RATE), 0.10)
		else:
			buf[i] = (lut[int(ph2) & SIN_LUT_MASK] * 0.8 + lut[int(ph3) & SIN_LUT_MASK] * 0.2) * dec
			dec *= m1
		ph1 += i1
		ph2 += i2
		ph3 += i3
	return buf


func _gen_buzz(dur: float, freq: float, seed_value: int) -> PackedFloat32Array:
	var buf := _mk(dur)
	var n: int = buf.size()
	var env := _env_buf(n, 0.006, dur * 0.45)
	var noise := _noise
	var base: int = (seed_value * 613) & NOISE_MASK
	var lp := 0.0
	var am_inc: float = 33.0 * float(SIN_LUT_SIZE) / float(MIX_RATE)
	var am := 0.0
	var saw_inc: float = freq / float(MIX_RATE)
	var saw_ph := 0.0
	for i in n:
		saw_ph += saw_inc
		if saw_ph >= 1.0:
			saw_ph -= 1.0
		var saw := 2.0 * saw_ph - 1.0
		var mod := 0.65 + 0.35 * _sin_lut[int(am) & SIN_LUT_MASK]
		lp += 0.16 * ((saw * 0.6 + noise[(base + i) & NOISE_MASK] * 0.18) - lp)
		buf[i] = lp * mod * env[i]
		am += am_inc
	return buf


func _gen_door() -> PackedFloat32Array:
	var dur: float = 0.55
	var buf := _mk(dur)
	var n: int = buf.size()
	var env := _env_buf(n, 0.02, dur * 0.5)
	var noise := _noise
	var base: int = (int(SOUND_SEEDS["door"]) * 331) & NOISE_MASK
	var lut := _sin_lut
	var lp := 0.0
	var ph := 0.0
	var ph2 := 0.0
	var inc: float = 150.0 * float(SIN_LUT_SIZE) / float(MIX_RATE)
	var sweep: float = 90.0 * float(SIN_LUT_SIZE) / float(MIX_RATE) / float(n)
	for i in n:
		lp += 0.09 * (noise[(base + i) & NOISE_MASK] - lp)
		var cur: float = inc + sweep * float(i)
		ph += cur
		ph2 += cur * 2.4
		var creak := lut[int(ph) & SIN_LUT_MASK] * 0.35 + lut[int(ph2) & SIN_LUT_MASK] * 0.12
		buf[i] = (lp * 1.6 + creak) * env[i]
	_add_click(buf, dur - 0.09, 2200.0, 0.5)
	return buf


func _gen_keypad() -> PackedFloat32Array:
	var buf := _mk(0.42)
	var n: int = buf.size()
	var lut := _sin_lut
	for k in 4:
		_add_click(buf, 0.02 + 0.085 * float(k), 1400.0 + 120.0 * float(k), 0.55)
	var inc: float = 760.0 * float(SIN_LUT_SIZE) / float(MIX_RATE)
	var ph := 0.0
	for i in n:
		buf[i] += lut[int(ph) & SIN_LUT_MASK] * 0.12 * _bump(float(i) / float(MIX_RATE), 0.1)
		ph += inc
	return buf


func _gen_beep() -> PackedFloat32Array:
	var buf := _mk(0.12)
	var n: int = buf.size()
	var env := _env_buf(n, 0.004, 0.05)
	var lut := _sin_lut
	var inc: float = 1180.0 * float(SIN_LUT_SIZE) / float(MIX_RATE)
	var inc2: float = 2360.0 * float(SIN_LUT_SIZE) / float(MIX_RATE)
	var ph := 0.0
	var ph2 := 0.0
	for i in n:
		buf[i] = (lut[int(ph) & SIN_LUT_MASK] * 0.8 + lut[int(ph2) & SIN_LUT_MASK] * 0.2) * env[i]
		ph += inc
		ph2 += inc2
	return buf


func _gen_blip(dur: float, f_start: float, f_end: float, bright: float) -> PackedFloat32Array:
	var buf := _mk(dur)
	var n: int = buf.size()
	var env := _env_buf(n, 0.004, dur * 0.6)
	var lut := _sin_lut
	var ph := 0.0
	var ph2 := 0.0
	var dec := 1.0
	var mul: float = exp(-3.0 / float(MIX_RATE))
	var step: float = (f_end - f_start) / float(maxi(1, n))
	for i in n:
		var f: float = f_start + step * float(i) if f_end > 0.0 else f_start
		var inc: float = f * float(SIN_LUT_SIZE) / float(MIX_RATE)
		var a := lut[int(ph) & SIN_LUT_MASK] * 0.85
		a += lut[int(ph2) & SIN_LUT_MASK] * 0.15 * bright
		buf[i] = a * env[i] * dec
		ph += inc
		ph2 += inc * 2.0
		dec *= mul
	return buf


func _gen_hit() -> PackedFloat32Array:
	var dur: float = 0.3
	var buf := _mk(dur)
	var n: int = buf.size()
	var env := _env_buf(n, 0.0015, dur * 0.7)
	var noise := _noise
	var base: int = (int(SOUND_SEEDS["hit"]) * 419) & NOISE_MASK
	var lut := _sin_lut
	var lp := 0.0
	var ph := 0.0
	var ph2 := 0.0
	var inc: float = 64.0 * float(SIN_LUT_SIZE) / float(MIX_RATE)
	var inc2: float = 180.0 * float(SIN_LUT_SIZE) / float(MIX_RATE)
	var d1 := 1.0
	var d2 := 1.0
	var m1: float = exp(-18.0 / float(MIX_RATE))
	var m2: float = exp(-40.0 / float(MIX_RATE))
	for i in n:
		lp += 0.20 * (noise[(base + i) & NOISE_MASK] - lp)
		var body := lut[int(ph) & SIN_LUT_MASK] * d1 * 0.9
		var crack := lut[int(ph2) & SIN_LUT_MASK] * d2 * 0.35
		buf[i] = (lp * 1.2 + body + crack) * env[i]
		ph += inc
		ph2 += inc2
		d1 *= m1
		d2 *= m2
	return buf


func _gen_hurt() -> PackedFloat32Array:
	var dur: float = 0.45
	var buf := _mk(dur)
	var n: int = buf.size()
	var env := _env_buf(n, 0.006, dur * 0.55)
	var noise := _noise
	var base: int = (int(SOUND_SEEDS["hurt"]) * 271) & NOISE_MASK
	var lut := _sin_lut
	var lp := 0.0
	var ph := 0.0
	var ph2 := 0.0
	var ph3 := 0.0
	var sweep := 1.0
	var sweep_mul: float = exp(-6.0 / float(MIX_RATE))
	for i in n:
		var f: float = 90.0 + 210.0 * sweep
		var inc: float = f * float(SIN_LUT_SIZE) / float(MIX_RATE)
		lp += 0.25 * (noise[(base + i) & NOISE_MASK] - lp)
		var growl := lut[int(ph) & SIN_LUT_MASK] * 0.7
		growl += lut[int(ph2) & SIN_LUT_MASK] * 0.25
		growl += lut[int(ph3) & SIN_LUT_MASK] * 0.12
		buf[i] = (growl + lp * 0.5) * env[i]
		ph += inc
		ph2 += inc * 2.02
		ph3 += inc * 3.05
		sweep *= sweep_mul
	return buf


func _gen_swing() -> PackedFloat32Array:
	var dur: float = 0.4
	var buf := _mk(dur)
	var n: int = buf.size()
	var env := _env_buf(n, 0.02, dur * 0.35)
	var win := _win_buf(n)
	var noise := _noise
	var base: int = (int(SOUND_SEEDS["swing"]) * 157) & NOISE_MASK
	var lp := 0.0
	var lp2 := 0.0
	var cut := 0.55
	var cut_step: float = (0.03 - 0.55) / float(maxi(1, n))
	for i in n:
		lp += cut * (noise[(base + i) & NOISE_MASK] - lp)
		lp2 += cut * (lp - lp2)
		var band := lp - lp2
		buf[i] = (lp * 1.2 + band * 2.2) * env[i] * win[i]
		cut += cut_step
	return buf


func _gen_death() -> PackedFloat32Array:
	var dur: float = 1.05
	var buf := _mk(dur)
	var n: int = buf.size()
	var env := _env_buf(n, 0.02, dur * 0.5)
	var noise := _noise
	var base: int = (int(SOUND_SEEDS["death"]) * 883) & NOISE_MASK
	var lut := _sin_lut
	var lp := 0.0
	var ph := 0.0
	var ph2 := 0.0
	var ph3 := 0.0
	var sweep := 1.0
	var sweep_mul: float = exp(-1.8 / float(MIX_RATE))
	for i in n:
		var f: float = 40.0 + 160.0 * sweep
		var inc: float = f * float(SIN_LUT_SIZE) / float(MIX_RATE)
		lp += 0.06 * (noise[(base + i) & NOISE_MASK] - lp)
		var tone := lut[int(ph) & SIN_LUT_MASK] * 0.8
		tone += lut[int(ph2) & SIN_LUT_MASK] * 0.3
		tone += lut[int(ph3) & SIN_LUT_MASK] * 0.25
		buf[i] = (tone + lp * 0.7) * env[i]
		ph += inc
		ph2 += inc * 1.5
		ph3 += inc * 0.5
		sweep *= sweep_mul
	return buf


func _gen_heartbeat() -> PackedFloat32Array:
	var buf := _mk(0.6)
	_add_thump(buf, 0.0, 62.0, 1.0, 14.0)
	_add_thump(buf, 0.30, 54.0, 0.72, 12.0)
	var n: int = buf.size()
	var env := _env_buf(n, 0.004, 0.05)
	var win := _win_buf(n)
	for i in n:
		buf[i] = buf[i] * win[i] * env[i]
	return buf


func _gen_candle() -> PackedFloat32Array:
	var dur: float = 0.25
	var buf := _mk(dur)
	var n: int = buf.size()
	var env := _env_buf(n, 0.005, dur * 0.7)
	var noise := _noise
	var base: int = (int(SOUND_SEEDS["candle"]) * 733) & NOISE_MASK
	var lut := _sin_lut
	var lp := 0.0
	var inc: float = 1568.0 * float(SIN_LUT_SIZE) / float(MIX_RATE)
	var inc2: float = 2093.0 * float(SIN_LUT_SIZE) / float(MIX_RATE)
	var ph := 0.0
	var ph2 := 0.0
	var d1 := 1.0
	var mul: float = exp(-12.0 / float(MIX_RATE))
	var puff_dec := 1.0
	var puff_mul: float = exp(-30.0 / float(MIX_RATE))
	for i in n:
		lp += 0.5 * (noise[(base + i) & NOISE_MASK] - lp)
		var tone := (lut[int(ph) & SIN_LUT_MASK] * 0.5 + lut[int(ph2) & SIN_LUT_MASK] * 0.25) * d1
		var puff := lp * puff_dec * 0.5
		buf[i] = (tone + puff) * env[i]
		ph += inc
		ph2 += inc2
		d1 *= mul
		puff_dec *= puff_mul
	return buf


func _gen_reveal() -> PackedFloat32Array:
	var dur: float = 1.0
	var buf := _mk(dur)
	var n: int = buf.size()
	var env := _env_buf(n, 0.15, dur * 0.4)
	var win := _win_buf(n)
	var lut := _sin_lut
	var ph1 := 0.0
	var ph2 := 0.0
	var ph3 := 0.0
	var trem := 0.0
	var trem_inc: float = 7.0 * float(SIN_LUT_SIZE) / float(MIX_RATE)
	for i in n:
		var u: float = float(i) / float(n)
		var f: float = 220.0 + (880.0 - 220.0) * u * u
		var inc: float = f * float(SIN_LUT_SIZE) / float(MIX_RATE)
		var v := lut[int(ph1) & SIN_LUT_MASK] * 0.6
		v += lut[int(ph2) & SIN_LUT_MASK] * 0.28
		v += lut[int(ph3) & SIN_LUT_MASK] * 0.14
		var am := 0.8 + 0.2 * lut[int(trem) & SIN_LUT_MASK]
		buf[i] = v * am * env[i] * win[i]
		ph1 += inc
		ph2 += inc * 1.5
		ph3 += inc * 2.51
		trem += trem_inc
	return buf


func _gen_note() -> PackedFloat32Array:
	var dur: float = 0.35
	var buf := _mk(dur)
	var n: int = buf.size()
	var win := _win_buf(n)
	var noise := _noise
	var base: int = (int(SOUND_SEEDS["note"]) * 193) & NOISE_MASK
	var lut := _sin_lut
	var lp := 0.0
	var lp2 := 0.0
	var am := 0.0
	var am_inc: float = 17.0 * float(SIN_LUT_SIZE) / float(MIX_RATE)
	var cut_am := 0.0
	var cut_inc: float = 11.0 * float(SIN_LUT_SIZE) / float(MIX_RATE)
	for i in n:
		var x := noise[(base + i) & NOISE_MASK]
		var cut: float = 0.35 + 0.22 * lut[int(cut_am) & SIN_LUT_MASK]
		if cut < 0.02:
			cut = 0.02
		lp += cut * (x - lp)
		lp2 += cut * (lp - lp2)
		var band := lp - lp2
		buf[i] = band * 3.0 * (0.55 + 0.45 * lut[int(am) & SIN_LUT_MASK]) * win[i]
		am += am_inc
		cut_am += cut_inc
	return buf


func _gen_dig() -> PackedFloat32Array:
	var dur: float = 0.55
	var buf := _mk(dur)
	var n: int = buf.size()
	var win := _win_buf(n)
	var noise := _noise
	var base: int = (int(SOUND_SEEDS["dig"]) * 347) & NOISE_MASK
	var lut := _sin_lut
	var lp := 0.0
	var g1 := 0.0
	var g2 := 0.0
	var g3 := 0.0
	var i1: float = 23.0 * float(SIN_LUT_SIZE) / float(MIX_RATE)
	var i2: float = 47.0 * float(SIN_LUT_SIZE) / float(MIX_RATE)
	var i3: float = 9.0 * float(SIN_LUT_SIZE) / float(MIX_RATE)
	for i in n:
		var x := noise[(base + i) & NOISE_MASK]
		var cut: float = 0.12 + 0.09 * lut[int(g1) & SIN_LUT_MASK]
		if cut < 0.02:
			cut = 0.02
		lp += cut * (x - lp)
		var grit := 0.6 + 0.4 * lut[int(g2) & SIN_LUT_MASK] * lut[int(g3) & SIN_LUT_MASK]
		buf[i] = (lp * 1.5 + x * 0.12) * grit * win[i]
		g1 += i1
		g2 += i2
		g3 += i3
	return buf


func _gen_save() -> PackedFloat32Array:
	var dur: float = 0.7
	var buf := _mk(dur)
	var n: int = buf.size()
	var lut := _sin_lut
	var p1 := 0.0
	var p2 := 0.0
	var p3 := 0.0
	var i1: float = 523.25 * float(SIN_LUT_SIZE) / float(MIX_RATE)
	var i2: float = 783.99 * float(SIN_LUT_SIZE) / float(MIX_RATE)
	var i3: float = 1046.5 * float(SIN_LUT_SIZE) / float(MIX_RATE)
	var d1 := 1.0
	var d2 := 1.0
	var d3 := 1.0
	var m1: float = exp(-4.0 / float(MIX_RATE))
	var m2: float = exp(-5.0 / float(MIX_RATE))
	var m3: float = exp(-7.0 / float(MIX_RATE))
	var start2: int = int(0.12 * float(MIX_RATE))
	for i in n:
		var v := 0.0
		if i < start2:
			v = lut[int(p1) & SIN_LUT_MASK] * d1 * 0.8
		else:
			v = lut[int(p2) & SIN_LUT_MASK] * d2 * 0.7 + lut[int(p3) & SIN_LUT_MASK] * d3 * 0.3
		buf[i] = v
		p1 += i1
		p2 += i2
		p3 += i3
		d1 *= m1
		d2 *= m2
		d3 *= m3
	return buf


func _gen_boss() -> PackedFloat32Array:
	var dur: float = 1.1
	var buf := _mk(dur)
	var n: int = buf.size()
	var env := _env_buf(n, 0.01, dur * 0.55)
	var win := _win_buf(n)
	var noise := _noise
	var base: int = (int(SOUND_SEEDS["boss"]) * 991) & NOISE_MASK
	var lut := _sin_lut
	var lp := 0.0
	var ph := 0.0
	var ph2 := 0.0
	var ph3 := 0.0
	var f_step: float = -46.0 * 0.18 / float(maxi(1, n))
	for i in n:
		var f: float = 46.0 + f_step * float(i)
		var inc: float = f * float(SIN_LUT_SIZE) / float(MIX_RATE)
		lp += 0.05 * (noise[(base + i) & NOISE_MASK] - lp)
		var tone := lut[int(ph) & SIN_LUT_MASK] * 0.9
		tone += lut[int(ph2) & SIN_LUT_MASK] * 0.35
		tone += lut[int(ph3) & SIN_LUT_MASK] * 0.18
		buf[i] = (tone + lp * 1.1) * env[i] * (0.7 + 0.3 * win[i])
		ph += inc
		ph2 += inc * 2.0
		ph3 += inc * 3.01
	return buf


func _gen_scream() -> PackedFloat32Array:
	var dur: float = 0.9
	var buf := _mk(dur)
	var n: int = buf.size()
	var env := _env_buf(n, 0.06, dur * 0.4)
	var win := _win_buf(n)
	var noise := _noise
	var base: int = (int(SOUND_SEEDS["scream"]) * 557) & NOISE_MASK
	var lut := _sin_lut
	var ph1 := 0.0
	var ph2 := 0.0
	var ph3 := 0.0
	var vib := 0.0
	var vib_inc: float = 6.5 * float(SIN_LUT_SIZE) / float(MIX_RATE)
	var lp := 0.0
	for i in n:
		var f: float = (620.0 + 180.0 * win[i]) * (1.0 + 0.06 * lut[int(vib) & SIN_LUT_MASK])
		var inc: float = f * float(SIN_LUT_SIZE) / float(MIX_RATE)
		lp += 0.6 * (noise[(base + i) & NOISE_MASK] - lp)
		var v := lut[int(ph1) & SIN_LUT_MASK] * 0.6 + lut[int(ph2) & SIN_LUT_MASK] * 0.5
		v += lut[int(ph3) & SIN_LUT_MASK] * 0.25 + lp * 0.3
		v = v / (1.0 + absf(v)) * 1.6
		buf[i] = v * env[i]
		ph1 += inc
		ph2 += inc * 1.047
		ph3 += inc * 0.5
		vib += vib_inc
	return buf


# ---------------------------------------------------------------------------
# Ambient generators (all built at 7.0 s, stored as 6.5 s seamless loops)
# ---------------------------------------------------------------------------

func _gen_ambient(kind: String) -> PackedFloat32Array:
	var raw := PackedFloat32Array()
	match kind:
		"hospital":
			raw = _amb_hospital()
		"cemetery":
			raw = _amb_cemetery()
		"prison":
			raw = _amb_prison()
		"church":
			raw = _amb_church()
		"menu":
			raw = _amb_menu()
		_:
			return raw
	if raw.size() == 0:
		return raw
	raw = _loopify(raw, LOOP_FADE)
	_normalize(raw, AMBIENT_PEAK)
	return raw


## Distant creak: a wobbling resonant tone with a half-sine window.
func _add_creak(buf: PackedFloat32Array, t0: float, amp: float) -> void:
	var n: int = buf.size()
	var start: int = int(t0 * float(MIX_RATE))
	if start < 0 or start >= n:
		return
	var ln: int = mini(n - start, int(1.3 * float(MIX_RATE)))
	if ln <= 2:
		return
	var win := _win_buf(ln)
	var lut := _sin_lut
	var ph1 := 0.0
	var ph2 := 0.0
	var w := 0.0
	var w_inc: float = 2.2 * float(SIN_LUT_SIZE) / float(MIX_RATE)
	for i in ln:
		var f: float = 195.0 + 30.0 * lut[int(w) & SIN_LUT_MASK]
		var inc: float = f * float(SIN_LUT_SIZE) / float(MIX_RATE)
		ph1 += inc
		ph2 += inc * 2.4
		var e: float = win[i]
		buf[start + i] += (lut[int(ph1) & SIN_LUT_MASK] * 0.12 + lut[int(ph2) & SIN_LUT_MASK] * 0.05) * e * amp
		w += w_inc


func _amb_hospital() -> PackedFloat32Array:
	var buf := _mk(7.0)
	var n: int = buf.size()
	var noise := _noise
	var base: int = 4099
	var lut := _sin_lut
	var lp := 0.0
	var ph1 := 0.0
	var ph2 := 0.0
	var ph3 := 0.0
	var ph4 := 0.0
	var i1: float = 55.0 * float(SIN_LUT_SIZE) / float(MIX_RATE)
	var i2: float = 82.5 * float(SIN_LUT_SIZE) / float(MIX_RATE)
	var i3: float = 110.0 * float(SIN_LUT_SIZE) / float(MIX_RATE)
	var i4: float = 0.125 * float(SIN_LUT_SIZE) / float(MIX_RATE)
	var t_step: float = 1.0 / float(MIX_RATE)
	var cyc := 0.0
	for i in n:
		lp += 0.02 * (noise[(base + i) & NOISE_MASK] - lp)
		var hum := lut[int(ph1) & SIN_LUT_MASK] * 0.55
		hum += lut[int(ph2) & SIN_LUT_MASK] * 0.22
		hum += lut[int(ph3) & SIN_LUT_MASK] * 0.12
		var breathe := 0.82 + 0.18 * lut[int(ph4) & SIN_LUT_MASK]
		cyc += t_step
		if cyc >= 4.0:
			cyc -= 4.0
		var v := hum * breathe + lp * 0.45
		if cyc < 0.5:
			v += lut[int((52.0 - 14.0 * cyc) * cyc * float(SIN_LUT_SIZE)) & SIN_LUT_MASK] * exp(-cyc * 9.0) * 0.55
		buf[i] = v
		ph1 += i1
		ph2 += i2
		ph3 += i3
		ph4 += i4
	return buf


func _amb_cemetery() -> PackedFloat32Array:
	var buf := _mk(7.0)
	var n: int = buf.size()
	var noise := _noise
	var base: int = 8191
	var lut := _sin_lut
	var lp := 0.0
	var g1 := 0.0
	var g2 := 0.0
	var g3 := 0.0
	var i1: float = 0.11 * float(SIN_LUT_SIZE) / float(MIX_RATE)
	var i2: float = 0.037 * float(SIN_LUT_SIZE) / float(MIX_RATE)
	var i3: float = 41.0 * float(SIN_LUT_SIZE) / float(MIX_RATE)
	for i in n:
		lp += 0.05 * (noise[(base + i) & NOISE_MASK] - lp)
		var gust: float = 0.55 + 0.45 * lut[int(g1) & SIN_LUT_MASK] * lut[int(g2) & SIN_LUT_MASK]
		buf[i] = lp * 2.2 * gust + lut[int(g3) & SIN_LUT_MASK] * 0.1
		g1 += i1
		g2 += i2
		g3 += i3
	_add_creak(buf, 2.6, 1.0)
	_add_creak(buf, 5.6, 0.85)
	return buf


func _amb_prison() -> PackedFloat32Array:
	var buf := _mk(7.0)
	var n: int = buf.size()
	var rng := _rng_seed(5003)
	var noise := _noise
	var base: int = 12287
	var lut := _sin_lut
	var lp := 0.0
	var ph := 0.0
	var inc: float = 43.0 * float(SIN_LUT_SIZE) / float(MIX_RATE)
	for i in n:
		lp += 0.03 * (noise[(base + i) & NOISE_MASK] - lp)
		buf[i] = lp * 1.1 + lut[int(ph) & SIN_LUT_MASK] * 0.12
		ph += inc
	var t_drop := 0.7
	for k in 8:
		_add_drop(buf, t_drop, 0.55)
		t_drop += rng.randf_range(0.55, 1.25)
	var t_clang := 1.9
	for k in 3:
		_add_clang(buf, t_clang, rng, 0.35)
		t_clang += rng.randf_range(1.8, 3.0)
	return buf


func _amb_church() -> PackedFloat32Array:
	var buf := _mk(7.0)
	var n: int = buf.size()
	var noise := _noise
	var base: int = 16381
	var lut := _sin_lut
	var amps := PackedFloat32Array([1.0, 0.55, 0.32, 0.2])
	for h in amps.size():
		var f: float = 55.0 * float(h + 1)
		var a: float = amps[h]
		var inc: float = f * float(SIN_LUT_SIZE) / float(MIX_RATE)
		var ph := 0.0
		for i in n:
			buf[i] += lut[int(ph) & SIN_LUT_MASK] * a
			ph += inc
	var lp := 0.0
	var c1 := 0.0
	var c2 := 0.0
	var m1 := 0.0
	var m2 := 0.0
	var s1 := 0.0
	var ic1: float = 440.0 * float(SIN_LUT_SIZE) / float(MIX_RATE)
	var ic2: float = 660.2 * float(SIN_LUT_SIZE) / float(MIX_RATE)
	var im1: float = 0.15 * float(SIN_LUT_SIZE) / float(MIX_RATE)
	var im2: float = 0.11 * float(SIN_LUT_SIZE) / float(MIX_RATE)
	var is1: float = 0.08 * float(SIN_LUT_SIZE) / float(MIX_RATE)
	for i in n:
		lp += 0.01 * (noise[(base + i) & NOISE_MASK] - lp)
		var choir := lut[int(c1) & SIN_LUT_MASK] * 0.05 * (0.6 + 0.4 * lut[int(m1) & SIN_LUT_MASK])
		choir += lut[int(c2) & SIN_LUT_MASK] * 0.035 * (0.6 + 0.4 * lut[int(m2) & SIN_LUT_MASK])
		var swell := 0.75 + 0.25 * lut[int(s1) & SIN_LUT_MASK]
		buf[i] = (buf[i] + choir + lp * 0.6) * swell
		c1 += ic1
		c2 += ic2
		m1 += im1
		m2 += im2
		s1 += is1
	return buf


func _amb_menu() -> PackedFloat32Array:
	var buf := _mk(7.0)
	var n: int = buf.size()
	var noise := _noise
	var base: int = 20479
	var lut := _sin_lut
	var lp := 0.0
	var p1 := 0.0
	var p2 := 0.0
	var p3 := 0.0
	var p4 := 0.0
	var p5 := 0.0
	var i1: float = 30.0 * float(SIN_LUT_SIZE) / float(MIX_RATE)
	var i2: float = 30.7 * float(SIN_LUT_SIZE) / float(MIX_RATE)
	var i3: float = 45.2 * float(SIN_LUT_SIZE) / float(MIX_RATE)
	var i4: float = 90.5 * float(SIN_LUT_SIZE) / float(MIX_RATE)
	var i5: float = 0.09 * float(SIN_LUT_SIZE) / float(MIX_RATE)
	for i in n:
		lp += 0.015 * (noise[(base + i) & NOISE_MASK] - lp)
		var v := lut[int(p1) & SIN_LUT_MASK] * 0.7
		v += lut[int(p2) & SIN_LUT_MASK] * 0.5
		v += lut[int(p3) & SIN_LUT_MASK] * 0.28
		v += lut[int(p4) & SIN_LUT_MASK] * 0.1
		var swell := 0.7 + 0.3 * lut[int(p5) & SIN_LUT_MASK]
		buf[i] = (v * 0.6 + lp * 0.9) * swell
		p1 += i1
		p2 += i2
		p3 += i3
		p4 += i4
		p5 += i5
	return buf
