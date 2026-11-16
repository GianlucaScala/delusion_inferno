extends CharacterBody3D
## Kriecher: flach, schnell, beißt. Kommt im Rudel und zwingt einen vom Boden
## weg. Das Gegenstück zum Fugenläufer, der auf Abstand bleibt.

const Fx := preload("res://scripts/fx.gd")

signal died(enemy: Node)

const SPEED := 6.4
const GRAVITY := 15.0
const SIGHT_RANGE := 30.0
const BITE_RANGE := 1.9
const BITE_DAMAGE := 11.0

var health := 32.0
var dead := false
var alerted := false
var xp_reward := 20
var scrap_reward := 5
var body_radius := 0.6

var _bite_cd := 0.0
var _lunge := 0.0
var _phase := randf() * TAU
var _flash := 0.0
var _weave := randf_range(-1.0, 1.0)

var _model: Node3D
var _shell_mat: StandardMaterial3D
var _legs: Array[Node3D] = []


func _ready() -> void:
	collision_layer = Game.LAYER_ENEMY
	collision_mask = Game.LAYER_WORLD | Game.LAYER_PLAYER
	add_to_group("enemy")
	var shape := SphereShape3D.new()
	shape.radius = 0.55
	var cs := CollisionShape3D.new()
	cs.shape = shape
	cs.position.y = 0.55
	add_child(cs)
	_build_model()


func _box(parent: Node3D, size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = mat
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	parent.add_child(mi)
	return mi


func _build_model() -> void:
	_model = Node3D.new()
	add_child(_model)
	_shell_mat = StandardMaterial3D.new()
	_shell_mat.albedo_color = Color(0.42, 0.14, 0.17)
	_shell_mat.roughness = 0.5
	_shell_mat.emission_enabled = true
	_shell_mat.emission = Color(1.0, 0.4, 0.3)
	_shell_mat.emission_energy_multiplier = 0.0
	var bone := StandardMaterial3D.new()
	bone.albedo_color = Color(0.78, 0.75, 0.68)
	bone.roughness = 0.6
	var eye := Fx.glow_material(Color(0.62, 0.18, 1.0), 4.0)

	_box(_model, Vector3(0.55, 0.3, 1.1), Vector3(0, 0.55, 0), _shell_mat)
	_box(_model, Vector3(0.4, 0.22, 0.5), Vector3(0, 0.72, 0.15), bone)
	_box(_model, Vector3(0.36, 0.2, 0.3), Vector3(0, 0.5, -0.65), bone)        # Kopfplatte
	_box(_model, Vector3(0.06, 0.06, 0.04), Vector3(-0.1, 0.52, -0.81), eye)
	_box(_model, Vector3(0.06, 0.06, 0.04), Vector3(0.1, 0.52, -0.81), eye)
	_box(_model, Vector3(0.05, 0.05, 0.7), Vector3(0, 0.62, 0.85), bone)        # Kabelschwanz
	for i in 6:
		var side := -1.0 if i % 2 == 0 else 1.0
		var row := float(i / 2) - 1.0
		var hip := Node3D.new()
		hip.position = Vector3(side * 0.28, 0.55, row * 0.38)
		hip.rotation.z = side * 0.9
		_model.add_child(hip)
		_box(hip, Vector3(0.06, 0.55, 0.06), Vector3(0, 0.25, 0), bone)
		var shin := _box(hip, Vector3(0.05, 0.8, 0.05), Vector3(side * 0.28, 0.2, 0), bone)
		shin.rotation.z = -side * 1.5
		_legs.append(hip)


func take_damage(amount: float, pos := Vector3.ZERO, dir := Vector3.ZERO) -> void:
	if dead:
		return
	health -= amount
	alerted = true
	_flash = 1.0
	velocity += dir * 3.0
	Fx.damage_number(get_tree().current_scene, pos, amount)
	Sfx.play_at("enemy_hit", global_position, 0.0, 1.4, 0.12)
	if health <= 0.0:
		dead = true
		Game.add_xp(xp_reward)
		if scrap_reward > 0:
			Game.add_scrap(scrap_reward)
			Fx.float_text(get_tree().current_scene, global_position + Vector3(0, 1.4, 0), "+%d Schrott" % scrap_reward, Color(1.0, 0.72, 0.38))
		Sfx.play_at("enemy_die", global_position, -2.0, 1.5, 0.1)
		Fx.debris(get_tree().current_scene, global_position + Vector3(0, 0.5, 0), _shell_mat.duplicate(), 5)
		died.emit(self)
		queue_free()


func _physics_process(delta: float) -> void:
	if dead:
		return
	_phase += delta
	_bite_cd -= delta
	_lunge = maxf(_lunge - delta, 0.0)
	_flash = maxf(_flash - delta * 6.0, 0.0)
	_shell_mat.emission_energy_multiplier = _flash * 2.0

	var player: Node3D = Game.player
	var move := Vector3.ZERO
	if player and not player.dead and not Game.ended:
		var to_p: Vector3 = player.global_position - global_position
		var flat := Vector3(to_p.x, 0, to_p.z)
		var dist := flat.length()
		if not alerted and dist < SIGHT_RANGE and absf(to_p.y) < 8.0:
			alerted = true
			Sfx.play_at("enemy_alert", global_position, -2.0, 1.6, 0.1)
			for other in get_tree().get_nodes_in_group("enemy"):
				if other.global_position.distance_to(global_position) < 18.0:
					other.alerted = true
		if alerted and dist > 0.01:
			flat /= dist
			_model.rotation.y = lerp_angle(_model.rotation.y, atan2(-flat.x, -flat.z), 1.0 - exp(-delta * 10.0))
			if dist > BITE_RANGE * 0.7:
				# im Zickzack anlaufen, damit das Rudel nicht in einer Linie kommt
				move = (flat + flat.cross(Vector3.UP) * sin(_phase * 3.0 + _weave * 4.0) * 0.45).normalized()
			if dist < BITE_RANGE and absf(to_p.y) < 1.6 and _bite_cd <= 0.0:
				_bite_cd = 0.95
				_lunge = 0.2
				velocity += flat * 4.0
				player.take_damage(BITE_DAMAGE, global_position, flat)
				Sfx.play_at("claw_hit", global_position, -4.0, 1.5, 0.1)

	if move != Vector3.ZERO and not _has_floor(move):
		move = Vector3.ZERO
	var hv := Vector3(velocity.x, 0, velocity.z).move_toward(move * SPEED, 26.0 * delta)
	velocity.x = hv.x
	velocity.z = hv.z
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	move_and_slide()

	var gait := hv.length() / SPEED
	_model.position.y = sin(_phase * 16.0) * 0.03 * gait
	_model.rotation.x = -_lunge * 1.5
	for i in _legs.size():
		_legs[i].rotation.x = sin(_phase * 18.0 + i * PI * 0.66) * 0.5 * gait
	if global_position.y < -400.0:
		queue_free()


func _has_floor(dir: Vector3) -> bool:
	var from := global_position + dir * 1.2 + Vector3(0, 0.6, 0)
	var q := PhysicsRayQueryParameters3D.create(from, from + Vector3(0, -2.2, 0), Game.LAYER_WORLD)
	return not get_world_3d().direct_space_state.intersect_ray(q).is_empty()
