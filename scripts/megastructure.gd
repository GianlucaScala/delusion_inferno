extends Node3D
## Baukasten für die Megastruktur.
## Alles besteht aus Boxen. Sie werden gesammelt und bei commit() zu wenigen
## MultiMeshes (ein Draw Call pro Material) plus einem StaticBody verschmolzen.

const CONCRETE_SHADER := preload("res://shaders/concrete.gdshader")
const Fx := preload("res://scripts/fx.gd")

var materials := {}
var _instances := {}
var _shapes: Array = []


func _init() -> void:
	materials["concrete"] = _concrete(Color(0.40, 0.41, 0.42), 4.0, 0.035)
	materials["concrete_dark"] = _concrete(Color(0.25, 0.26, 0.28), 3.0, 0.03)
	materials["mega"] = _concrete(Color(0.30, 0.31, 0.33), 16.0, 0.16)
	materials["metal"] = _flat(Color(0.10, 0.085, 0.075), 0.6, 0.55)
	materials["rust"] = _flat(Color(0.23, 0.12, 0.07), 0.2, 0.9)
	materials["light_warm"] = Fx.glow_material(Color(1.0, 0.52, 0.2), 8.0)
	materials["light_cold"] = Fx.glow_material(Color(0.6, 0.85, 1.0), 6.0)
	materials["light_red"] = Fx.glow_material(Color(1.0, 0.12, 0.08), 4.0)
	materials["light_entity"] = Fx.glow_material(Color(0.62, 0.18, 1.0), 6.0)
	materials["light_abyss"] = Fx.glow_material(Color(0.55, 0.12, 1.0), 14.0)
	materials["flesh"] = _flat(Color(0.33, 0.12, 0.16), 0.1, 0.55)


func _concrete(color: Color, panel: float, seam: float) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = CONCRETE_SHADER
	mat.set_shader_parameter("base_color", color)
	mat.set_shader_parameter("panel_size", panel)
	mat.set_shader_parameter("seam", seam)
	return mat


func _flat(color: Color, metallic: float, roughness: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.metallic = metallic
	mat.roughness = roughness
	return mat


## Box mit Mittelpunkt und Größe. rot = optionale Drehung (für Rampen, Kabel).
func box(center: Vector3, size: Vector3, kind := "concrete", collide := true, rot := Basis.IDENTITY) -> void:
	if not _instances.has(kind):
		_instances[kind] = []
	_instances[kind].append(Transform3D(rot * Basis.from_scale(size), center))
	if collide:
		_shapes.append([Transform3D(rot, center), size])


## Unsichtbare Kollisionsbox (z. B. für Geländer aus vielen dünnen Teilen).
func collider(center: Vector3, size: Vector3, rot := Basis.IDENTITY) -> void:
	_shapes.append([Transform3D(rot, center), size])


## Box über zwei Eckpunkte (achsparallel).
func span(a: Vector3, b: Vector3, kind := "concrete", collide := true) -> void:
	var lo := Vector3(minf(a.x, b.x), minf(a.y, b.y), minf(a.z, b.z))
	var hi := Vector3(maxf(a.x, b.x), maxf(a.y, b.y), maxf(a.z, b.z))
	box((lo + hi) * 0.5, hi - lo, kind, collide)


## Schräge Platte von a nach b (Oberkante läuft durch beide Punkte).
func ramp(a: Vector3, b: Vector3, width: float, thick := 0.6, kind := "concrete") -> Basis:
	var dir := b - a
	var basis := Basis.looking_at(dir.normalized(), Vector3.UP)
	var center := (a + b) * 0.5 - basis.y * thick * 0.5
	box(center, Vector3(width, thick, dir.length()), kind, true, basis)
	return basis


## Dünner Balken zwischen zwei beliebigen Punkten (Kabel, Streben).
func strut(a: Vector3, b: Vector3, thick: float, kind := "metal", collide := false) -> void:
	var dir := b - a
	var n := dir.normalized()
	var up := Vector3.UP if absf(n.y) < 0.99 else Vector3.RIGHT
	box((a + b) * 0.5, Vector3(thick, thick, dir.length()), kind, collide, Basis.looking_at(n, up))


## Punktlicht ohne Schatten (billig, davon vertragen wir viele).
func lamp(pos: Vector3, color: Color, energy := 2.0, radius := 16.0, shadows := false) -> OmniLight3D:
	var light := OmniLight3D.new()
	light.position = pos
	light.light_color = color
	light.light_energy = energy
	light.omni_range = radius
	light.omni_attenuation = 1.4
	light.shadow_enabled = shadows
	light.light_volumetric_fog_energy = 2.0
	add_child(light)
	return light


func commit() -> void:
	var unit := BoxMesh.new()
	unit.size = Vector3.ONE
	for kind in _instances:
		var list: Array = _instances[kind]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = unit
		mm.instance_count = list.size()
		for i in list.size():
			mm.set_instance_transform(i, list[i])
		var mmi := MultiMeshInstance3D.new()
		mmi.name = "Boxes_" + kind
		mmi.multimesh = mm
		mmi.material_override = materials[kind]
		if kind.begins_with("light"):
			mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mmi)

	var body := StaticBody3D.new()
	body.name = "Collision"
	body.collision_layer = 1
	body.collision_mask = 0
	add_child(body)
	for entry in _shapes:
		var shape := BoxShape3D.new()
		shape.size = entry[1]
		var cs := CollisionShape3D.new()
		cs.shape = shape
		cs.transform = entry[0]
		body.add_child(cs)
	_instances.clear()
	_shapes.clear()
