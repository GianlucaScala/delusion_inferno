extends Node
## Autoload "Game": Eingaben, Funk-Untertitel, Auftrag, Logs, Dialoge und der
## Fortschritt (Layer, XP, Attribute, Schrott, Story-Flags), der zwischen
## Layern erhalten bleibt und in user://inferno_save.json gespeichert wird.

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
signal scrap_changed
signal layer_changing(title: String, sub: String)
signal dialogue_changed(speaker: String, text: String, choices: Array)
signal dialogue_ended
signal dialogue_event(event: String)

const SAVE_PATH := "user://inferno_save.json"

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
		"desc": "+6 m Seillänge, schneller nachladen, härtere Klaue.",
	},
}

var player: Node3D
var reading := false
var menu_open := false
var ended := false
var objective := ""
var talking := false
var transitioning := false
var flags := {}                 # Story-Zustand: "name" -> true (wird gespeichert)

var layer := 1                  # aktuelle Ebene des Inferno
var level := 1                  # Stufe der Spielfigur
var xp := 0
var skill_points := 0
var stats := {"fleisch": 0, "waffe": 0, "arm": 0}
var scrap := 0
var upgrades := {}              # beim Krämer gekauft: "id" -> true
var saved_checkpoint = null     # {"pos": [x, y, z], "yaw": float} oder null
var saving_enabled := true
var booted := false

var _talk := {}
var _talk_id := ""
var _talk_node := {}
var _talk_choices: Array = []

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
	elif not _queue.is_empty() and not reading and not talking:
		var line: Array = _queue.pop_front()
		_line_active = true
		_line_left = line[2]
		subtitle_shown.emit(line[0], line[1])


## True, solange noch Funksprüche laufen oder warten.
func speaking() -> bool:
	return _line_active or not _queue.is_empty()


## True, solange die Spielfigur nicht gesteuert werden soll.
func busy() -> bool:
	return reading or menu_open or ended or talking or transitioning


# --- Erzählung ----------------------------------------------------------

## Funkspruch in die Warteschlange. Dauer wird aus der Textlänge geschätzt.
func say(speaker: String, text: String, duration := 0.0) -> void:
	if duration <= 0.0:
		duration = clampf(1.6 + text.length() * 0.055, 2.5, 9.0)
	_queue.append([speaker, text, duration])


func set_objective(text: String) -> void:
	objective = text
	objective_changed.emit(text)


func has_flag(flag: String) -> bool:
	return flags.has(flag)


func set_flag(flag: String) -> void:
	flags[flag] = true


## Rücksetzpunkt merken und speichern.
func checkpoint(pos: Vector3, yaw: float) -> void:
	if player:
		player.set_checkpoint(pos, yaw)
	saved_checkpoint = {"pos": [pos.x, pos.y, pos.z], "yaw": yaw}
	save()


# --- Dialoge ------------------------------------------------------------
# Ein Gespräch ist ein Dictionary aus Knoten:
#   "start": {"who": "FISHER", "text": "...", "next": "a"}
#   "a":     {"who": "FISHER", "text": "...", "choices": [{"text": "...", "next": "b"}]}
# Knoten und Antworten können tragen:
#   "set": Flag setzen     "event": Signal dialogue_event     "xp" / "scrap": Belohnung (einmalig)
#   "if" / "unless": Antwort nur zeigen, wenn Flag (nicht) gesetzt
#   "cost" + "buy": Antwort kostet Schrott und schaltet ein Upgrade frei

func start_talk(id: String, tree: Dictionary, start := "start") -> void:
	if talking or tree.is_empty():
		return
	talking = true
	_talk = tree
	_talk_id = id
	_show_talk(start)


func _show_talk(key: String) -> void:
	if key == "" or not _talk.has(key):
		_end_talk()
		return
	_talk_node = _talk[key]
	_apply_effects(_talk_node, "%s:%s" % [_talk_id, key])
	_talk_choices = []
	for choice in _talk_node.get("choices", []):
		if choice.has("if") and not has_flag(choice["if"]):
			continue
		if choice.has("unless") and has_flag(choice["unless"]):
			continue
		if choice.has("buy") and upgrades.has(choice["buy"]):
			continue
		_talk_choices.append(choice)
	var labels: Array = []
	for choice in _talk_choices:
		var label: String = choice["text"]
		if choice.has("cost"):
			label += "   [%d Schrott]" % choice["cost"]
		labels.append(label)
	dialogue_changed.emit(_talk_node.get("who", ""), _talk_node.get("text", ""), labels)


func _apply_effects(node: Dictionary, once_key: String) -> void:
	if node.has("set"):
		set_flag(node["set"])
	if (node.has("xp") or node.has("scrap")) and not has_flag("reward:" + once_key):
		set_flag("reward:" + once_key)
		if node.has("xp"):
			add_xp(node["xp"])
		if node.has("scrap"):
			add_scrap(node["scrap"])
	if node.has("event"):
		dialogue_event.emit(node["event"])


## Weiter, wenn der Knoten keine Antworten hat.
func talk_advance() -> void:
	if talking and _talk_choices.is_empty():
		_show_talk(_talk_node.get("next", ""))


func talk_choose(index: int) -> void:
	if not talking or index < 0 or index >= _talk_choices.size():
		return
	var choice: Dictionary = _talk_choices[index]
	if choice.has("cost"):
		if scrap < choice["cost"]:
			_show_talk(choice.get("broke", "broke"))
			return
		add_scrap(-choice["cost"])
		upgrades[choice["buy"]] = true
		stats_changed.emit()
	_apply_effects(choice, "%s:choice:%s" % [_talk_id, choice["text"]])
	_show_talk(choice.get("next", ""))


func _end_talk() -> void:
	talking = false
	_talk = {}
	_talk_choices = []
	dialogue_ended.emit()
	save()


# --- Layer & Speichern --------------------------------------------------

## Blendet ab, wechselt die Ebene und lädt die Szene neu.
func goto_layer(target: int, title: String, sub: String) -> void:
	if transitioning:
		return
	transitioning = true
	layer_changing.emit(title, sub)
	await get_tree().create_timer(4.0).timeout
	layer = target
	saved_checkpoint = null
	flags.erase("objective")
	save()
	reset_transient()
	get_tree().reload_current_scene()


## Alles, was nur für die laufende Szene gilt.
func reset_transient() -> void:
	reading = false
	menu_open = false
	ended = false
	talking = false
	transitioning = false
	objective = ""
	_queue.clear()
	_line_active = false
	_gap_left = 0.0
	_talk = {}
	get_tree().paused = false


func new_game() -> void:
	layer = 1
	level = 1
	xp = 0
	skill_points = 0
	stats = {"fleisch": 0, "waffe": 0, "arm": 0}
	scrap = 0
	upgrades = {}
	flags = {}
	saved_checkpoint = null
	reset_transient()
	save()


func to_save() -> Dictionary:
	return {
		"version": 1, "layer": layer, "level": level, "xp": xp, "skill_points": skill_points,
		"stats": stats, "scrap": scrap, "upgrades": upgrades, "flags": flags,
		"checkpoint": saved_checkpoint, "objective": objective,
	}


func from_save(data: Dictionary) -> void:
	layer = int(data.get("layer", 1))
	level = int(data.get("level", 1))
	xp = int(data.get("xp", 0))
	skill_points = int(data.get("skill_points", 0))
	stats = {"fleisch": 0, "waffe": 0, "arm": 0}
	for key in data.get("stats", {}):
		stats[key] = int(data["stats"][key])
	scrap = int(data.get("scrap", 0))
	upgrades = data.get("upgrades", {})
	flags = data.get("flags", {})
	saved_checkpoint = data.get("checkpoint", null)
	objective = str(data.get("objective", ""))


func save() -> void:
	if not saving_enabled:
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(to_save(), "\t"))


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func load_save() -> bool:
	if not has_save():
		return false
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if typeof(data) != TYPE_DICTIONARY:
		return false
	from_save(data)
	return true


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


func add_scrap(amount: int) -> void:
	scrap = maxi(scrap + amount, 0)
	scrap_changed.emit()


func spend_point(stat: String) -> bool:
	if skill_points <= 0 or not stats.has(stat):
		return false
	skill_points -= 1
	stats[stat] += 1
	stats_changed.emit()
	save()
	return true


func max_health() -> float:
	return 100.0 + stats["fleisch"] * 20.0 + (25.0 if upgrades.has("plating") else 0.0)


func gas_charges() -> float:
	return 3.0 if upgrades.has("gas_tank") else 2.0


func cool_mult() -> float:
	return 1.5 if upgrades.has("cooling") else 1.0


func damage_mult() -> float:
	return 1.0 + stats["waffe"] * 0.15


func heat_mult() -> float:
	return pow(0.9, stats["waffe"])


func grapple_range() -> float:
	return 38.0 + stats["arm"] * 6.0


func grapple_cooldown() -> float:
	return 0.45 * pow(0.85, stats["arm"])


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
	_keys("interact", [KEY_E, KEY_ENTER])
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
