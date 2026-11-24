extends Node

## Phase P12 / P1.1: Adaptive Audio, Drop-In Studio Asset Loader & Procedural SFX Synthesizer.
## Automatically loads custom studio assets from res://assets/audio/{sfx,music,voices}/ when present,
## and seamlessly falls back to zero-dependency synthesized 16-bit PCM SFX otherwise.
## Silent & allocation-free in headless/Dummy test environments.

const SAMPLE_RATE := 22050
const POOL_SIZE := 6

var _clips: Dictionary = {}
var _pool: Array[AudioStreamPlayer] = []
var _pool_idx: int = 0
var _music_player: AudioStreamPlayer
var _voice_player: AudioStreamPlayer
var _current_music: String = ""
var _enabled: bool = true

func _ready() -> void:
	if DisplayServer.get_name() in ["headless", "Dummy"]:
		_enabled = false
		return
	for i in range(POOL_SIZE):
		var p := AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		_pool.append(p)
	_music_player = AudioStreamPlayer.new()
	_music_player.bus = "Master"
	add_child(_music_player)
	_voice_player = AudioStreamPlayer.new()
	_voice_player.bus = "Master"
	add_child(_voice_player)
	_build_all_clips()

func play(sfx_name: String, volume_db: float = -6.0, pitch_jitter: float = 0.06) -> void:
	if not _enabled or _pool.is_empty():
		return
	var stream: AudioStream = _resolve_sfx_stream(sfx_name)
	if stream == null:
		return
	var p: AudioStreamPlayer = _pool[_pool_idx]
	_pool_idx = (_pool_idx + 1) % _pool.size()
	p.stream = stream
	p.volume_db = volume_db
	p.pitch_scale = 1.0 + randf_range(-pitch_jitter, pitch_jitter)
	p.play()

func play_music(track_name: String, volume_db: float = -10.0) -> void:
	if not _enabled or _music_player == null or track_name == _current_music:
		return
	for ext in ["ogg", "mp3", "wav"]:
		var path := "res://assets/audio/music/%s.%s" % [track_name, ext]
		if ResourceLoader.exists(path):
			var st := ResourceLoader.load(path) as AudioStream
			if st:
				_current_music = track_name
				_music_player.stream = st
				_music_player.volume_db = volume_db
				_music_player.play()
				return

func play_voice(char_id: String, line_id: String, volume_db: float = -2.0) -> bool:
	if not _enabled or _voice_player == null:
		return false
	for ext in ["ogg", "wav", "mp3"]:
		var path := "res://assets/audio/voices/%s/%s.%s" % [char_id, line_id, ext]
		if ResourceLoader.exists(path):
			var st := ResourceLoader.load(path) as AudioStream
			if st:
				_voice_player.stream = st
				_voice_player.volume_db = volume_db
				_voice_player.play()
				return true
	return false

func _resolve_sfx_stream(sfx_name: String) -> AudioStream:
	if _clips.has(sfx_name):
		return _clips[sfx_name]
	for ext in ["wav", "ogg", "mp3"]:
		var path := "res://assets/audio/sfx/%s.%s" % [sfx_name, ext]
		if ResourceLoader.exists(path):
			var loaded := ResourceLoader.load(path) as AudioStream
			if loaded:
				_clips[sfx_name] = loaded
				return loaded
	return null

func _build_all_clips() -> void:
	var defaults := {
		"kick": _make_sweep(0.14, 180.0, 58.0, 0.28, true),
		"whip": _make_sweep(0.16, 420.0, 1650.0, 0.55, true),
		"urn": _make_shatter(0.24),
		"chime": _make_chord([523.25, 659.25, 783.99], 0.36, 0.0),
		"chest": _make_chord([392.0, 493.88, 587.33, 783.99], 0.48, 0.06),
		"buy": _make_chord([659.25, 987.77], 0.22, 0.04),
		"ui_click": _make_sweep(0.05, 680.0, 420.0, 0.08, false),
		"rapture": _make_chord([293.66, 440.0, 587.33, 880.0], 0.65, 0.05),
	}
	for k in defaults.keys():
		var loaded: AudioStream = null
		for ext in ["wav", "ogg", "mp3"]:
			var path := "res://assets/audio/sfx/%s.%s" % [k, ext]
			if ResourceLoader.exists(path):
				loaded = ResourceLoader.load(path) as AudioStream
				break
		_clips[k] = loaded if loaded != null else defaults[k]

func _make_wav(samples: PackedByteArray) -> AudioStreamWAV:
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = SAMPLE_RATE
	wav.stereo = false
	wav.data = samples
	return wav

func _make_sweep(dur: float, f0: float, f1: float, noise_mix: float, punchy: bool) -> AudioStreamWAV:
	var n := int(dur * SAMPLE_RATE)
	var data := PackedByteArray()
	data.resize(n * 2)
	var phase := 0.0
	for i in range(n):
		var t := float(i) / float(n)
		var env := pow(1.0 - t, 2.2 if punchy else 1.4)
		var freq := lerpf(f0, f1, t)
		phase += TAU * freq / float(SAMPLE_RATE)
		var tone := sin(phase) * (1.0 - noise_mix) + randf_range(-1.0, 1.0) * noise_mix
		var s := clampi(int(tone * env * 22000.0), -32767, 32767)
		data[i * 2] = s & 0xFF
		data[i * 2 + 1] = (s >> 8) & 0xFF
	return _make_wav(data)

func _make_shatter(dur: float) -> AudioStreamWAV:
	var n := int(dur * SAMPLE_RATE)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in range(n):
		var t := float(i) / float(n)
		var env := pow(1.0 - t, 2.4)
		var tinkle := sin(TAU * 1950.0 * t * dur) * 0.35 + sin(TAU * 2740.0 * t * dur) * 0.25
		var noise := randf_range(-1.0, 1.0) * 0.55
		var s := clampi(int((tinkle + noise) * env * 20000.0), -32767, 32767)
		data[i * 2] = s & 0xFF
		data[i * 2 + 1] = (s >> 8) & 0xFF
	return _make_wav(data)

func _make_chord(freqs: Array, dur: float, arp_step: float) -> AudioStreamWAV:
	var n := int(dur * SAMPLE_RATE)
	var data := PackedByteArray()
	data.resize(n * 2)
	var inv_cnt := 1.0 / maxf(1.0, float(freqs.size()))
	for i in range(n):
		var sec := float(i) / float(SAMPLE_RATE)
		var sum := 0.0
		for fi in range(freqs.size()):
			var start_s := float(fi) * arp_step
			if sec < start_s:
				continue
			var local_t := (sec - start_s) / maxf(0.05, dur - start_s)
			var env := clampf(local_t * 25.0, 0.0, 1.0) * pow(maxf(0.0, 1.0 - local_t), 1.8)
			var f := float(freqs[fi])
			sum += (sin(TAU * f * sec) * 0.75 + sin(TAU * f * 2.0 * sec) * 0.25) * env * inv_cnt
		var s := clampi(int(sum * 24000.0), -32767, 32767)
		data[i * 2] = s & 0xFF
		data[i * 2 + 1] = (s >> 8) & 0xFF
	return _make_wav(data)
