extends Node
## Autoload "Sfx": spielt die WAVs aus res://audio/.
##
##   Sfx.play("shot")                         einmalig, ohne Ort
##   Sfx.play_at("enemy_shot", position)      einmalig, im Raum
##   Sfx.loop("wind_loop", 0.6, 1.2)          Dauerton: jede Frame Lautstärke (0..1) und Tonhöhe setzen
##
## Die Dateien sind Platzhalter aus tools/gen_audio.py. Wer eine Datei gleichen
## Namens ersetzt, ersetzt den Sound; hier muss nichts geändert werden.

const DIR := "res://audio/"

## Grundlautstärke pro Sound in dB. Alles, was hier fehlt, spielt mit 0 dB.
const GAIN := {
	"shot": -7.0, "shot_dry": -6.0, "impact": -9.0,
	"enemy_hit": -6.0, "enemy_die": -3.0, "enemy_alert": -9.0, "enemy_charge": -8.0, "enemy_shot": -4.0,
	"hook_fire": -4.0, "hook_hit": -2.0, "reel_loop": -17.0, "wind_loop": -5.0,
	"gas": -1.0, "whoosh": -7.0, "claw_hit": -5.0,
	"step1": -15.0, "step2": -15.0, "jump": -14.0, "land": -8.0, "hurt": -6.0, "death": -4.0,
	"radio": -14.0, "ui_open": -16.0, "ui_close": -16.0, "ui_spend": -8.0, "levelup": -7.0, "objective": -16.0,
	"boss_charge": -5.0, "boss_slam": -1.0, "boss_fan": -4.0, "boss_roar": -3.0, "boss_die": -1.0,
	"door_loop": -6.0, "door_stop": -3.0,
	"title": -4.0, "ambient_loop": -15.0, "boss_music_loop": -13.0,
}

var _streams := {}
var _loops := {}          # key -> {player, target, pitch}
var _music := {}          # key -> {player, target}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_bus("SFX")
	_ensure_bus("Music")
	for key in GAIN:
		var path: String = DIR + key + ".wav"
		if not ResourceLoader.exists(path):
			push_warning("Sound fehlt: " + path)
			continue
		var stream: AudioStreamWAV = load(path)
		if key.ends_with("_loop"):
			stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
			stream.loop_begin = 0
			stream.loop_end = int(round(stream.get_length() * stream.mix_rate))
		_streams[key] = stream

	Game.subtitle_shown.connect(func(_speaker: String, _text: String) -> void: play("radio"))
	Game.objective_changed.connect(func(_text: String) -> void: play("objective"))
	Game.toast.connect(func(_text: String) -> void: play("levelup"))
	Game.log_opened.connect(func(_title: String, _body: String) -> void: play("ui_open"))
	Game.log_closed.connect(func() -> void: play("ui_close"))
	Game.title_card.connect(func(_title: String, _sub: String) -> void: play("title"))
	Game.boss_started.connect(func(_boss: Node, _boss_name: String) -> void:
		play("boss_roar")
		music("boss_music_loop", 1.0)
		music("ambient_loop", 0.35))
	Game.boss_ended.connect(func() -> void:
		music("boss_music_loop", 0.0)
		music("ambient_loop", 1.0))
	Game.ending_started.connect(func(_title: String, _body: String) -> void:
		play("title", 0.0, 0.75)
		music("ambient_loop", 0.25))
	music("ambient_loop", 1.0)


func _ensure_bus(bus: String) -> void:
	if AudioServer.get_bus_index(bus) == -1:
		AudioServer.add_bus()
		AudioServer.set_bus_name(AudioServer.bus_count - 1, bus)


func _gain(key: String) -> float:
	return GAIN.get(key, 0.0)


# --- Einzelne Sounds ----------------------------------------------------

func play(key: String, volume_db := 0.0, pitch := 1.0, pitch_var := 0.0) -> void:
	if not _streams.has(key):
		return
	var p := AudioStreamPlayer.new()
	p.stream = _streams[key]
	p.bus = "SFX"
	p.volume_db = _gain(key) + volume_db
	p.pitch_scale = maxf(pitch + randf_range(-pitch_var, pitch_var), 0.05)
	add_child(p)
	p.finished.connect(p.queue_free)
	p.play()


func play_at(key: String, pos: Vector3, volume_db := 0.0, pitch := 1.0, pitch_var := 0.0) -> void:
	if not _streams.has(key):
		return
	var p := AudioStreamPlayer3D.new()
	p.stream = _streams[key]
	p.bus = "SFX"
	p.volume_db = _gain(key) + volume_db
	p.pitch_scale = maxf(pitch + randf_range(-pitch_var, pitch_var), 0.05)
	p.unit_size = 12.0
	p.max_distance = 140.0
	p.position = pos
	add_child(p)
	p.finished.connect(p.queue_free)
	p.play()


# --- Dauertöne ----------------------------------------------------------

## Lautstärke 0..1 und Tonhöhe eines Dauertons setzen. 0 blendet ihn aus.
func loop(key: String, volume: float, pitch := 1.0) -> void:
	if not _streams.has(key):
		return
	if not _loops.has(key):
		if volume <= 0.0:
			return
		var p := AudioStreamPlayer.new()
		p.stream = _streams[key]
		p.bus = "SFX"
		p.volume_db = -80.0
		add_child(p)
		_loops[key] = {"player": p, "target": 0.0, "level": 0.0}
	var entry: Dictionary = _loops[key]
	entry["target"] = clampf(volume, 0.0, 1.0)
	entry["player"].pitch_scale = clampf(pitch, 0.2, 3.0)


func stop_loops() -> void:
	for key in _loops:
		_loops[key]["target"] = 0.0


## Musik/Ambiente auf dem Music-Bus. level 0..1, wird weich überblendet.
func music(key: String, level: float) -> void:
	if not _streams.has(key):
		return
	if not _music.has(key):
		var p := AudioStreamPlayer.new()
		p.stream = _streams[key]
		p.bus = "Music"
		p.volume_db = -80.0
		add_child(p)
		_music[key] = {"player": p, "target": 0.0, "level": 0.0}
	_music[key]["target"] = clampf(level, 0.0, 1.0)


func _process(delta: float) -> void:
	_fade(_loops, delta, 9.0)
	_fade(_music, delta, 0.6)


func _fade(table: Dictionary, delta: float, speed: float) -> void:
	for key in table:
		var entry: Dictionary = table[key]
		var p: AudioStreamPlayer = entry["player"]
		entry["level"] = move_toward(entry["level"], entry["target"], speed * delta)
		if entry["level"] <= 0.001:
			if p.playing:
				p.stop()
			continue
		if not p.playing:
			p.play()
		p.volume_db = _gain(key) + linear_to_db(entry["level"])
