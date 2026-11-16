extends Node
## Autoload "Game": Eingaben, Funk-Untertitel, Auftrag, Logs und der
## RPG-Fortschritt (XP, Level, Attribute), der zwischen Layern erhalten bleibt.

signal subtitle_shown(speaker: String, text: String)
signal subtitle_hidden
signal objective_changed(text: String)
signal log_opened(title: String, body: String)
signal log_closed
signal ending_started(title: String, body: String)
signal title_card(title: String, sub: String)
signal toast(text: String)
signal xp_changed
signal stats_changed
signal boss_started(boss: Node, boss_name: String)
signal boss_ended

const LAYER_WORLD := 1
const LAYER_PLAYER := 2
const LAYER_ENEMY := 4

## Attribute, in die man Punkte stecken kann. Reihenfolge = Tasten 1-3.
const STATS := {
	"fleisch": {
		"name": "FLEISCH",
		"desc": "+20 Integrität. Was noch von dir übrig ist, hält länger.",
	},
	"waffe": {
		"name": "DIENSTWAFFE",
		"desc": "+15 % Schaden, läuft langsamer heiß.",
	},
	"arm": {
		"name": "ARM",
		"desc": "+6 m Hakenreichweite, kürzere Pause, härtere Klaue.",
	},
}

var player: Node3D
var reading := false
var menu_open := false
var ended := false
var objective := ""
var flags := {}

var level := 1
var xp := 0
var skill_points := 0
var stats := {"fleisch": 0, "waffe": 0, "arm": 0}

var _queue: Array = []
var _line_left := 0.0
var _gap_left := 0.0
var _line_active := false
var _log_done: Callable


func _enter_tree() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_input()


func _process(delta: float) -> void:
	if get_tree().paused:
		return
	if _line_active:
		_line_left -= delta
		if _line_left <= 0.0:
			_line_active = false
			_gap_left = 0.35
			subtitle_hidden.emit()
	elif _gap_left > 0.0:
		_gap_left -= delta
	elif not _queue.is_empty() and not reading:
		var line: Array = _queue.pop_front()
		_line_active = true
		_line_left = line[2]
		subtitle_shown.emit(line[0], line[1])


## True, solange die Spielfigur nicht gesteuert werden soll.
func busy() -> bool:
	return reading or menu_open or ended


# --- Erzählung ----------------------------------------------------------

## Funkspruch in die Warteschlange. Dauer wird aus der Textlänge geschätzt.
func say(speaker: String, text: String, duration := 0.0) -> void:
	if duration <= 0.0:
		duration = clampf(1.6 + text.length() * 0.055, 2.5, 9.0)
	_queue.append([speaker, text, duration])


func set_objective(text: String) -> void:
	objective = text
	objective_changed.emit(text)


func open_log(title: String, body: String, on_close := Callable()) -> void:
	reading = true
	_log_done = on_close
	log_opened.emit(title, body)


func close_log() -> void:
	if not reading:
		return
	reading = false
	log_closed.emit()
	if _log_done.is_valid():
		var cb := _log_done
		_log_done = Callable()
		cb.call()


func end_game(title: String, body: String) -> void:
	if ended:
		return
	ended = true
	ending_started.emit(title, body)


# --- RPG ----------------------------------------------------------------

func xp_needed() -> int:
	return 80 + level * 60


func add_xp(amount: int) -> void:
	xp += amount
	while xp >= xp_needed():
		xp -= xp_needed()
		level += 1
		skill_points += 1
		toast.emit("STUFE %d   —   [Tab]  den Arm füttern" % level)
		stats_changed.emit()
	xp_changed.emit()


func spend_point(stat: String) -> bool:
	if skill_points <= 0 or not stats.has(stat):
		return false
	skill_points -= 1
	stats[stat] += 1
	stats_changed.emit()
	return true


func max_health() -> float:
	return 100.0 + stats["fleisch"] * 20.0


func damage_mult() -> float:
	return 1.0 + stats["waffe"] * 0.15


func heat_mult() -> float:
	return pow(0.9, stats["waffe"])


func grapple_range() -> float:
	return 38.0 + stats["arm"] * 6.0


func grapple_cooldown() -> float:
	return 1.1 * pow(0.85, stats["arm"])


func melee_damage() -> float:
	return 45.0 + stats["arm"] * 12.0


# --- Eingaben -----------------------------------------------------------

func _setup_input() -> void:
	_keys("move_forward", [KEY_W, KEY_UP])
	_keys("move_back", [KEY_S, KEY_DOWN])
	_keys("move_left", [KEY_A, KEY_LEFT])
	_keys("move_right", [KEY_D, KEY_RIGHT])
	_keys("jump", [KEY_SPACE])
	_keys("sprint", [KEY_SHIFT])
	_keys("interact", [KEY_E])
	_keys("grapple", [KEY_Q])
	_keys("melee", [KEY_F])
	_keys("upgrade", [KEY_TAB])
	_keys("pause", [KEY_ESCAPE])
	_mouse("fire", MOUSE_BUTTON_LEFT)
	_mouse("aim", MOUSE_BUTTON_RIGHT)
	_mouse("grapple", MOUSE_BUTTON_MIDDLE)

	_pad_axis("move_forward", JOY_AXIS_LEFT_Y, -1.0)
	_pad_axis("move_back", JOY_AXIS_LEFT_Y, 1.0)
	_pad_axis("move_left", JOY_AXIS_LEFT_X, -1.0)
	_pad_axis("move_right", JOY_AXIS_LEFT_X, 1.0)
	_pad_axis("fire", JOY_AXIS_TRIGGER_RIGHT, 1.0)
	_pad_axis("aim", JOY_AXIS_TRIGGER_LEFT, 1.0)
	_pad_button("jump", JOY_BUTTON_A)
	_pad_button("melee", JOY_BUTTON_B)
	_pad_button("interact", JOY_BUTTON_X)
	_pad_button("grapple", JOY_BUTTON_RIGHT_SHOULDER)
	_pad_button("sprint", JOY_BUTTON_LEFT_STICK)
	_pad_button("upgrade", JOY_BUTTON_BACK)
	_pad_button("pause", JOY_BUTTON_START)


func _ensure(action: String) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, 0.3)


func _keys(action: String, keys: Array) -> void:
	_ensure(action)
	for k in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = k
		InputMap.action_add_event(action, ev)


func _mouse(action: String, button: MouseButton) -> void:
	_ensure(action)
	var ev := InputEventMouseButton.new()
	ev.button_index = button
	InputMap.action_add_event(action, ev)


func _pad_button(action: String, button: JoyButton) -> void:
	_ensure(action)
	var ev := InputEventJoypadButton.new()
	ev.button_index = button
	InputMap.action_add_event(action, ev)


func _pad_axis(action: String, axis: JoyAxis, value: float) -> void:
	_ensure(action)
	var ev := InputEventJoypadMotion.new()
	ev.axis = axis
	ev.axis_value = value
	InputMap.action_add_event(action, ev)
