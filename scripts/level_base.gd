extends Node3D
## Gemeinsame Basis aller Layer: Baukasten-Helfer, Story-Trigger, Stimmung.

const Builder := preload("res://scripts/megastructure.gd")
const Enemy := preload("res://scripts/enemy.gd")
const Crawler := preload("res://scripts/crawler.gd")
const Interactable := preload("res://scripts/interactable.gd")
const Npc := preload("res://scripts/npc.gd")
const Story := preload("res://scripts/story.gd")
const Fx := preload("res://scripts/fx.gd")

const WARM := Color(1.0, 0.55, 0.22)
const COLD := Color(0.6, 0.85, 1.0)
const ENTITY := Color(0.62, 0.18, 1.0)

## Nummer des Layers; steckt in den Namen der gespeicherten Trigger-Flags.
var layer_id := 0
var spawn_point := Vector3.ZERO
var spawn_yaw := 0.0

# Stimmung: main.gd baut daraus Nebel und Licht.
var fog_color := Color(0.15, 0.18, 0.205)
var fog_density := 0.0034
var ambient_color := Color(0.42, 0.5, 0.56)
var ambient_energy := 0.42
var sun_color := Color(0.62, 0.72, 0.82)
var sun_energy := 0.7

var b: Builder
var _rng := RandomNumberGenerator.new()


func _make_builder(seed_value: int) -> void:
	_rng.seed = seed_value
	b = Builder.new()
	b.name = "Structure"
	add_child(b)


func start_story() -> void:
	pass


# --- Bausteine ----------------------------------------------------------

## Brücke entlang Z mit Geländer. gaps = [[Seite(-1/1), z_min, z_max], ...]
func _bridge_z(x: float, y: float, z0: float, z1: float, width: float, gaps: Array = []) -> void:
	var hw := width * 0.5
	b.span(Vector3(x - hw, y - 0.8, z0), Vector3(x + hw, y, z1))
	b.span(Vector3(x - 0.5, y - 2.6, z0), Vector3(x + 0.5, y - 0.8, z1), "concrete_dark", false)
	var lo := minf(z0, z1)
	var hi := maxf(z0, z1)
	var z := lo + 1.0
	while z < hi - 2.5:
		for side in [-1.0, 1.0]:
			var broken := false
			for gap in gaps:
				if side == gap[0] and z > gap[1] and z < gap[2]:
					broken = true
			if broken:
				continue
			var rx: float = x + side * (hw - 0.08)
			b.box(Vector3(rx, y + 0.55, z), Vector3(0.1, 1.1, 0.1), "metal", false)
			b.box(Vector3(rx, y + 1.1, z + 1.5), Vector3(0.08, 0.08, 3.0), "metal", false)
			b.box(Vector3(rx, y + 0.6, z + 1.5), Vector3(0.05, 0.05, 3.0), "metal", false)
			b.collider(Vector3(rx, y + 0.6, z + 1.5), Vector3(0.12, 1.2, 3.0))
		z += 3.0


func _lamp_post(pos: Vector3, height: float, color: Color, kind: String, energy := 2.2) -> OmniLight3D:
	b.box(pos + Vector3(0, height * 0.5, 0), Vector3(0.14, height, 0.14), "metal", false)
	b.box(pos + Vector3(0, height, 0), Vector3(0.5, 0.12, 0.5), "metal", false)
	b.box(pos + Vector3(0, height - 0.12, 0), Vector3(0.36, 0.1, 0.36), kind, false)
	return b.lamp(pos + Vector3(0, height - 0.5, 0), color, energy, 17.0)


func _crate(pos: Vector3, size := 1.2, kind := "rust") -> void:
	b.box(pos + Vector3(0, size * 0.5, 0), Vector3.ONE * size, kind)


## Violett glimmender Knoten: Hinweis "hier greift der Haken gut".
func _anchor(pos: Vector3) -> void:
	b.box(pos, Vector3(0.7, 0.3, 0.7), "flesh", false)
	b.box(pos + Vector3(0, -0.2, 0), Vector3(0.36, 0.14, 0.36), "light_entity", false)
	b.lamp(pos + Vector3(0, -0.8, 0), ENTITY, 1.6, 9.0)


## Portal quer zum Weg (Durchgang entlang Z): zwei Pfosten, ein Sturz, ein Anker.
## Wer den Sturz anhakt, wird darüber hinweg auf die Plattform dahinter geworfen.
func _portal(center: Vector3, width: float, height: float, kind := "metal") -> void:
	var hw := width * 0.5
	b.span(center + Vector3(-hw - 0.6, 0, -0.4), center + Vector3(-hw, height, 0.4), kind)
	b.span(center + Vector3(hw, 0, -0.4), center + Vector3(hw + 0.6, height, 0.4), kind)
	b.span(center + Vector3(-hw - 0.6, height, -0.6), center + Vector3(hw + 0.6, height + 0.8, 0.6), kind)
	_anchor(center + Vector3(0, height - 0.15, 0))


func _terminal(pos: Vector3, yaw: float) -> Interactable:
	var node := Interactable.new()
	node.position = pos
	node.rotation.y = yaw
	add_child(node)
	var rot := Basis(Vector3.UP, yaw)
	b.box(pos + Vector3(0, 0.6, 0), Vector3(1.0, 1.2, 0.5), "metal", true, rot)
	b.box(pos + rot * Vector3(0, 1.45, 0.05), Vector3(0.9, 0.6, 0.12), "metal", false, rot * Basis(Vector3.RIGHT, -0.35))
	b.box(pos + rot * Vector3(0, 1.45, 0.12), Vector3(0.74, 0.44, 0.04), "light_cold", false, rot * Basis(Vector3.RIGHT, -0.35))
	b.lamp(pos + rot * Vector3(0, 1.6, 0.9), COLD, 1.2, 6.0)
	return node


func _npc(look: String, display_name: String, pos: Vector3, face: Vector3, picker := Callable()) -> Npc:
	var npc := Npc.new()
	npc.look = look
	npc.display_name = display_name
	npc.talk_picker = picker
	npc.position = pos
	var to := face - pos
	npc.rotation.y = atan2(-to.x, -to.z)
	add_child(npc)
	return npc


func _spawn(script: GDScript, pos: Vector3) -> Node3D:
	var e: Node3D = script.new()
	e.position = pos
	add_child(e)
	return e


# --- Geschichte ---------------------------------------------------------

## Einmaliger Auslöser. Gemerkt wird er als Flag, also auch nach dem Laden.
func _trigger(id: String, center: Vector3, size: Vector3, action: Callable) -> void:
	var flag := "t%d:%s" % [layer_id, id]
	if Game.has_flag(flag):
		return
	var area := Area3D.new()
	area.collision_layer = 0
	area.collision_mask = Game.LAYER_PLAYER
	area.position = center
	var shape := BoxShape3D.new()
	shape.size = size
	var cs := CollisionShape3D.new()
	cs.shape = shape
	area.add_child(cs)
	add_child(area)
	area.body_entered.connect(func(_body: Node) -> void:
		if Game.has_flag(flag):
			return
		Game.set_flag(flag)
		action.call())


func _checkpoint(pos: Vector3, yaw: float) -> void:
	Game.checkpoint(pos, yaw)
