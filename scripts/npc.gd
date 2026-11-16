extends "res://scripts/interactable.gd"
## Eine Figur, mit der man reden kann. Baut sich aus Boxen nach einer Vorlage
## (look) und startet beim Benutzen ein Gespräch aus scripts/story.gd.
##
## talk_picker entscheidet, welches Gespräch gerade dran ist (je nach Flags).

const Fx := preload("res://scripts/fx.gd")
const Story := preload("res://scripts/story.gd")

var look := "settler"
var display_name := ""
var talk_picker: Callable        # () -> String: Schlüssel in Story.TALKS

var _model: Node3D
var _head: Node3D
var _phase := randf() * TAU


func _ready() -> void:
	_model = Node3D.new()
	add_child(_model)
	match look:
		"fisher":
			_build_fisher()
		"vesper":
			_build_vesper()
		"trader":
			_build_person(Color(0.3, 0.22, 0.14), Color(0.55, 0.42, 0.2), true)
		"elder":
			_build_person(Color(0.2, 0.18, 0.22), Color(0.5, 0.45, 0.55), false, 0.86)
		_:
			_build_person(Color(randf_range(0.14, 0.3), randf_range(0.14, 0.24), randf_range(0.12, 0.22)), Color(0.4, 0.38, 0.34), false, randf_range(0.9, 1.05))
	if prompt == "Benutzen":
		prompt = "[E]  Mit %s reden" % display_name
	if talk_picker.is_valid():
		on_use = func(_who: Node) -> void:
			var key: String = talk_picker.call()
			if Story.TALKS.has(key):
				Sfx.play("ui_open")
				Game.start_talk(key, Story.TALKS[key])
	else:
		enabled = false


func _process(delta: float) -> void:
	_phase += delta
	_model.position.y = sin(_phase * 1.3) * 0.015
	var player: Node3D = Game.player
	if player and _head:
		var to: Vector3 = player.global_position - global_position
		if to.length() < 9.0:
			var want := atan2(-to.x, -to.z) - global_rotation.y
			_head.rotation.y = lerp_angle(_head.rotation.y, clampf(wrapf(want, -PI, PI), -1.1, 1.1), 1.0 - exp(-delta * 4.0))
		else:
			_head.rotation.y = lerp_angle(_head.rotation.y, 0.0, 1.0 - exp(-delta * 2.0))


func _mat(color: Color, roughness := 0.8, metallic := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	m.metallic = metallic
	return m


func _box(parent: Node3D, size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = mat
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	parent.add_child(mi)
	return mi


func _make_head(y: float) -> Node3D:
	_head = Node3D.new()
	_head.position.y = y
	_model.add_child(_head)
	return _head


## Einfacher Mensch in Flickenkleidung.
func _build_person(cloth: Color, accent: Color, apron: bool, height := 1.0) -> void:
	var c := _mat(cloth)
	var a := _mat(accent)
	var skin := _mat(Color(0.7, 0.62, 0.55), 0.9)
	_model.scale = Vector3.ONE * height
	_box(_model, Vector3(0.16, 0.9, 0.18), Vector3(-0.12, 0.45, 0), c)
	_box(_model, Vector3(0.16, 0.9, 0.18), Vector3(0.12, 0.45, 0), c)
	_box(_model, Vector3(0.44, 0.62, 0.26), Vector3(0, 1.2, 0), c)
	_box(_model, Vector3(0.5, 0.5, 0.34), Vector3(0, 0.8, 0), a)
	_box(_model, Vector3(0.11, 0.6, 0.12), Vector3(-0.28, 1.2, 0), c)
	_box(_model, Vector3(0.11, 0.6, 0.12), Vector3(0.28, 1.2, 0), c)
	if apron:
		_box(_model, Vector3(0.4, 0.7, 0.04), Vector3(0, 0.95, -0.16), a)
	var head := _make_head(1.68)
	_box(head, Vector3(0.2, 0.24, 0.22), Vector3(0, 0, 0), skin)
	_box(head, Vector3(0.26, 0.14, 0.28), Vector3(0, 0.13, 0.02), a)             # Kapuze / Tuch


## Fisher: hockt, halb in eine Maschine eingewachsen, Kabel als Angelschnüre.
func _build_fisher() -> void:
	var rag := _mat(Color(0.2, 0.19, 0.15))
	var brass := _mat(Color(0.55, 0.45, 0.22), 0.4, 0.7)
	var flesh := _mat(Color(0.62, 0.5, 0.42), 0.8)
	var dark := _mat(Color(0.07, 0.07, 0.08), 0.5, 0.5)
	var glow := Fx.glow_material(Color(1.0, 0.75, 0.3), 2.5)
	# hockender Körper
	_box(_model, Vector3(0.5, 0.4, 0.6), Vector3(0, 0.35, 0.05), rag)
	_box(_model, Vector3(0.46, 0.6, 0.3), Vector3(0, 0.85, 0.1), rag)
	_box(_model, Vector3(0.14, 0.5, 0.5), Vector3(-0.2, 0.42, -0.25), rag)        # Knie
	_box(_model, Vector3(0.14, 0.5, 0.5), Vector3(0.2, 0.42, -0.25), rag)
	_box(_model, Vector3(0.1, 0.55, 0.1), Vector3(-0.3, 0.8, -0.12), flesh)
	_box(_model, Vector3(0.1, 0.55, 0.1), Vector3(0.3, 0.8, -0.12), flesh)
	# Rückenmaschine mit Angelruten
	_box(_model, Vector3(0.7, 0.9, 0.4), Vector3(0, 1.0, 0.42), brass)
	_box(_model, Vector3(0.5, 0.3, 0.3), Vector3(0, 1.6, 0.4), dark)
	_box(_model, Vector3(0.12, 0.12, 0.06), Vector3(0.18, 1.05, 0.2), glow)
	for i in 3:
		var rod := _box(_model, Vector3(0.03, 2.6, 0.03), Vector3(-0.3 + i * 0.3, 2.4, 0.2), dark)
		rod.rotation.x = -0.5 - i * 0.12
		rod.rotation.z = (i - 1) * 0.25
	# Kopf: Gesicht unter einer Haube aus Messing, ein Auge ist eine Linse
	var head := _make_head(1.32)
	_box(head, Vector3(0.2, 0.24, 0.22), Vector3(0, 0, -0.02), flesh)
	_box(head, Vector3(0.3, 0.2, 0.34), Vector3(0, 0.16, 0.04), brass)
	_box(head, Vector3(0.07, 0.07, 0.05), Vector3(0.05, 0.03, -0.14), glow)
	_box(head, Vector3(0.04, 0.3, 0.04), Vector3(-0.12, -0.2, 0.1), dark)        # Schlauch in den Hals


## Vesper: Rebellin. Helm mit Antennen-Ohren, helle Rüstteile, violette Akzente.
func _build_vesper() -> void:
	var suit := _mat(Color(0.12, 0.12, 0.15))
	var white := _mat(Color(0.82, 0.82, 0.8), 0.5)
	var purple := _mat(Color(0.42, 0.26, 0.6), 0.6)
	var skin := _mat(Color(0.76, 0.68, 0.62), 0.9)
	var glow := Fx.glow_material(Color(0.72, 0.38, 1.0), 2.0)
	_box(_model, Vector3(0.15, 0.9, 0.17), Vector3(-0.11, 0.45, 0), suit)
	_box(_model, Vector3(0.15, 0.9, 0.17), Vector3(0.11, 0.45, 0), suit)
	_box(_model, Vector3(0.2, 0.36, 0.24), Vector3(-0.11, 0.2, -0.01), white)     # Stiefel
	_box(_model, Vector3(0.2, 0.36, 0.24), Vector3(0.11, 0.2, -0.01), white)
	_box(_model, Vector3(0.36, 0.56, 0.22), Vector3(0, 1.2, 0), suit)
	_box(_model, Vector3(0.4, 0.18, 0.26), Vector3(0, 0.92, 0), purple)           # Gürtel
	_box(_model, Vector3(0.1, 0.56, 0.11), Vector3(-0.24, 1.2, 0), suit)
	_box(_model, Vector3(0.1, 0.56, 0.11), Vector3(0.24, 1.2, 0), suit)
	_box(_model, Vector3(0.14, 0.26, 0.15), Vector3(-0.24, 1.02, 0), white)       # Armschiene
	_box(_model, Vector3(0.06, 0.06, 0.03), Vector3(0, 1.3, -0.12), glow)
	var head := _make_head(1.64)
	_box(head, Vector3(0.19, 0.22, 0.2), Vector3(0, 0, 0), skin)
	_box(head, Vector3(0.28, 0.16, 0.3), Vector3(0, 0.14, 0.02), white)           # Helm
	_box(head, Vector3(0.3, 0.05, 0.1), Vector3(0, 0.1, -0.12), purple)           # Schirm
	for side in [-1.0, 1.0]:
		var ear := _box(head, Vector3(0.07, 0.3, 0.1), Vector3(side * 0.12, 0.36, 0.04), white)
		ear.rotation.z = -side * 0.25
		_box(head, Vector3(0.03, 0.12, 0.03), Vector3(side * 0.15, 0.56, 0.04), glow)
