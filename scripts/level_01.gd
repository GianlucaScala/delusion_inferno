extends Node3D
## LAYER I: eine Schlucht zwischen zwei Wandflächen des Inferno.
## Spielweg: Aufschlagsims -> Brücke -> Knoten (Terminal) -> abgerissene Rampe
## (Enterhaken) -> Verteilerdeck (Kampf) -> gebrochene Brücke (Enterhaken)
## -> Vorplatz mit dem Pförtner (Boss) -> Tor -> Schacht nach Layer II.

const Builder := preload("res://scripts/megastructure.gd")
const Enemy := preload("res://scripts/enemy.gd")
const Boss := preload("res://scripts/boss.gd")
const Interactable := preload("res://scripts/interactable.gd")
const Fx := preload("res://scripts/fx.gd")

const WARM := Color(1.0, 0.55, 0.22)
const COLD := Color(0.6, 0.85, 1.0)
const ENTITY := Color(0.62, 0.18, 1.0)
const WALL_NEAR_Z := 10.0      # Wandfläche hinter dem Start
const WALL_FAR_Z := -150.0     # Wandfläche mit dem Tor

var spawn_point := Vector3(0, 0.1, 7.0)
var spawn_yaw := 0.0

var b: Builder
var _rng := RandomNumberGenerator.new()
var _arena_alive := 0
var _door: AnimatableBody3D
var _gate_switch: Interactable
var _boss: Node3D
var _fired := {}


func _ready() -> void:
	_rng.seed = 412
	b = Builder.new()
	b.name = "Structure"
	add_child(b)
	_build_start()
	_build_bridge_one()
	_build_node_platform()
	_build_arena()
	_build_gate()
	_build_megastructure()
	b.commit()
	_build_story()


# --- Bausteine ----------------------------------------------------------

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


func _lamp_post(pos: Vector3, height: float, color: Color, kind: String, energy := 2.2) -> void:
	b.box(pos + Vector3(0, height * 0.5, 0), Vector3(0.14, height, 0.14), "metal", false)
	b.box(pos + Vector3(0, height, 0), Vector3(0.5, 0.12, 0.5), "metal", false)
	b.box(pos + Vector3(0, height - 0.12, 0), Vector3(0.36, 0.1, 0.36), kind, false)
	b.lamp(pos + Vector3(0, height - 0.5, 0), color, energy, 17.0)


func _crate(pos: Vector3, size := 1.2, kind := "rust") -> void:
	b.box(pos + Vector3(0, size * 0.5, 0), Vector3.ONE * size, kind)


## Violett glimmender Knoten: Hinweis "hier greift der Haken gut".
func _anchor(pos: Vector3) -> void:
	b.box(pos, Vector3(0.7, 0.3, 0.7), "flesh", false)
	b.box(pos + Vector3(0, -0.2, 0), Vector3(0.36, 0.14, 0.36), "light_entity", false)
	b.lamp(pos + Vector3(0, -0.8, 0), ENTITY, 1.6, 9.0)


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


func _spawn_enemy(pos: Vector3, arena: bool) -> void:
	var e := Enemy.new()
	e.position = pos
	add_child(e)
	if arena:
		_arena_alive += 1
		e.died.connect(_on_arena_enemy_died)


# --- Spielweg -----------------------------------------------------------

func _build_start() -> void:
	# Sims vor der Wand, auf dem Mainy aufschlägt
	b.span(Vector3(-8, -2, 0), Vector3(8, 0, WALL_NEAR_Z))
	b.span(Vector3(-8, 0, 0), Vector3(-7.6, 0.5, WALL_NEAR_Z), "concrete_dark")
	b.span(Vector3(7.6, 0, 0), Vector3(8, 0.5, WALL_NEAR_Z), "concrete_dark")
	b.span(Vector3(-8, 0, 0), Vector3(-2.2, 0.5, 0.4), "concrete_dark")
	b.span(Vector3(2.2, 0, 0), Vector3(8, 0.5, 0.4), "concrete_dark")
	# Nische mit Resten früherer "Urteile"
	b.span(Vector3(-2.6, 0, 4.5), Vector3(-2.0, 3.4, WALL_NEAR_Z), "concrete_dark")
	b.span(Vector3(2.0, 0, 4.5), Vector3(2.6, 3.4, WALL_NEAR_Z), "concrete_dark")
	b.span(Vector3(-2.6, 3.4, 4.0), Vector3(2.6, 4.0, WALL_NEAR_Z), "concrete_dark")
	b.span(Vector3(-1.4, 0, 9.0), Vector3(1.4, 0.25, 9.9), "flesh", false)
	b.span(Vector3(-1.2, 0.25, 9.5), Vector3(-0.2, 0.33, 9.8), "light_entity", false)
	b.lamp(Vector3(0, 2.4, 8.4), ENTITY, 1.3, 9.0)
	_crate(Vector3(5.5, 0, 7.5), 1.0)
	_crate(Vector3(-5.8, 0, 3.0), 1.3, "concrete_dark")
	# Rohre und Kabel an der Wand
	for i in 5:
		var x := -7.0 + i * 0.7
		b.span(Vector3(x, 0, 9.7), Vector3(x + 0.25, 60, 9.95), "metal", false)
	b.span(Vector3(4.0, 5.0, 9.5), Vector3(40.0, 5.6, 9.95), "rust", false)


func _build_bridge_one() -> void:
	_bridge_z(0, 0, 0, -60, 3.6, [[-1.0, -34.0, -24.0], [1.0, -49.0, -44.0]])
	for z in [-8.0, -30.0, -52.0]:
		_lamp_post(Vector3(1.55, 0, z), 3.6, WARM, "light_warm")
	# Pylone, die im Nebel nach unten verschwinden
	for z in [-20.0, -40.0]:
		b.span(Vector3(-1.6, -600, z - 1.6), Vector3(1.6, -0.8, z + 1.6), "concrete_dark", false)
		b.span(Vector3(-4, -6, z - 0.4), Vector3(4, -5.2, z + 0.4), "metal", false)
	b.strut(Vector3(-6, 14, WALL_NEAR_Z), Vector3(-9, 6, -60), 0.12)
	b.strut(Vector3(7, 22, WALL_NEAR_Z), Vector3(12, 9, -60), 0.12)


func _build_node_platform() -> void:
	b.span(Vector3(-12, -2, -84), Vector3(12, 0, -60))
	b.span(Vector3(-7, -700, -79), Vector3(7, -2, -65), "mega", false)
	b.span(Vector3(-12, 0, -84), Vector3(12, 0.5, -83.6), "concrete_dark")
	b.span(Vector3(-12, 0, -84), Vector3(-11.6, 0.5, -60), "concrete_dark")
	b.span(Vector3(-12, 0, -60.4), Vector3(-2.2, 0.5, -60), "concrete_dark")
	b.span(Vector3(2.2, 0, -60.4), Vector3(12, 0.5, -60), "concrete_dark")
	b.span(Vector3(11.6, 0, -84), Vector3(12, 0.5, -74.2), "concrete_dark")
	b.span(Vector3(11.6, 0, -69.8), Vector3(12, 0.5, -60), "concrete_dark")
	# Ruine eines Leitstands
	b.span(Vector3(-10, 0, -82), Vector3(-3, 6.5, -81), "concrete_dark")
	b.span(Vector3(-10, 0, -82), Vector3(-9, 4.0, -74), "concrete_dark")
	b.span(Vector3(-10, 6.5, -82.5), Vector3(-1, 7.2, -76), "concrete_dark")
	b.span(Vector3(-3.6, 0, -77), Vector3(-3.0, 6.5, -76.4), "metal")
	_crate(Vector3(-6, 0, -70))
	_crate(Vector3(-4.7, 0, -69.6), 0.9)
	_crate(Vector3(5, 0, -64), 1.4, "concrete_dark")
	_lamp_post(Vector3(-10.5, 0, -62), 5.0, WARM, "light_warm")
	_lamp_post(Vector3(10.5, 0, -82), 5.0, WARM, "light_warm")
	b.span(Vector3(9.6, 0, -62.4), Vector3(10.4, 30, -61.6), "metal", false)
	b.box(Vector3(10, 30.3, -62), Vector3(0.5, 0.5, 0.5), "light_red", false)

	var term := _terminal(Vector3(-6.5, 0, -80.2), 0.0)
	term.prompt = "[E]  Notiz lesen"
	term.on_use = _read_terminal

	# Rampe zum Verteilerdeck: nach zehn Metern abgerissen
	var basis := b.ramp(Vector3(12, 0, -72), Vector3(22, 3.33, -72), 4.4)
	for side in [-1.0, 1.0]:
		var off: Vector3 = basis.x * side * 2.1 + basis.y * 0.25
		b.box(Vector3(17, 1.67, -72) + off, Vector3(0.25, 0.5, 10.5), "concrete_dark", true, basis)
	b.span(Vector3(18, -700, -74), Vector3(21.5, 2.2, -70), "concrete_dark", false)
	# Bewehrungsstahl ragt aus der Bruchkante
	for i in 5:
		b.strut(Vector3(22, 3.1, -73.6 + i * 0.8), Vector3(23.4 + (i % 2) * 0.6, 2.7 - i * 0.1, -73.5 + i * 0.8), 0.06, "rust")
	b.box(Vector3(34.5, 5.2, -72), Vector3(3.0, 0.6, 4.4), "concrete_dark", false, Basis(Vector3.BACK, -0.5))
	# Träger über der Deckkante: hier greift der Haken
	b.span(Vector3(37, 19, -82), Vector3(40, 21, -62), "concrete_dark", false)
	b.span(Vector3(37.5, 8, -82.8), Vector3(39.5, 19, -81.2), "concrete_dark")
	b.span(Vector3(37.5, 8, -62.8), Vector3(39.5, 19, -61.2), "concrete_dark")
	b.collider(Vector3(38.5, 20, -72), Vector3(3, 2, 20))
	_anchor(Vector3(38.5, 18.85, -72))


func _build_arena() -> void:
	# Verteilerdeck
	b.span(Vector3(36, 6, -90), Vector3(72, 8, -54))
	b.span(Vector3(44, -700, -82), Vector3(64, 6, -62), "mega", false)
	# Brüstung mit Lücken für den Einstieg (West) und die Brücke (Nord)
	b.span(Vector3(36, 8, -54.4), Vector3(72, 8.6, -54), "concrete_dark")
	b.span(Vector3(71.6, 8, -90), Vector3(72, 8.6, -54), "concrete_dark")
	b.span(Vector3(36, 8, -90), Vector3(51.8, 8.6, -89.6), "concrete_dark")
	b.span(Vector3(56.2, 8, -90), Vector3(72, 8.6, -89.6), "concrete_dark")
	b.span(Vector3(36, 8, -90), Vector3(36.4, 8.6, -74.2), "concrete_dark")
	b.span(Vector3(36, 8, -69.8), Vector3(36.4, 8.6, -54), "concrete_dark")
	# Deckung: Stützenstümpfe und halbhohe Wände
	for p in [Vector3(45, 8, -63), Vector3(63, 8, -63), Vector3(45, 8, -81), Vector3(63, 8, -81)]:
		b.span(p - Vector3(1.1, 0, 1.1), p + Vector3(1.1, 3.4, 1.1), "concrete_dark")
	b.span(Vector3(51, 8, -68.5), Vector3(57, 9.3, -67.7), "concrete_dark")
	b.span(Vector3(43, 8, -75), Vector3(43.8, 9.3, -70), "concrete_dark")
	b.span(Vector3(58, 8, -78), Vector3(58.8, 9.3, -73), "concrete_dark")
	_crate(Vector3(49, 8, -76), 1.3)
	_crate(Vector3(66, 8, -70), 1.3)
	_crate(Vector3(66.2, 8, -71.5), 1.0, "concrete_dark")
	# Verteilerturm
	b.span(Vector3(66, 8, -60), Vector3(70, 26, -56), "concrete_dark")
	b.span(Vector3(64, 26, -62), Vector3(71.5, 27, -54.5), "concrete_dark")
	b.span(Vector3(66.5, 14, -60.1), Vector3(69.5, 14.3, -60), "light_warm", false)
	b.lamp(Vector3(68, 13.5, -61.5), WARM, 2.5, 20.0)
	# Oben auf dem Turm liegt etwas (optional, nur mit Haken erreichbar)
	b.box(Vector3(67.5, 27.4, -58), Vector3(1.2, 0.8, 1.2), "flesh", false)
	b.box(Vector3(67.5, 27.9, -58), Vector3(0.5, 0.25, 0.5), "light_entity", false)
	b.lamp(Vector3(67.5, 28.6, -58), ENTITY, 2.0, 10.0)
	_lamp_post(Vector3(38, 8, -56), 6.0, WARM, "light_warm", 2.6)
	_lamp_post(Vector3(70, 8, -88), 6.0, WARM, "light_warm", 2.6)
	_lamp_post(Vector3(38, 8, -88), 6.0, COLD, "light_cold", 1.8)

	for p in [Vector3(60, 8.2, -70), Vector3(65, 8.2, -84), Vector3(50, 8.2, -85)]:
		_spawn_enemy(p, true)

	# Brücke zum Vorplatz: in der Mitte zehn Meter weggebrochen
	_bridge_z(54, 8, -90, -100, 4.0)
	_bridge_z(54, 8, -110, -118, 4.0)
	_lamp_post(Vector3(55.8, 8, -96), 3.6, WARM, "light_warm")
	b.span(Vector3(52.4, -700, -117), Vector3(55.6, 7.2, -113), "concrete_dark", false)
	for i in 4:
		b.strut(Vector3(52.6 + i * 0.9, 7.6, -100), Vector3(52.8 + i * 0.9, 6.8 - (i % 2) * 0.4, -101.8), 0.06, "rust")
	# Portal am anderen Ende: Ankerpunkt für den Haken
	b.span(Vector3(51.6, 8, -112.4), Vector3(52.2, 14, -111.6), "metal")
	b.span(Vector3(55.8, 8, -112.4), Vector3(56.4, 14, -111.6), "metal")
	b.span(Vector3(51.6, 14, -112.6), Vector3(56.4, 14.8, -111.4), "metal")
	_anchor(Vector3(54, 13.85, -112))


func _build_gate() -> void:
	# Vorplatz: Arena des Pförtners
	b.span(Vector3(34, 6, WALL_FAR_Z), Vector3(74, 8, -118))
	b.span(Vector3(40, -700, -146), Vector3(68, 6, -122), "mega", false)
	b.span(Vector3(34, 8, -118.4), Vector3(51.8, 8.6, -118), "concrete_dark")
	b.span(Vector3(56.2, 8, -118.4), Vector3(74, 8.6, -118), "concrete_dark")
	b.span(Vector3(34, 8, WALL_FAR_Z), Vector3(34.4, 8.6, -118), "concrete_dark")
	b.span(Vector3(73.6, 8, WALL_FAR_Z), Vector3(74, 8.6, -118), "concrete_dark")
	# Deckung und hohe Stümpfe zum Weghaken
	for p in [Vector3(42, 8, -126), Vector3(66, 8, -126), Vector3(41, 8, -142), Vector3(67, 8, -142)]:
		b.span(p - Vector3(1.3, 0, 1.3), p + Vector3(1.3, 7.5, 1.3), "concrete_dark")
		b.span(p + Vector3(-1.8, 7.5, -1.8), p + Vector3(1.8, 8.0, 1.8), "concrete_dark")
	b.span(Vector3(46.5, 8, -129), Vector3(50, 9.3, -128.2), "concrete_dark")
	b.span(Vector3(58, 8, -129), Vector3(61.5, 9.3, -128.2), "concrete_dark")
	# Torrahmen
	b.span(Vector3(49.6, 8, -150.6), Vector3(51, 17.4, -149.4), "metal")
	b.span(Vector3(57, 8, -150.6), Vector3(58.4, 17.4, -149.4), "metal")
	b.span(Vector3(49.6, 16, -150.6), Vector3(58.4, 17.4, -149.4), "metal")
	b.span(Vector3(51.4, 17.6, -149.5), Vector3(56.6, 17.9, -149.35), "light_red", false)
	b.lamp(Vector3(54, 15, -146), Color(1.0, 0.2, 0.12), 1.8, 16.0)
	_lamp_post(Vector3(36, 8, -148), 7.0, COLD, "light_cold", 2.0)
	_lamp_post(Vector3(72, 8, -148), 7.0, COLD, "light_cold", 2.0)
	_lamp_post(Vector3(72, 8, -120), 6.0, WARM, "light_warm", 2.4)
	_lamp_post(Vector3(36, 8, -120), 6.0, WARM, "light_warm", 2.4)
	# Tunnel hinter dem Tor, dann der Schacht nach unten
	b.span(Vector3(52.5, 15.6, -171), Vector3(55.5, 15.8, -154), "light_cold", false)
	b.lamp(Vector3(54, 13, -162), COLD, 2.0, 18.0)
	for i in 14:
		var y := -4.0 - i * 9.0
		b.span(Vector3(51.02, y, -196 + (i % 3) * 4.0), Vector3(51.2, y + 0.4, -174), "light_entity", false)
		b.span(Vector3(56.8, y - 4.0, -200), Vector3(56.98, y - 3.6, -176 - (i % 2) * 6.0), "light_entity", false)
	b.lamp(Vector3(54, -6, -182), ENTITY, 5.0, 40.0)

	# Torblatt (fährt nach oben)
	_door = AnimatableBody3D.new()
	_door.collision_layer = Game.LAYER_WORLD
	_door.position = Vector3(54, 12, -150)
	var size := Vector3(6.0, 8.0, 0.8)
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = b.materials["rust"]
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	_door.add_child(mi)
	for i in 3:
		var rib := MeshInstance3D.new()
		var rib_mesh := BoxMesh.new()
		rib_mesh.size = Vector3(6.0, 0.35, 1.0)
		rib_mesh.material = b.materials["metal"]
		rib.mesh = rib_mesh
		rib.position.y = -2.6 + i * 2.6
		_door.add_child(rib)
	var shape := BoxShape3D.new()
	shape.size = size
	var cs := CollisionShape3D.new()
	cs.shape = shape
	_door.add_child(cs)
	add_child(_door)

	# Schaltpult: erst frei, wenn der Pförtner liegt
	_gate_switch = _terminal(Vector3(60.5, 8, -148.6), 0.0)
	_gate_switch.prompt = "[E]  Tor öffnen"
	_gate_switch.one_shot = true
	_gate_switch.enabled = false
	_gate_switch.on_use = _open_gate

	_boss = Boss.new()
	_boss.position = Vector3(54, 8.2, -141)
	add_child(_boss)
	_boss.died.connect(_on_boss_died)
	_boss.phase_two.connect(func() -> void:
		Game.say("FISHER", "Jetzt ist er wach. Vorher hat er nur gearbeitet."))


# --- Kulisse ------------------------------------------------------------

func _near_path(x: float, y: float) -> bool:
	return x > -30.0 and x < 95.0 and y > -30.0 and y < 45.0


func _build_megastructure() -> void:
	# Die zwei Wandflächen. Die Torwand hat eine Öffnung bei x 51..57, y 8..16,
	# dahinter 22 m Tunnelboden und dann den offenen Schacht.
	b.span(Vector3(-900, -900, WALL_NEAR_Z), Vector3(900, 900, WALL_NEAR_Z + 120), "mega")
	b.span(Vector3(-900, -900, WALL_FAR_Z - 120), Vector3(51, 900, WALL_FAR_Z), "mega")
	b.span(Vector3(57, -900, WALL_FAR_Z - 120), Vector3(900, 900, WALL_FAR_Z), "mega")
	b.span(Vector3(51, 16, WALL_FAR_Z - 120), Vector3(57, 900, WALL_FAR_Z), "mega")
	b.span(Vector3(51, -900, WALL_FAR_Z - 22), Vector3(57, 8, WALL_FAR_Z), "mega")
	b.span(Vector3(51, -900, WALL_FAR_Z - 120), Vector3(57, 16, WALL_FAR_Z - 52), "mega")

	# Querträger zwischen den Wänden, in allen Höhen
	for i in 90:
		var x := _rng.randf_range(-800, 800)
		var y := _rng.randf_range(-650, 650)
		var w := _rng.randf_range(3, 22)
		var h := w * _rng.randf_range(0.5, 1.4)
		if _near_path(x, y):
			continue
		# Unter dem Spielweg ausdünnen: der Blick in die Tiefe soll frei bleiben
		if x > -150.0 and x < 210.0 and y < -30.0 and y > -420.0 and _rng.randf() < 0.7:
			continue
		b.span(Vector3(x - w, y - h, WALL_FAR_Z), Vector3(x + w, y + h, WALL_NEAR_Z), "mega", false)
		if _rng.randf() < 0.6:
			var lz := _rng.randf_range(WALL_FAR_Z + 10, WALL_NEAR_Z - 10)
			b.box(Vector3(x, y - h - 0.4, lz), Vector3(2.5, 0.8, 2.5), "light_warm", false)

	# Wandreliefs: vorspringende Blöcke, Schächte, Simse
	for i in 260:
		var far_side := _rng.randf() < 0.5
		var x := _rng.randf_range(-850, 850)
		var y := _rng.randf_range(-700, 700)
		var w := _rng.randf_range(6, 70)
		var h := _rng.randf_range(6, 160)
		var d := _rng.randf_range(1.5, 14)
		if _rng.randf() < 0.3:
			h = _rng.randf_range(1.5, 5)
			w = _rng.randf_range(40, 220)
		if x + w > -30.0 and x - w < 95.0 and y + h > -12.0 and y - h < 30.0:
			continue
		var kind := "mega" if _rng.randf() < 0.7 else "concrete_dark"
		if far_side:
			b.span(Vector3(x - w, y - h, WALL_FAR_Z), Vector3(x + w, y + h, WALL_FAR_Z + d), kind, false)
		else:
			b.span(Vector3(x - w, y - h, WALL_NEAR_Z - d), Vector3(x + w, y + h, WALL_NEAR_Z), kind, false)

	# Frei stehende Megastützen weit links und rechts in der Schlucht
	for i in 26:
		var x := _rng.randf_range(-850, 850)
		if x > -110.0 and x < 190.0:
			continue
		var w := _rng.randf_range(10, 34)
		var z := _rng.randf_range(WALL_FAR_Z + 40, WALL_NEAR_Z - 40)
		b.span(Vector3(x - w, -900, z - w), Vector3(x + w, 900, z + w), "mega", false)

	# Rohrbündel entlang der Wände
	for i in 40:
		var far_side := _rng.randf() < 0.5
		var y := _rng.randf_range(-500, 500)
		var r := _rng.randf_range(0.4, 2.5)
		if y > -10.0 and y < 26.0:
			continue
		var x0 := _rng.randf_range(-850, 200)
		var x1 := x0 + _rng.randf_range(150, 700)
		var z := WALL_FAR_Z + r if far_side else WALL_NEAR_Z - r
		b.span(Vector3(x0, y - r, z - r), Vector3(x1, y + r, z + r), "rust" if _rng.randf() < 0.4 else "metal", false)

	# Kabel quer durch die Schlucht
	for i in 36:
		var x := _rng.randf_range(-300, 400)
		var y := _rng.randf_range(-200, 300)
		if _near_path(x, y) and y < 30.0:
			continue
		var a := Vector3(x, y, WALL_NEAR_Z)
		var c := Vector3(x + _rng.randf_range(-80, 80), y + _rng.randf_range(-90, 30), WALL_FAR_Z)
		b.strut(a, c, _rng.randf_range(0.15, 0.6))

	# Lichter: winzige Fenster geben den Maßstab
	for i in 190:
		var far_side := _rng.randf() < 0.5
		var cx := _rng.randf_range(-800, 800)
		var cy := _rng.randf_range(-600, 600)
		var cols := _rng.randi_range(1, 9)
		var rows := _rng.randi_range(1, 14)
		var kind := "light_warm" if _rng.randf() < 0.72 else "light_cold"
		var z := WALL_FAR_Z + 0.1 if far_side else WALL_NEAR_Z - 0.1
		for cxi in cols:
			for ry in rows:
				if _rng.randf() < 0.45:
					continue
				var p := Vector3(cx + cxi * 3.4, cy + ry * 4.6, z)
				if absf(p.x - 54.0) < 6.0 and p.y > 6.0 and p.y < 20.0:
					continue
				b.box(p, Vector3(1.2, 1.8, 0.2), kind, false)

	# Decks tief unten und hoch oben, mit Lichtkante
	for i in 22:
		var x := _rng.randf_range(-500, 500)
		var y := _rng.randf_range(-420, 420)
		if absf(y) < 50.0:
			continue
		var w := _rng.randf_range(15, 60)
		var far_side := _rng.randf() < 0.5
		var z0 := WALL_FAR_Z if far_side else WALL_NEAR_Z
		var z1 := z0 + (1.0 if far_side else -1.0) * _rng.randf_range(20, 70)
		b.span(Vector3(x - w, y - 2, z0), Vector3(x + w, y, z1), "concrete_dark", false)
		b.box(Vector3(x, y + 0.6, z1), Vector3(w * 1.6, 0.5, 0.5), "light_warm", false)

	# Tief unten: Adern. Dort schläft etwas, und es leuchtet im Schlaf.
	for i in 46:
		var x := _rng.randf_range(-500, 560)
		var y := _rng.randf_range(-520, -150)
		var far_side := _rng.randf() < 0.5
		var z := WALL_FAR_Z + 0.4 if far_side else WALL_NEAR_Z - 0.4
		var length := _rng.randf_range(30, 160)
		var thick := _rng.randf_range(0.8, 3.0)
		if _rng.randf() < 0.5:
			b.box(Vector3(x, y, z), Vector3(thick, length, 0.6), "light_entity", false)
		else:
			b.box(Vector3(x, y, z), Vector3(length, thick, 0.6), "light_entity", false)
	# Dicke Adern quer durch die Schlucht: von oben als Geflecht zu sehen
	for i in 16:
		var x := _rng.randf_range(-260, 330)
		var y := _rng.randf_range(-330, -150)
		b.strut(Vector3(x, y, WALL_NEAR_Z), Vector3(x + _rng.randf_range(-90, 90), y - _rng.randf_range(0, 50), WALL_FAR_Z), _rng.randf_range(2.5, 6.0), "light_abyss")
	for i in 7:
		var x := _rng.randf_range(-300, 200)
		var y := _rng.randf_range(-340, -190)
		var z := _rng.randf_range(WALL_FAR_Z + 25, WALL_NEAR_Z - 25)
		b.strut(Vector3(x, y, z), Vector3(x + _rng.randf_range(160, 420), y - _rng.randf_range(-20, 40), z + _rng.randf_range(-30, 30)), _rng.randf_range(3.0, 7.0), "light_abyss")


# --- Geschichte ---------------------------------------------------------

func _trigger(id: String, center: Vector3, size: Vector3, action: Callable) -> void:
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
		if _fired.has(id):
			return
		_fired[id] = true
		action.call())


func _checkpoint(pos: Vector3, yaw: float) -> void:
	if Game.player:
		Game.player.set_checkpoint(pos, yaw)


func _build_story() -> void:
	_trigger("bridge_mid", Vector3(0, 2, -28), Vector3(6, 5, 4), func() -> void:
		Game.say("FISHER", "Nach oben kommt hier keiner mehr. Nach unten kommt jeder.")
		Game.say("FISHER", "Ganz unten schläft etwas. Es träumt, und der Traum steigt auf. Dein Arm ist ein Stück davon."))
	_trigger("node", Vector3(0, 2, -62), Vector3(8, 5, 4), func() -> void:
		_checkpoint(Vector3(0, 0.1, -63), 0.0)
		Game.say("FISHER", "Links im Leitstand flackert ein Terminal. Lies es oder lass es. Es ändert nichts.")
		Game.set_objective("Sieh dich im Knoten um"))
	_trigger("ramp_end", Vector3(19, 4, -72), Vector3(5, 6, 6), func() -> void:
		_checkpoint(Vector3(15, 1.2, -72), -PI * 0.5)
		Game.say("FISHER", "Die Rampe ist weg. Macht nichts.")
		Game.say("FISHER", "Ziel auf den Träger da oben und drück Q. Der Arm will sowieso raus.")
		Game.set_objective("Enterhaken [Q]: hinauf zum Verteilerdeck"))
	_trigger("arena_in", Vector3(39.5, 11, -72), Vector3(5, 8, 8), func() -> void:
		_checkpoint(Vector3(39, 8.1, -72), -PI * 0.5)
		Game.say("FISHER", "Fugenläufer. Sie dichten Risse ab. Für sie bist du ein Riss.")
		Game.say("FISHER", "Rechte Maustaste zielen, linke schießen. Kommen sie zu nah: F. Dann macht es der Arm.")
		Game.set_objective("Räume das Verteilerdeck"))
	_trigger("bridge_gap", Vector3(54, 10, -93), Vector3(5, 5, 3), func() -> void:
		_checkpoint(Vector3(54, 8.1, -92), 0.0)
		Game.say("FISHER", "Wieder ein Loch. Du weißt, was zu tun ist."))
	_trigger("boss", Vector3(54, 11, -121), Vector3(8, 6, 4), func() -> void:
		_checkpoint(Vector3(54, 8.1, -114), 0.0)
		_boss.activate()
		Game.say("FISHER", "Der Pförtner. Die CSRU hat ihn gefüttert, bis er die Tür nicht mehr vergessen konnte.")
		Game.say("FISHER", "Wenn er sich aufrichtet, schlägt er Wellen. Dann solltest du nicht auf dem Boden stehen.")
		Game.set_objective("Überlebe den Pförtner"))
	_trigger("ending", Vector3(54, -14, -185), Vector3(6, 10, 30), func() -> void:
		Game.end_game("LAYER II", "Fortsetzung folgt."))


func start_story() -> void:
	Game.title_card.emit("iNFERNO;", "LAYER I   —   LIMBUS")
	Game.set_objective("Überquere die Brücke")
	await get_tree().create_timer(3.0).timeout
	Game.say("FISHER", "…he. Du da. Du atmest ja noch.")
	Game.say("FISHER", "Die meisten, die ihr runterwerft, kommen in Stücken an. Du bist am Stück. Fast.")
	Game.say("FISHER", "Schau nicht auf den Arm. Der ist jetzt eben so. Das macht das Inferno mit Fleisch, das es mag.")
	Game.say("FISHER", "Ich bin Fisher. Komm über die Brücke, Bulle. WASD, Shift zum Rennen.")


func _read_terminal(_who: Node) -> void:
	var body := "LAYER I ist stabil. Die Vermischung schreitet ohne unser Zutun voran: " \
		+ "Organisches repliziert Maschine, Maschine repliziert Organisches.\n\n" \
		+ "Die Entität schläft. Aber sie träumt nach oben.\n\n" \
		+ "Beobachtung: Was von oben fällt, wird nicht getötet. Es wird aufgenommen. " \
		+ "Gliedmaßen zuerst.\n\n" \
		+ "Das Tor nach LAYER II bleibt geschlossen. Der Pförtner ist gefüttert. " \
		+ "Er öffnet für niemanden, der noch ganz Mensch ist.\n\n" \
		+ "— G."
	Game.open_log("CSRU  //  CYBERNETIC SCHIZOID REFORMATION UNIT  //  NOTIZ 12", body, func() -> void:
		if Game.flags.has("log_read"):
			return
		Game.flags["log_read"] = true
		Game.add_xp(40)
		Game.say("FISHER", "CSRU. Meine alte Familie. Lies nicht zu viel davon, es bleibt hängen.")
		Game.say("FISHER", "Im Osten war mal eine Rampe zum Verteilerdeck. Von dort geht es zum Tor.")
		Game.set_objective("Erreiche das Tor nach Layer II"))


func _on_arena_enemy_died(_enemy: Node) -> void:
	_arena_alive -= 1
	if _arena_alive == 0:
		Game.say("FISHER", "Still. So mag ich sie am liebsten.")
		Game.set_objective("Erreiche das Tor nach Layer II")


func _on_boss_died(_boss_node: Node) -> void:
	_gate_switch.enabled = true
	Game.say("FISHER", "…du hast ihn wirklich abgeschaltet. Das hat seit Jahren keiner geschafft.")
	Game.say("FISHER", "Das Pult rechts vom Tor. Mach auf.")
	Game.set_objective("Öffne das Tor")


func _open_gate(_who: Node) -> void:
	_gate_switch.prompt = ""
	var tw := create_tween()
	tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(_door, "position:y", 20.4, 6.0)
	Game.say("FISHER", "Dahinter geht es nur noch nach unten. Ich warte dort auf dich. Wahrscheinlich.")
	Game.set_objective("Steig hinab")
