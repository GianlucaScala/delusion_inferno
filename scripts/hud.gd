extends CanvasLayer
## HUD: Fadenkreuz, Zustand, XP, Auftrag, Funk-Untertitel, Bossleiste,
## Log-Fenster und das Attribut-Menü ([Tab]).

const INK := Color(0.86, 0.9, 0.92)
const AMBER := Color(1.0, 0.62, 0.28)
const ENTITY := Color(0.72, 0.38, 1.0)
const BAR_W := 240.0


class Reticle extends Control:
	var spread := 0.0
	var hit := 0.0
	var kill := false
	var aiming := false
	var grapple := false
	var grapple_cd := 0.0
	var gas := 2.0

	func _draw() -> void:
		var c := size * 0.5
		var col := Color(0.9, 0.95, 1.0, 0.85)
		var gap := 5.0 + spread * 10.0 + (0.0 if aiming else 3.0)
		for d in [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN]:
			draw_line(c + d * gap, c + d * (gap + 7.0), col, 2.0)
		draw_rect(Rect2(c - Vector2(1, 1), Vector2(2, 2)), col)
		# Haken: Raute, wenn etwas in Reichweite ist; Bogen, solange er sich erholt
		if grapple:
			var r := 22.0
			var pts := PackedVector2Array([c + Vector2(0, -r), c + Vector2(r, 0), c + Vector2(0, r), c + Vector2(-r, 0), c + Vector2(0, -r)])
			draw_polyline(pts, Color(0.72, 0.38, 1.0, 0.9), 1.5)
		elif grapple_cd > 0.0:
			draw_arc(c, 22.0, -PI * 0.5, -PI * 0.5 + TAU * clampf(grapple_cd, 0.0, 1.0), 24, Color(0.72, 0.38, 1.0, 0.45), 1.5)
		# Gasladungen: zwei kurze Striche unter dem Fadenkreuz
		for i in 2:
			var fill := clampf(gas - i, 0.0, 1.0)
			var x := c.x - 11.0 + i * 12.0
			draw_rect(Rect2(x, c.y + 30.0, 10.0, 3.0), Color(0, 0, 0, 0.45))
			draw_rect(Rect2(x, c.y + 30.0, 10.0 * fill, 3.0), Color(0.86, 0.9, 0.92, 0.85 if fill >= 1.0 else 0.4))
		if hit > 0.0:
			var hc := Color(1.0, 0.3, 0.2, hit) if kill else Color(1, 1, 1, hit)
			for d in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
				draw_line(c + d * 8.0, c + d * 15.0, hc, 2.0)


var _player: Node
var _boss: Node
var _reticle: Reticle
var _health_fill: ColorRect
var _heat_fill: ColorRect
var _heat_label: Label
var _xp_fill: ColorRect
var _level_label: Label
var _objective: Label
var _subtitle: Label
var _prompt: Label
var _toast: Label
var _title: Label
var _title_sub: Label
var _vignette: ColorRect
var _fade: ColorRect
var _log_panel: PanelContainer
var _log_title: Label
var _log_body: Label
var _boss_box: Control
var _boss_name: Label
var _boss_fill: ColorRect
var _menu: PanelContainer
var _menu_points: Label
var _menu_buttons := {}
var _end_title: Label
var _end_body: Label


func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	Game.subtitle_shown.connect(_on_subtitle)
	Game.subtitle_hidden.connect(func() -> void: _subtitle.visible = false)
	Game.objective_changed.connect(_on_objective)
	Game.log_opened.connect(_on_log_opened)
	Game.log_closed.connect(func() -> void: _log_panel.visible = false)
	Game.title_card.connect(_on_title_card)
	Game.ending_started.connect(_on_ending)
	Game.toast.connect(_on_toast)
	Game.xp_changed.connect(_refresh_xp)
	Game.stats_changed.connect(_refresh_xp)
	Game.boss_started.connect(_on_boss_started)
	Game.boss_ended.connect(_on_boss_ended)
	_refresh_xp()
	if Game.objective != "":
		_on_objective(Game.objective)


func bind_player(player: Node) -> void:
	_player = player
	player.health_changed.connect(_on_health)
	player.heat_changed.connect(_on_heat)
	player.hit_confirmed.connect(_on_hit)
	player.damaged.connect(_on_damaged)
	player.prompt_changed.connect(_on_prompt)
	player.died.connect(func() -> void: _tween_fade(1.0, 1.2))
	player.respawned.connect(func() -> void: _tween_fade(0.0, 0.8))


func _process(delta: float) -> void:
	if _reticle.hit > 0.0:
		_reticle.hit = maxf(_reticle.hit - delta * 3.5, 0.0)
	if _player:
		_reticle.aiming = _player.aiming
		_reticle.grapple = _player.grapple_ready
		_reticle.gas = _player.gas
		_reticle.grapple_cd = _player.grapple_cd / maxf(Game.grapple_cooldown(), 0.01)
		_reticle.spread = lerpf(_reticle.spread, _player.heat, 1.0 - exp(-delta * 10.0))
		_reticle.visible = not _player.dead and not Game.busy()
	_reticle.queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("upgrade"):
		_toggle_menu()
		get_viewport().set_input_as_handled()
	elif Game.menu_open:
		if event.is_action_pressed("pause"):
			_toggle_menu()
			get_viewport().set_input_as_handled()
		elif event is InputEventKey and event.pressed and not event.echo:
			var keys := Game.STATS.keys()
			var idx: int = event.physical_keycode - KEY_1
			if idx >= 0 and idx < keys.size():
				_spend(keys[idx])


# --- Aufbau -------------------------------------------------------------

func _label(text: String, font_size: int, color := INK) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("outline_size", 6)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _rect(color: Color) -> ColorRect:
	var r := ColorRect.new()
	r.color = color
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


func _bar(parent: Control, y: float, height: float, color: Color, width := BAR_W) -> ColorRect:
	var back := _rect(Color(0, 0, 0, 0.55))
	back.position = Vector2(0, y)
	back.size = Vector2(width, height)
	parent.add_child(back)
	var fill := _rect(color)
	fill.position = Vector2(0, y)
	fill.size = Vector2(width, height)
	parent.add_child(fill)
	return fill


func _panel_style(border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.02, 0.03, 0.045, 0.94)
	style.border_color = border
	style.set_border_width_all(1)
	style.set_content_margin_all(34)
	return style


func _centered_box() -> VBoxContainer:
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return box


func _build() -> void:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	_vignette = _rect(Color(0.8, 0.05, 0.02, 0.0))
	_vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(_vignette)

	_reticle = Reticle.new()
	_reticle.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_reticle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_reticle)

	# Auftrag oben links
	var obj_box := VBoxContainer.new()
	obj_box.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	obj_box.position = Vector2(36, 30)
	obj_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(obj_box)
	obj_box.add_child(_label("AUFTRAG", 13, AMBER))
	_objective = _label("", 20)
	obj_box.add_child(_objective)

	# Zustand unten links
	var bars := Control.new()
	bars.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	bars.position = Vector2(36, -118)
	bars.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(bars)
	bars.add_child(_label("INTEGRITÄT", 12, AMBER))
	_health_fill = _bar(bars, 20, 8, INK)
	_heat_label = _label("DIENSTWAFFE", 12, AMBER)
	_heat_label.position = Vector2(0, 34)
	bars.add_child(_heat_label)
	_heat_fill = _bar(bars, 54, 5, AMBER)
	_heat_fill.size.x = 0
	_level_label = _label("STUFE 1", 12, ENTITY)
	_level_label.position = Vector2(0, 66)
	bars.add_child(_level_label)
	_xp_fill = _bar(bars, 86, 4, ENTITY)

	# Steuerung unten rechts
	var keys := _label("[Q] Haken    [Leertaste] Abspringen / Gasstoß    [F] Klaue    [Tab] Arm    [E] Benutzen", 13, Color(0.86, 0.9, 0.92, 0.55))
	keys.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	keys.offset_left = -760
	keys.offset_right = -36
	keys.offset_top = -52
	keys.offset_bottom = -30
	keys.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	root.add_child(keys)

	# Bossleiste oben Mitte
	_boss_box = Control.new()
	_boss_box.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_boss_box.position = Vector2(-300, 44)
	_boss_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_boss_box.visible = false
	root.add_child(_boss_box)
	_boss_name = _label("", 18, INK)
	_boss_name.size = Vector2(600, 24)
	_boss_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_boss_box.add_child(_boss_name)
	_boss_fill = _bar(_boss_box, 30, 7, ENTITY, 600.0)

	# Untertitel
	_subtitle = _label("", 23)
	_subtitle.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_subtitle.anchor_left = 0.18
	_subtitle.anchor_right = 0.82
	_subtitle.offset_left = 0
	_subtitle.offset_right = 0
	_subtitle.offset_top = -190
	_subtitle.offset_bottom = -100
	_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_subtitle.visible = false
	root.add_child(_subtitle)

	# Interaktionshinweis
	_prompt = _label("", 20, AMBER)
	_prompt.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_prompt.anchor_left = 0.3
	_prompt.anchor_right = 0.7
	_prompt.offset_left = 0
	_prompt.offset_right = 0
	_prompt.offset_top = 70
	_prompt.offset_bottom = 110
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.visible = false
	root.add_child(_prompt)

	# Einblendung (Stufenaufstieg)
	_toast = _label("", 24, ENTITY)
	_toast.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_toast.anchor_left = 0.2
	_toast.anchor_right = 0.8
	_toast.offset_left = 0
	_toast.offset_right = 0
	_toast.offset_top = 150
	_toast.offset_bottom = 190
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.modulate.a = 0.0
	root.add_child(_toast)

	# Abblende
	_fade = _rect(Color(0, 0, 0, 0))
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(_fade)

	# Titelkarte
	var title_box := _centered_box()
	root.add_child(title_box)
	_title = _label("", 92)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.modulate.a = 0.0
	title_box.add_child(_title)
	_title_sub = _label("", 22, AMBER)
	_title_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_sub.modulate.a = 0.0
	title_box.add_child(_title_sub)

	# Log-Fenster
	_log_panel = PanelContainer.new()
	_log_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_log_panel.anchor_left = 0.24
	_log_panel.anchor_right = 0.76
	_log_panel.anchor_top = 0.16
	_log_panel.anchor_bottom = 0.84
	_log_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.55, 0.85, 1.0, 0.6)))
	_log_panel.visible = false
	root.add_child(_log_panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 20)
	_log_panel.add_child(vb)
	_log_title = _label("", 17, Color(0.6, 0.9, 1.0))
	_log_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(_log_title)
	_log_body = _label("", 21)
	_log_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_log_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_child(_log_body)
	var hint := _label("[E]  schließen", 15, AMBER)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	vb.add_child(hint)

	_build_menu(root)

	# Endkarte
	var end_box := _centered_box()
	root.add_child(end_box)
	_end_title = _label("", 64)
	_end_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_end_title.modulate.a = 0.0
	end_box.add_child(_end_title)
	_end_body = _label("", 22, ENTITY)
	_end_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_end_body.modulate.a = 0.0
	end_box.add_child(_end_body)


func _build_menu(root: Control) -> void:
	_menu = PanelContainer.new()
	_menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_menu.anchor_left = 0.27
	_menu.anchor_right = 0.73
	_menu.anchor_top = 0.2
	_menu.anchor_bottom = 0.8
	_menu.add_theme_stylebox_override("panel", _panel_style(Color(0.72, 0.38, 1.0, 0.7)))
	_menu.visible = false
	root.add_child(_menu)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 14)
	_menu.add_child(vb)
	vb.add_child(_label("DER ARM WILL ETWAS", 26, ENTITY))
	_menu_points = _label("", 17, AMBER)
	vb.add_child(_menu_points)
	var index := 1
	for key in Game.STATS:
		var info: Dictionary = Game.STATS[key]
		var button := Button.new()
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.focus_mode = Control.FOCUS_NONE
		button.custom_minimum_size = Vector2(0, 78)
		button.add_theme_font_size_override("font_size", 19)
		button.pressed.connect(_spend.bind(key))
		button.set_meta("index", index)
		vb.add_child(button)
		_menu_buttons[key] = button
		index += 1
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_child(spacer)
	var hint := _label("[1] [2] [3] oder Klick  —  [Tab] schließen", 15, AMBER)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	vb.add_child(hint)


# --- Attribut-Menü ------------------------------------------------------

func _toggle_menu() -> void:
	if Game.menu_open:
		Game.menu_open = false
		_menu.visible = false
		get_tree().paused = false
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		return
	if Game.reading or Game.ended or (_player and _player.dead):
		return
	Game.menu_open = true
	Sfx.play("ui_open")
	_refresh_menu()
	_menu.visible = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _spend(stat: String) -> void:
	if Game.spend_point(stat):
		_refresh_menu()
		Sfx.play("ui_spend")


func _refresh_menu() -> void:
	_menu_points.text = "Stufe %d      Freie Punkte: %d" % [Game.level, Game.skill_points]
	for key in _menu_buttons:
		var info: Dictionary = Game.STATS[key]
		var button: Button = _menu_buttons[key]
		button.text = "  [%d]   %s   ·   Rang %d\n         %s" % [button.get_meta("index"), info["name"], Game.stats[key], info["desc"]]
		button.disabled = Game.skill_points <= 0


# --- Signale ------------------------------------------------------------

func _on_health(value: float, max_value: float) -> void:
	var ratio := clampf(value / max_value, 0.0, 1.0)
	_health_fill.size.x = BAR_W * ratio
	_health_fill.color = INK if ratio > 0.35 else Color(1.0, 0.3, 0.2)


func _on_heat(value: float, overheated: bool) -> void:
	_heat_fill.size.x = BAR_W * clampf(value, 0.0, 1.0)
	_heat_fill.color = Color(1.0, 0.25, 0.15) if overheated else AMBER
	_heat_label.text = "DIENSTWAFFE  //  ÜBERHITZT" if overheated else "DIENSTWAFFE"


func _refresh_xp() -> void:
	_xp_fill.size.x = BAR_W * clampf(float(Game.xp) / Game.xp_needed(), 0.0, 1.0)
	var text := "STUFE %d" % Game.level
	if Game.skill_points > 0:
		text += "   ·   %d Punkt%s frei  [Tab]" % [Game.skill_points, "" if Game.skill_points == 1 else "e"]
	_level_label.text = text


func _on_hit(killed: bool) -> void:
	_reticle.hit = 1.0
	_reticle.kill = killed


func _on_damaged() -> void:
	_vignette.color.a = 0.32
	var tw := create_tween()
	tw.tween_property(_vignette, "color:a", 0.0, 0.5)


func _on_prompt(text: String) -> void:
	_prompt.text = text
	_prompt.visible = text != ""


func _on_subtitle(speaker: String, text: String) -> void:
	_subtitle.text = "%s:  %s" % [speaker, text]
	_subtitle.visible = true


func _on_objective(text: String) -> void:
	_objective.text = text
	_objective.modulate = AMBER
	var tw := create_tween()
	tw.tween_property(_objective, "modulate", Color.WHITE, 1.4)


func _on_toast(text: String) -> void:
	_toast.text = text
	_toast.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(_toast, "modulate:a", 1.0, 0.3)
	tw.tween_interval(3.0)
	tw.tween_property(_toast, "modulate:a", 0.0, 1.0)


func _on_boss_started(boss: Node, boss_name: String) -> void:
	_boss = boss
	_boss_name.text = boss_name
	_boss_fill.size.x = 600.0
	_boss_box.visible = true
	_boss_box.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(_boss_box, "modulate:a", 1.0, 1.0)
	boss.health_changed.connect(func(value: float, max_value: float) -> void:
		_boss_fill.size.x = 600.0 * clampf(value / max_value, 0.0, 1.0))


func _on_boss_ended() -> void:
	var tw := create_tween()
	tw.tween_property(_boss_box, "modulate:a", 0.0, 1.5)
	tw.tween_callback(func() -> void: _boss_box.visible = false)


func _on_log_opened(title: String, body: String) -> void:
	_log_title.text = title
	_log_body.text = body
	_log_panel.visible = true
	_prompt.visible = false


func _on_title_card(title: String, sub: String) -> void:
	_title.text = title
	_title_sub.text = sub
	_fade.color.a = 1.0
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 0.0, 2.5)
	tw.parallel().tween_property(_title, "modulate:a", 1.0, 1.2)
	tw.parallel().tween_property(_title_sub, "modulate:a", 1.0, 1.8)
	tw.tween_interval(2.2)
	tw.tween_property(_title, "modulate:a", 0.0, 1.5)
	tw.parallel().tween_property(_title_sub, "modulate:a", 0.0, 1.5)


func _on_ending(title: String, body: String) -> void:
	_end_title.text = title
	_end_body.text = body
	_fade.color = Color(0.04, 0.0, 0.07, 0.0)
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 1.0, 2.0)
	tw.tween_property(_end_title, "modulate:a", 1.0, 1.2)
	tw.tween_property(_end_body, "modulate:a", 1.0, 1.2)


func _tween_fade(alpha: float, time: float) -> void:
	_fade.color = Color(0, 0, 0, _fade.color.a)
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", alpha, time)
