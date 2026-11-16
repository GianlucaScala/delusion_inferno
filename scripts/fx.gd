extends RefCounted
## Kleine Wegwerf-Effekte: Leuchtspur, Einschlag, Trümmer.


static func glow_material(color: Color, energy := 4.0) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0, 0, 0)
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = energy
	return mat


static func tracer(parent: Node, from: Vector3, to: Vector3, color: Color) -> void:
	var length := from.distance_to(to)
	if length < 0.05:
		return
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.04, 0.04, 1.0)
	mesh.material = glow_material(color, 6.0)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	var dir := (to - from) / length
	var up := Vector3.UP if absf(dir.y) < 0.99 else Vector3.RIGHT
	mi.global_transform = Transform3D(Basis.looking_at(dir, up), (from + to) * 0.5)
	mi.scale = Vector3(1.0, 1.0, length)
	var tw := mi.create_tween()
	tw.tween_property(mi, "scale", Vector3(0.02, 0.02, length), 0.14)
	tw.tween_callback(mi.queue_free)


static func impact(parent: Node, pos: Vector3, normal: Vector3, color: Color) -> void:
	var root := Node3D.new()
	parent.add_child(root)
	root.global_position = pos

	var p := CPUParticles3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3.ONE * 0.05
	mesh.material = glow_material(color, 3.0)
	p.mesh = mesh
	p.amount = 10
	p.lifetime = 0.45
	p.one_shot = true
	p.explosiveness = 1.0
	p.direction = normal
	p.spread = 55.0
	p.initial_velocity_min = 2.0
	p.initial_velocity_max = 6.0
	p.gravity = Vector3(0, -12, 0)
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.4
	root.add_child(p)
	p.emitting = true

	var light := OmniLight3D.new()
	light.light_color = color
	light.light_energy = 2.5
	light.omni_range = 5.0
	light.position = normal * 0.2
	root.add_child(light)

	var tw := root.create_tween()
	tw.tween_property(light, "light_energy", 0.0, 0.2)
	tw.tween_interval(0.5)
	tw.tween_callback(root.queue_free)


static func debris(parent: Node, pos: Vector3, mat: Material, count := 7) -> void:
	for i in count:
		var body := RigidBody3D.new()
		body.collision_layer = 0
		body.collision_mask = 1
		var size := Vector3(randf_range(0.1, 0.45), randf_range(0.08, 0.3), randf_range(0.1, 0.6))
		var mesh := BoxMesh.new()
		mesh.size = size
		mesh.material = mat
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		body.add_child(mi)
		var shape := BoxShape3D.new()
		shape.size = size
		var cs := CollisionShape3D.new()
		cs.shape = shape
		body.add_child(cs)
		parent.add_child(body)
		body.global_position = pos + Vector3(randf_range(-0.4, 0.4), randf_range(-0.5, 0.6), randf_range(-0.4, 0.4))
		body.linear_velocity = Vector3(randf_range(-3, 3), randf_range(1, 5), randf_range(-3, 3))
		body.angular_velocity = Vector3(randf_range(-8, 8), randf_range(-8, 8), randf_range(-8, 8))
		var tw := body.create_tween()
		tw.tween_interval(randf_range(4.0, 6.0))
		tw.tween_property(mi, "scale", Vector3.ONE * 0.01, 0.4)
		tw.tween_callback(body.queue_free)


## Schwebende Schadenszahl (RPG-Feedback).
static func damage_number(parent: Node, pos: Vector3, amount: float, color := Color(1, 0.92, 0.8)) -> void:
	var label := Label3D.new()
	label.text = str(int(round(amount)))
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.fixed_size = true
	label.pixel_size = 0.0016
	label.font_size = 34
	label.outline_size = 10
	label.modulate = color
	label.outline_modulate = Color(0, 0, 0, 0.9)
	parent.add_child(label)
	label.global_position = pos + Vector3(randf_range(-0.3, 0.3), 0.4, randf_range(-0.3, 0.3))
	var tw := label.create_tween()
	tw.tween_property(label, "global_position:y", label.global_position.y + 1.3, 0.7)
	tw.parallel().tween_property(label, "modulate:a", 0.0, 0.7).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(label, "outline_modulate:a", 0.0, 0.7).set_ease(Tween.EASE_IN)
	tw.tween_callback(label.queue_free)


## Flacher Ring, der sich über den Boden ausbreitet (Boss-Schockwelle).
static func shock_ring(parent: Node, pos: Vector3, radius: float, time: float, color: Color) -> void:
	var mesh := TorusMesh.new()
	mesh.inner_radius = 0.93
	mesh.outer_radius = 1.0
	mesh.rings = 48
	mesh.ring_segments = 6
	mesh.material = glow_material(color, 5.0)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	mi.global_position = pos
	mi.scale = Vector3(0.5, 2.5, 0.5)
	var tw := mi.create_tween()
	tw.tween_property(mi, "scale", Vector3(radius, 2.5, radius), time)
	tw.tween_callback(mi.queue_free)
