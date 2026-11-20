extends Node

const SAMPLE_RATE: int = 22050
const CUSTOM_SFX_DIR: String = "res://assets/audio/sfx/"

var _streams: Dictionary = {}
var _player: AudioStreamPlayer = null

func _ready() -> void:
	_player = AudioStreamPlayer.new()
	_player.name = "GlobalSFXPlayer"
	_player.bus = &"Master"
	_player.max_polyphony = 6
	add_child(_player)

	_register_sfx(&"kick", _synth_kick())
	_register_sfx(&"post", _synth_tone(620.0, 290.0, 0.22, 0.35, true))
	_register_sfx(&"goal", _synth_fanfare())
	_register_sfx(&"whistle", _synth_whistle())
	_register_sfx(&"card", _synth_tone(540.0, 820.0, 0.08, 0.22, false))
	_register_sfx(&"cash", _synth_double_chime(880.0, 1320.0))
	_register_sfx(&"door", _synth_tone(210.0, 140.0, 0.11, 0.25, false))
	_register_sfx(&"click", _synth_tone(680.0, 740.0, 0.04, 0.16, false))
	_register_sfx(&"level_up", _synth_double_chime(660.0, 1100.0))

func _register_sfx(sfx_name: StringName, fallback: AudioStreamWAV) -> void:
	var custom_wav: String = CUSTOM_SFX_DIR + String(sfx_name) + ".wav"
	if ResourceLoader.exists(custom_wav):
		var loaded: Resource = load(custom_wav)
		if loaded is AudioStream:
			_streams[sfx_name] = loaded
			return
	_streams[sfx_name] = fallback

func play(sfx_name: StringName, pitch_jitter: float = 0.05) -> void:
	if _player == null or not _streams.has(sfx_name):
		return
	_player.stream = _streams[sfx_name] as AudioStream
	_player.pitch_scale = randf_range(1.0 - pitch_jitter, 1.0 + pitch_jitter)
	_player.play()

func play_kick() -> void: play(&"kick", 0.08)
func play_post() -> void: play(&"post", 0.05)
func play_goal() -> void: play(&"goal", 0.02)
func play_whistle() -> void: play(&"whistle", 0.02)
func play_card() -> void: play(&"card", 0.08)
func play_cash() -> void: play(&"cash", 0.03)
func play_door() -> void: play(&"door", 0.06)
func play_click() -> void: play(&"click", 0.05)
func play_level_up() -> void: play(&"level_up", 0.02)

func _build_wav(samples: PackedFloat32Array) -> AudioStreamWAV:
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = SAMPLE_RATE
	wav.stereo = false
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in range(samples.size()):
		var v: int = clampi(int(samples[i] * 32767.0), -32768, 32767)
		bytes.encode_s16(i * 2, v)
	wav.data = bytes
	return wav

func _synth_kick() -> AudioStreamWAV:
	var count: int = int(SAMPLE_RATE * 0.11)
	var arr := PackedFloat32Array()
	arr.resize(count)
	var phase: float = 0.0
	for i in count:
		var t: float = float(i) / float(count)
		var freq: float = lerpf(185.0, 52.0, t)
		phase += TAU * freq / float(SAMPLE_RATE)
		var env: float = (1.0 - t) * (1.0 - t)
		arr[i] = sin(phase) * env * 0.48
	return _build_wav(arr)

func _synth_tone(f0: float, f1: float, dur: float, vol: float, metallic: bool) -> AudioStreamWAV:
	var count: int = int(SAMPLE_RATE * dur)
	var arr := PackedFloat32Array()
	arr.resize(count)
	var phase: float = 0.0
	for i in count:
		var t: float = float(i) / float(count)
		var freq: float = lerpf(f0, f1, t)
		phase += TAU * freq / float(SAMPLE_RATE)
		var env: float = 1.0 - t
		var s: float = sin(phase)
		if metallic:
			s = (s + 0.45 * sin(phase * 2.7)) * 0.7
		arr[i] = s * env * vol
	return _build_wav(arr)

func _synth_double_chime(f0: float, f1: float) -> AudioStreamWAV:
	var count: int = int(SAMPLE_RATE * 0.24)
	var arr := PackedFloat32Array()
	arr.resize(count)
	var phase: float = 0.0
	for i in count:
		var t: float = float(i) / float(count)
		var freq: float = f0 if t < 0.45 else f1
		phase += TAU * freq / float(SAMPLE_RATE)
		var env: float = (1.0 - t) * 0.9
		arr[i] = sin(phase) * env * 0.28
	return _build_wav(arr)

func _synth_whistle() -> AudioStreamWAV:
	var count: int = int(SAMPLE_RATE * 0.34)
	var arr := PackedFloat32Array()
	arr.resize(count)
	var phase: float = 0.0
	for i in count:
		var t: float = float(i) / float(count)
		var trill: float = 2750.0 + sin(t * TAU * 22.0) * 180.0
		phase += TAU * trill / float(SAMPLE_RATE)
		var env: float = minf(t * 14.0, 1.0) * (1.0 - t * 0.85)
		arr[i] = sin(phase) * env * 0.22
	return _build_wav(arr)

func _synth_fanfare() -> AudioStreamWAV:
	var count: int = int(SAMPLE_RATE * 0.48)
	var arr := PackedFloat32Array()
	arr.resize(count)
	var phase: float = 0.0
	for i in count:
		var t: float = float(i) / float(count)
		var freq: float = 523.25 if t < 0.28 else (659.25 if t < 0.56 else 783.99)
		phase += TAU * freq / float(SAMPLE_RATE)
		var env: float = minf(t * 20.0, 1.0) * (1.0 - maxf((t - 0.65) / 0.35, 0.0))
		arr[i] = (sin(phase) + 0.3 * sin(phase * 2.0)) * env * 0.24
	return _build_wav(arr)
