extends "res://scripts/level_base.gd"
## LAYER II: DIE HÄNGE. Eine Halle ohne durchgehenden Boden; man kommt nur
## schwingend voran. Tief unten leuchtet das Adergeflecht der Entität.
##
## Spielweg (nach Norden = -Z):
##   Auffangbecken (Fisher) -> zwei Hänge-Plattformen (Kriecher, Fugenläufer)
##   -> Siedlung Naht (Vesper, Krämer, die Alte) -> Auftrag: Signalmast hinter
##   dem Nordtor einschalten -> zurück zu Vesper -> Durchsage der CSRU.

const FLOOR_Y := -260.0
const CEIL_Y := 150.0
const WALL_W := -120.0
const WALL_E := 150.0
const ALARM := Color(1.0, 0.08, 0.05)

var _mast_switch: Interactable
var _beacon_mat: StandardMaterial3D
var _beacon_light: OmniLight3D
var _naht_lights: Array[OmniLight3D] = []


func _ready() -> void:
	layer_id = 2
	spawn_point = Vector3(0, 0.1, 3.0)
	fog_color = Color(0.165, 0.13, 0.11)
	fog_density = 0.0036
	ambient_color = Color(0.56, 0.47, 0.4)
	ambient_energy = 0.4
	sun_color = Color(0.85, 0.68, 0.52)
	sun_energy = 0.5
	_make_builder(2077)
	_build_basin()
	_build_hangs()
	_build_naht()
	_build_mast()
	_build_cavern()
	b.commit()
	_build_people()
	_build_story()
	Game.dialogue_event.connect(_on_dialogue_event)


# --- Bausteine ----------------------------------------------------------

## Hängende Plattform mit Stützsäule und Brüstung. An Nord- und Südkante
## bleibt um gap_x eine Lücke von sechs Metern frei.
func _platform(x0: float, x1: float, z_south: float, z_north: float, gap_x: float) -> void:
	b.span(Vector3(x0, -2, z_north), Vector3(x1, 0, z_south))
	var cx := (x0 + x1) * 0.5
	var cz := (z_south + z_north) * 0.5
	b.span(Vector3(cx - 5, FLOOR_Y, cz - 5), Vector3(cx + 5, -2, cz + 5), "mega", false)
	b.span(Vector3(x0, 0, z_north), Vector3(x0 + 0.4, 0.5, z_south), "concrete_dark")
	b.span(Vector3(x1 - 0.4, 0, z_north), Vector3(x1, 0.5, z_south), "concrete_dark")
	for z in [z_south - 0.4, z_north]:
		if gap_x - 3.0 > x0:
			b.span(Vector3(x0, 0, z), Vector3(gap_x - 3.0, 0.5, z + 0.4), "concrete_dark")
		if gap_x + 3.0 < x1:
			b.span(Vector3(gap_x + 3.0, 0, z), Vector3(x1, 0.5, z + 0.4), "concrete_dark")


## Zaun aus unterschiedlich hohen Flicken von a nach b (entlang X oder Z).
func _fence(a: Vector3, c: Vector3, kinds: Array) -> void:
	var along := (c - a).normalized()
	var total := a.distance_to(c)
	var done := 0.0
	while done < total - 0.01:
		var w := minf(_rng.randf_range(2.5, 5.0), total - done)
		var p0 := a + along * done
		var p1 := p0 + along * w + Vector3(0.6 * absf(along.z), _rng.randf_range(2.6, 3.8), 0.6 * absf(along.x))
		b.span(p0, p1, kinds[_rng.randi() % kinds.size()])
		done += w


func _stump(pos: Vector3, height := 3.2) -> void:
	b.span(pos - Vector3(1.0, 0, 1.0), pos + Vector3(1.0, height, 1.0), "concrete_dark")


# --- Spielweg -----------------------------------------------------------

func _build_basin() -> void:
	# Auffangbecken unter dem Schacht
	_platform(-9, 9, 9, -9, 0)
	b.span(Vector3(-3, 0, 8.6), Vector3(3, 0.5, 9), "concrete_dark")
	for side in [-1.0, 1.0]:
		b.span(Vector3(side * 5, 16, -6), Vector3(side * 6, CEIL_Y, 6), "mega_far", false)
		b.span(Vector3(-6, 16, side * 5), Vector3(6, CEIL_Y, side * 6), "mega_far", false)
	b.span(Vector3(-4.9, 44, -4.9), Vector3(4.9, 44.4, 4.9), "light_cold", false)
	b.lamp(Vector3(0, 11, 0), COLD, 3.2, 26.0)
	# Auffangnetz: Kabel, die aus dem Schacht hängen
	for i in 8:
		var ang := i * TAU / 8.0
		b.strut(Vector3(cos(ang) * 4.6, 16, sin(ang) * 4.6), Vector3(cos(ang + 0.5) * 7.6, 0.1, sin(ang + 0.5) * 7.6), 0.08)
	# Wo man aufgeschlagen ist
	b.span(Vector3(-1.6, 0, 3.6), Vector3(1.4, 0.12, 6.4), "flesh", false)
	b.span(Vector3(-0.4, 0.12, 4.4), Vector3(0.5, 0.18, 5.2), "light_entity", false)
	_crate(Vector3(-6, 0, 5), 1.3)
	_crate(Vector3(-6.2, 0, 3.4), 0.9, "concrete_dark")
	_crate(Vector3(6.5, 0, 6.5), 1.1, "patch_ochre")
	_lamp_post(Vector3(-7.5, 0, -7.5), 4.5, WARM, "light_warm", 2.0)


func _build_hangs() -> void:
	# Hang 1: Kriecher
	_platform(-8, 8, -27, -55, 0)
	_portal(Vector3(0, 0, -29), 6.4, 6.0)
	_stump(Vector3(-5, 0, -40))
	_stump(Vector3(5, 0, -44), 2.2)
	_crate(Vector3(2.5, 0, -36), 1.3)
	_crate(Vector3(-2.5, 0, -50), 1.2, "concrete_dark")
	_lamp_post(Vector3(7, 0, -53), 5.0, WARM, "light_warm", 2.4)
	_lamp_post(Vector3(-7, 0, -31), 5.0, WARM, "light_warm", 2.0)
	for p in [Vector3(-4, 0.2, -48), Vector3(4, 0.2, -51), Vector3(0, 0.2, -53)]:
		_spawn(Crawler, p)

	# Hang 2: gemischt
	_platform(4, 32, -74, -104, 14)
	_portal(Vector3(14, 0, -76), 6.4, 6.0)
	_stump(Vector3(9, 0, -88))
	_stump(Vector3(26, 0, -86))
	_stump(Vector3(18, 0, -96), 2.2)
	b.span(Vector3(20, 0, -84), Vector3(24, 1.3, -83.2), "concrete_dark")
	_crate(Vector3(28, 0, -100), 1.3)
	_lamp_post(Vector3(5.5, 0, -102), 5.5, WARM, "light_warm", 2.4)
	_lamp_post(Vector3(30.5, 0, -76), 5.5, COLD, "light_cold", 1.8)
	for p in [Vector3(9, 0.2, -99), Vector3(27, 0.2, -97)]:
		_spawn(Enemy, p)
	for p in [Vector3(20, 0.2, -100), Vector3(12, 0.2, -93)]:
		_spawn(Crawler, p)


func _build_naht() -> void:
	b.span(Vector3(-10, -2, -186), Vector3(42, 0, -122))
	b.span(Vector3(0, FLOOR_Y, -148), Vector3(12, -2, -136), "mega", false)
	b.span(Vector3(22, FLOOR_Y, -176), Vector3(34, -2, -164), "mega", false)

	# Palisade aus Flickwerk, Lücken an Süd- und Nordtor (x 11..21)
	var kinds := ["patch_red", "patch_teal", "patch_ochre", "rust", "concrete_dark"]
	for z in [-122.6, -186.0]:
		_fence(Vector3(-10, 0, z), Vector3(11, 0, z), kinds)
		_fence(Vector3(21, 0, z), Vector3(42, 0, z), kinds)
	for x in [-10.0, 41.4]:
		_fence(Vector3(x, 0, -186), Vector3(x, 0, -122), kinds)
	_portal(Vector3(16, 0, -124), 8.0, 7.0, "rust")
	_portal(Vector3(16, 0, -184), 8.0, 7.0, "rust")

	# Hütten links und rechts der Gasse
	var shacks := [
		[-8.0, -1.0, -152.0], [-8.0, -1.0, -164.0], [-8.0, -1.0, -176.0],
		[33.0, 40.0, -132.0], [33.0, 40.0, -160.0],
	]
	for s in shacks:
		var kind: String = kinds[_rng.randi() % 3]
		var h := _rng.randf_range(2.9, 3.6)
		b.span(Vector3(s[0], 0, s[2] - 4.5), Vector3(s[1], h, s[2] + 4.5), kind)
		var front: float = s[1] if s[0] < 0.0 else s[0]
		var out := 1.0 if s[0] < 0.0 else -1.0
		b.box(Vector3(front + out * 1.2, h + 0.1, s[2]), Vector3(3.0, 0.12, 9.6), "cloth", false, Basis(Vector3.BACK, -out * 0.14))
		b.box(Vector3(front + out * 0.06, 1.1, s[2] + 1.5), Vector3(0.1, 2.2, 1.3), "metal", false)
		b.box(Vector3(front + out * 0.4, h - 0.5, s[2] - 2.0), Vector3(0.22, 0.22, 0.22), "light_warm", false)
		b.box(Vector3((s[0] + s[1]) * 0.5, h + 0.5, s[2] - 1.0), Vector3(2.0, 1.0, 2.0), "rust", false)

	# Lichterketten quer über die Gasse
	for lz in [-134.0, -147.0, -160.0, -173.0]:
		var a := Vector3(-1.0, 4.4, lz)
		var c := Vector3(33.0, 4.9, lz - 3.0)
		b.strut(a, c, 0.04)
		for k in range(1, 11):
			var t := k / 11.0
			var sag := sin(t * PI) * 0.7
			b.box(a.lerp(c, t) - Vector3(0, 0.15 + sag, 0), Vector3.ONE * 0.2, "light_warm", false)
	_naht_lights.append(b.lamp(Vector3(16, 4.5, -136), WARM, 1.8, 20.0))
	_naht_lights.append(b.lamp(Vector3(16, 4.5, -172), WARM, 1.8, 20.0))

	# Feuerschale in der Mitte
	b.span(Vector3(15.2, 0, -156.8), Vector3(16.8, 0.9, -155.2), "metal")
	b.box(Vector3(16, 0.95, -156), Vector3(1.2, 0.2, 1.2), "light_warm", false)
	_naht_lights.append(b.lamp(Vector3(16, 2.2, -156), WARM, 3.4, 24.0, true))

	# Wasserturm (Landmarke)
	for lx in [34.5, 39.5]:
		for lz in [-182.5, -177.5]:
			b.span(Vector3(lx - 0.25, 0, lz - 0.25), Vector3(lx + 0.25, 9, lz + 0.25), "metal")
	b.span(Vector3(33.5, 9, -183.5), Vector3(40.5, 14.5, -176.5), "rust")
	b.span(Vector3(36.8, 0, -176.6), Vector3(37.2, 9, -176.2), "metal", false)

	# Krämerstand
	b.span(Vector3(2.0, 0, -138.6), Vector3(3.0, 1.1, -133.4), "patch_ochre")
	for pz in [-138.6, -133.4]:
		b.span(Vector3(2.9, 1.1, pz - 0.1), Vector3(3.1, 3.2, pz + 0.1), "metal", false)
	b.box(Vector3(2.6, 3.2, -136), Vector3(4.6, 0.12, 6.4), "patch_red", false, Basis(Vector3.BACK, -0.12))
	_crate(Vector3(-0.5, 0, -139), 1.2, "patch_teal")
	_crate(Vector3(-0.8, 0, -133.5), 1.0)
	b.box(Vector3(2.5, 1.25, -137.4), Vector3(0.5, 0.3, 0.5), "light_cold", false)
	b.box(Vector3(2.5, 1.2, -135.0), Vector3(0.6, 0.2, 0.9), "rust", false)
	_naht_lights.append(b.lamp(Vector3(4.0, 2.6, -136), WARM, 1.4, 9.0))

	# Vespers Posten: Kartentisch und Funkmast
	b.span(Vector3(28.4, 0, -147.6), Vector3(31.0, 0.9, -144.4), "metal")
	b.box(Vector3(29.7, 0.93, -146), Vector3(1.7, 0.04, 2.3), "cloth", false)
	b.box(Vector3(29.4, 0.96, -146.4), Vector3(0.5, 0.03, 0.08), "light_cold", false)
	b.box(Vector3(30.0, 0.96, -145.6), Vector3(0.08, 0.03, 0.6), "light_entity", false)
	b.span(Vector3(31.6, 0, -150.2), Vector3(31.9, 10, -149.9), "metal", false)
	b.box(Vector3(31.75, 10.2, -150.05), Vector3(0.4, 0.4, 0.4), "light_red", false)
	b.lamp(Vector3(29.0, 2.4, -146), COLD, 1.2, 8.0)

	# Schrein der Alten
	b.span(Vector3(27.0, 0, -180.5), Vector3(30.0, 0.6, -178.0), "concrete_dark")
	b.box(Vector3(28.5, 1.0, -179.2), Vector3(0.9, 0.8, 0.9), "flesh", false)
	b.box(Vector3(28.5, 1.5, -179.2), Vector3(0.4, 0.3, 0.4), "light_entity", false)
	b.lamp(Vector3(28.5, 2.2, -178.6), ENTITY, 1.8, 9.0)


func _build_mast() -> void:
	_platform(0, 32, -206, -248, 16)
	_portal(Vector3(16, 0, -208), 6.4, 6.0)
	b.span(Vector3(15.4, 0, -238.6), Vector3(16.6, 46, -237.4), "metal")
	for y in [12.0, 24.0, 36.0]:
		b.span(Vector3(12.0, y, -238.2), Vector3(20.0, y + 0.3, -237.8), "metal", false)
	for corner in [Vector3(1, 0.5, -207), Vector3(31, 0.5, -207), Vector3(1, 0.5, -247), Vector3(31, 0.5, -247)]:
		b.strut(Vector3(16, 40, -238), corner, 0.06)
	_stump(Vector3(7, 0, -220))
	_stump(Vector3(25, 0, -226), 2.2)
	_stump(Vector3(9, 0, -240))
	_crate(Vector3(24, 0, -242), 1.3)
	_lamp_post(Vector3(30.5, 0, -207.5), 5.0, WARM, "light_warm", 2.2)

	_mast_switch = _terminal(Vector3(21, 0, -235), 0.0)
	_mast_switch.prompt = "[E]  Signalmast einschalten"
	_mast_switch.one_shot = true
	_mast_switch.enabled = Game.has_flag("l2_quest") and not Game.has_flag("l2_mast_on")
	_mast_switch.on_use = _activate_mast

	_beacon_mat = Fx.glow_material(COLD, 0.0)
	var mesh := BoxMesh.new()
	mesh.size = Vector3.ONE * 1.6
	mesh.material = _beacon_mat
	var beacon := MeshInstance3D.new()
	beacon.mesh = mesh
	beacon.position = Vector3(16, 47, -238)
	add_child(beacon)
	_beacon_light = OmniLight3D.new()
	_beacon_light.position = Vector3(16, 45, -236)
	_beacon_light.light_color = COLD
	_beacon_light.light_energy = 0.0
	_beacon_light.omni_range = 80.0
	_beacon_light.light_volumetric_fog_energy = 3.0
	add_child(_beacon_light)
	if Game.has_flag("l2_mast_on"):
		_beacon_mat.emission_energy_multiplier = 9.0
		_beacon_light.light_energy = 5.0
	elif Game.has_flag("l2_quest"):
		_spawn_mast_enemies()


func _spawn_mast_enemies() -> void:
	for p in [Vector3(8, 0.2, -224), Vector3(24, 0.2, -222), Vector3(12, 0.2, -234), Vector3(23, 0.2, -238)]:
		_spawn(Crawler, p)
	for p in [Vector3(5, 0.2, -244), Vector3(28, 0.2, -232)]:
		_spawn(Enemy, p)


# --- Kulisse ------------------------------------------------------------

func _build_cavern() -> void:
	b.span(Vector3(-420, FLOOR_Y - 10, -540), Vector3(420, FLOOR_Y, 280), "mega_far", false)
	b.span(Vector3(-420, CEIL_Y, -540), Vector3(420, CEIL_Y + 70, 280), "mega_far", false)
	b.span(Vector3(WALL_W - 120, FLOOR_Y, -540), Vector3(WALL_W, CEIL_Y, 280), "mega_far", false)
	b.span(Vector3(WALL_E, FLOOR_Y, -540), Vector3(WALL_E + 120, CEIL_Y, 280), "mega_far", false)

	# Säulenwald, manche abgebrochen
	for zi in 10:
		var z := 220.0 - zi * 82.0
		for x in [-78.0, 104.0]:
			var w := _rng.randf_range(10.0, 15.0)
			var top := CEIL_Y if _rng.randf() > 0.25 else _rng.randf_range(-70.0, 70.0)
			b.span(Vector3(x - w, FLOOR_Y, z - w), Vector3(x + w, top, z + w), "mega_far", false)
			# Adern klettern die Säule hoch
			var climb := _rng.randf_range(40.0, 150.0)
			b.box(Vector3(x - w - 0.3, FLOOR_Y + climb * 0.5, z + _rng.randf_range(-w, w) * 0.6), Vector3(0.6, climb, _rng.randf_range(1.0, 3.0)), "light_abyss", false)
			b.box(Vector3(x + w + 0.3, FLOOR_Y + climb * 0.35, z + _rng.randf_range(-w, w) * 0.6), Vector3(0.6, climb * 0.7, _rng.randf_range(1.0, 3.0)), "light_abyss", false)

	# Zwei Rohre über dem ganzen Weg: Ankerfläche zum Schwingen
	b.span(Vector3(-15, 22, -270), Vector3(-10, 27, 30), "rust")
	b.span(Vector3(36, 30, -270), Vector3(41, 35, 30), "rust")
	var hz := 10.0
	while hz > -260.0:
		b.strut(Vector3(-12.5, 27, hz), Vector3(-12.5, CEIL_Y, hz), 0.5)
		b.strut(Vector3(38.5, 35, hz - 20.0), Vector3(38.5, CEIL_Y, hz - 20.0), 0.5)
		b.box(Vector3(-12.5, 21.85, hz - 10.0), Vector3(1.6, 0.3, 0.5), "light_warm", false)
		b.box(Vector3(38.5, 29.85, hz - 30.0), Vector3(1.6, 0.3, 0.5), "light_cold", false)
		hz -= 40.0
	b.lamp(Vector3(-12.5, 20.5, -40), WARM, 2.0, 24.0)
	b.lamp(Vector3(-12.5, 20.5, -200), WARM, 2.0, 24.0)

	# Querträger in allen Höhen, aber nicht auf Augenhöhe
	for i in 34:
		var y := _rng.randf_range(FLOOR_Y + 30.0, CEIL_Y - 10.0)
		if y > -40.0 and y < 60.0:
			continue
		var z := _rng.randf_range(-500.0, 240.0)
		var w := _rng.randf_range(3.0, 12.0)
		b.span(Vector3(WALL_W, y - w, z - w), Vector3(WALL_E, y + w, z + w), "mega_far", false)

	# Adergeflecht am Boden: hier ist die Entität schon näher
	for i in 90:
		var x := _rng.randf_range(WALL_W + 5.0, WALL_E - 5.0)
		var z := _rng.randf_range(-500.0, 240.0)
		var length := _rng.randf_range(40.0, 230.0)
		var thick := _rng.randf_range(2.0, 7.0)
		if _rng.randf() < 0.5:
			b.box(Vector3(x, FLOOR_Y + 0.4, z), Vector3(length, 0.6, thick), "light_abyss", false)
		else:
			b.box(Vector3(x, FLOOR_Y + 0.4, z), Vector3(thick, 0.6, length), "light_abyss", false)

	# Fensterlichter an den Hallenwänden
	for i in 110:
		var east := _rng.randf() < 0.5
		var wx := WALL_E - 0.1 if east else WALL_W + 0.1
		var cy := _rng.randf_range(FLOOR_Y + 20.0, CEIL_Y - 30.0)
		var cz := _rng.randf_range(-500.0, 220.0)
		var kind := "light_warm" if _rng.randf() < 0.75 else "light_cold"
		for col in _rng.randi_range(1, 8):
			for row in _rng.randi_range(1, 12):
				if _rng.randf() < 0.45:
					continue
				b.box(Vector3(wx, cy + row * 4.6, cz + col * 3.4), Vector3(0.2, 1.8, 1.2), kind, false)

	# Ketten mit Lampen von der Decke
	for i in 16:
		var x := _rng.randf_range(-70.0, 100.0)
		var z := _rng.randf_range(-320.0, 80.0)
		if x > -22.0 and x < 48.0:
			continue
		var low := _rng.randf_range(20.0, 80.0)
		b.strut(Vector3(x, CEIL_Y, z), Vector3(x, low, z), 0.25)
		b.box(Vector3(x, low - 0.7, z), Vector3.ONE * 1.4, "light_warm", false)


# --- Leute & Geschichte -------------------------------------------------

func _build_people() -> void:
	_npc("fisher", "Fisher", Vector3(5.5, 0, -4), Vector3(0, 0, 3), func() -> String:
		return "fisher_again" if Game.has_flag("l2_met_fisher") else "fisher_meet")
	_npc("vesper", "Vesper", Vector3(27, 0, -146), Vector3(16, 0, -146), _pick_vesper)
	_npc("trader", "dem Krämer", Vector3(1.2, 0, -136), Vector3(10, 0, -136), func() -> String: return "trader")
	_npc("elder", "der Alten", Vector3(27, 0, -177), Vector3(16, 0, -170), func() -> String: return "elder")
	for spot in [[Vector3(10, 0, -161), Vector3(16, 0, -156)], [Vector3(21, 0, -165), Vector3(16, 0, -156)],
			[Vector3(7, 0, -173), Vector3(-1, 0, -176)], [Vector3(23, 0, -133), Vector3(33, 0, -132)]]:
		_npc("settler", "", spot[0], spot[1])


func _pick_vesper() -> String:
	if Game.has_flag("l2_finale"):
		return ""
	if Game.has_flag("l2_mast_on"):
		return "vesper_done"
	if Game.has_flag("l2_quest"):
		return "vesper_waiting"
	if Game.has_flag("l2_met_vesper"):
		return "vesper_ask"
	return "vesper_meet"


func _build_story() -> void:
	_trigger("hang_1", Vector3(0, 8, -41), Vector3(16, 18, 28), func() -> void:
		_checkpoint(Vector3(0, 0.1, -33), 0.0)
		Game.say(Story.FISHER, "Kriecher. Die beißen. Bleib nicht stehen, und wenn es zu viele werden: nach oben."))
	_trigger("hang_2", Vector3(18, 8, -89), Vector3(28, 18, 30), func() -> void:
		_checkpoint(Vector3(14, 0.1, -80), 0.0)
		Game.say(Story.FISHER, "Noch ein Sprung, dann siehst du die Lichter. Ab dort bin ich still. Naht mag mich nicht."))
	_trigger("naht", Vector3(16, 8, -146), Vector3(52, 18, 44), func() -> void:
		_checkpoint(Vector3(16, 0.1, -128), 0.0)
		if not Game.has_flag("l2_quest"):
			Game.set_objective("Sieh dich in Naht um. Jemand hat hier das Sagen."))
	_trigger("mast", Vector3(16, 8, -227), Vector3(32, 18, 42), func() -> void:
		_checkpoint(Vector3(16, 0.1, -212), 0.0))


func start_story() -> void:
	Game.title_card.emit("LAYER II", "DIE HÄNGE")
	if Game.has_flag("l2_finale"):
		_finale()
		return
	if Game.has_flag("l2_started"):
		return                      # geladener Spielstand: Auftrag steht schon
	Game.set_flag("l2_started")
	Game.checkpoint(spawn_point, spawn_yaw)
	Game.set_objective("Sprich mit Fisher")
	await get_tree().create_timer(3.5).timeout
	Game.say(Story.FISHER, "Unten. Gut. Dreh dich nach rechts, ich sitze am Geländer.")


func _on_dialogue_event(event: String) -> void:
	match event:
		"l2_to_naht":
			Game.set_objective("Folge dem Rohr nach Norden zur Siedlung Naht")
		"l2_quest_start":
			_spawn_mast_enemies()
			_mast_switch.enabled = true
			Game.set_objective("Schalte den Signalmast hinter dem Nordtor ein")
		"l2_finale":
			_finale()


func _activate_mast(_who: Node) -> void:
	Game.set_flag("l2_mast_on")
	_mast_switch.prompt = ""
	var tw := create_tween()
	tw.tween_property(_beacon_mat, "emission_energy_multiplier", 9.0, 1.2)
	tw.parallel().tween_property(_beacon_light, "light_energy", 5.0, 1.2)
	Sfx.play_at("door_stop", Vector3(16, 4, -238), 2.0, 1.4)
	Sfx.play("levelup", -4.0, 0.8)
	Game.add_xp(60)
	Game.say(Story.VESPER, "Ich sehe das Licht. Komm zurück, bevor es noch jemand anderes sieht.")
	Game.set_objective("Zurück nach Naht: sprich mit Vesper")
	Game.checkpoint(Vector3(16, 0.1, -212), PI)


## Die CSRU meldet sich. Naht wird rot, danach endet der Akt.
func _finale() -> void:
	Game.set_objective("")
	var warm: StandardMaterial3D = b.materials["light_warm"]
	var tw := create_tween()
	tw.tween_property(warm, "emission", ALARM, 1.5)
	for light in _naht_lights:
		tw.parallel().tween_property(light, "light_color", ALARM, 1.5)
	Sfx.play("boss_roar", -4.0, 0.6)
	Sfx.music("boss_music_loop", 0.7)
	for line in Story.FINALE_LINES:
		Game.say(line[0], line[1])
	await get_tree().create_timer(1.0).timeout
	while Game.talking or Game.speaking():
		await get_tree().create_timer(0.25).timeout
	await get_tree().create_timer(1.5).timeout
	Game.end_game("AKT IV", "FALLBACK   —   Fortsetzung folgt.")
