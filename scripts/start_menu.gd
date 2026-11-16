extends CanvasLayer
## Startmenü: erscheint nur, wenn es einen Spielstand gibt.
##   Enter / Klick   Fortsetzen
##   N               Neues Spiel (überschreibt den Spielstand)

const INK := Color(0.86, 0.9, 0.92)
const AMBER := Color(1.0, 0.62, 0.28)


func _ready() -> void:
	layer = 20
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var back := ColorRect.new()
	back.color = Color(0.03, 0.035, 0.045)
	back.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(back)

	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 18)
	add_child(box)

	var title := Label.new()
	title.text = "iNFERNO;"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 96)
	title.add_theme_color_override("font_color", INK)
	box.add_child(title)

	var info := "Spielstand"
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(Game.SAVE_PATH))
	if typeof(data) == TYPE_DICTIONARY:
		info = "Layer %d   ·   Stufe %d   ·   %d Schrott" % [int(data.get("layer", 1)), int(data.get("level", 1)), int(data.get("scrap", 0))]
	var sub := Label.new()
	sub.text = info
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 20)
	sub.add_theme_color_override("font_color", AMBER)
	box.add_child(sub)

	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 30)
	box.add_child(gap)
	_button(box, "Fortsetzen   [Enter]", _continue)
	_button(box, "Neues Spiel   [N]", _new_game)


func _button(parent: Control, text: String, action: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(380, 56)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 22)
	b.pressed.connect(action)
	parent.add_child(b)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_ENTER or event.physical_keycode == KEY_E:
			_continue()
		elif event.physical_keycode == KEY_N:
			_new_game()


func _continue() -> void:
	if not Game.load_save():
		Game.new_game()
	Sfx.play("ui_open")
	get_tree().reload_current_scene()


func _new_game() -> void:
	Game.new_game()
	Sfx.play("ui_spend")
	get_tree().reload_current_scene()
