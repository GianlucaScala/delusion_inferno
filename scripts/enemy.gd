extends CharacterBody3D
## Fugenläufer: staksige Wartungsmaschine, die "Risse" abdichtet.
## Hält Abstand, umkreist die Spielerin und verschießt langsame Schweißbolzen.

const Fx := preload("res://scripts/fx.gd")
const Projectile := preload("res://scripts/projectile.gd")

signal died(enemy: Node)

const SPEED := 3.4
const GRAVITY := 15.0
const SIGHT_RANGE := 42.0
const BOLT_SPEED := 17.0

var health := 60.0
var dead := false
var alerted := false
var xp_reward := 35
var scrap_reward := 8
var body_radius := 0.55

var _fire_t := 1.5
var _windup := 0.0
var _strafe := 1.0
var _strafe_t := 2.0
var _phase := randf() * TAU
var _flash := 0.0

var _model: Node3D
var _eye: MeshInstance3D
var _eye_mat: StandardMaterial3D
var _shell_mat: StandardMaterial3D
var _legs: Array[Node3D] = []


func _ready() -> void:
	collision_layer = Game.LAYER_ENEMY
	collision_mask = Game.LAYER_WORLD | Game.LAYER_PLAYER
	add_to_group("enemy")
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.55
	capsule.height = 2.3
	var cs := CollisionShape3D.new()
	cs.shape = capsule
	cs.position.y = 1.15
	add_child(cs)
	_build_model()
	_fire_t = randf_range(1.0, 2.2)
	_strafe = 1.0 if randf() > 0.5 else -1.0


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
	_shell_mat.albedo_color = Color(0.82, 0.8, 0.74)
	_shell_mat.roughness = 0.7
	_shell_mat.emission_enabled = true
	_shell_mat.emission = Color(1.0, 0.4, 0.2)
	_shell_mat.emission_energy_multiplier = 0.0
	var joint := StandardMaterial3D.new()
	joint.albedo_color = Color(0.08, 0.08, 0.09)
	joint.roughness = 0.5
	_eye_mat = Fx.glow_material(Color(1.0, 0.15, 0.08), 3.0)

	# Rumpf: schmal, hoch aufgehängt
	_box(_model, Vector3(0.5, 0.42, 1.0), Vector3(0, 1.75, 0), _shell_mat)
	_box(_model, Vector3(0.34, 0.3, 0.5), Vector3(0, 1.98, 0.2), _shell_mat)
	_box(_model, Vector3(0.3, 0.2, 0.3), Vector3(0, 1.72, -0.6), joint)
	_eye = _box(_model, Vector3(0.14, 0.14, 0.06), Vector3(0, 1.74, -0.76), _eye_mat)
	_box(_model, Vector3(0.04, 0.9, 0.04), Vector3(0.14, 2.5, 0.35), joint)   # Antenne
	# Vier lange Beine
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var hip := Node3D.new()
			hip.position = Vector3(sx * 0.28, 1.7, sz * 0.35)
			hip.rotation.z = sx * 0.42
			hip.rotation.x = -sz * 0.25
			_model.add_child(hip)
			_box(hip, Vector3(0.09, 0.9, 0.09), Vector3(0, 0.3, 0), joint)
			var knee := Node3D.new()
			knee.position = Vector3(0, 0.75, 0)
			knee.rotation.z = -sx * 0.85
			hip.add_child(knee)
			_box(knee, Vector3(0.07, 2.2, 0.07), Vector3(0, -1.1, 0), _shell_mat)
			_legs.append(hip)


func take_damage(amount: float, pos := Vector3.ZERO, dir := Vector3.ZERO) -> void:
	if dead:
		return
	health -= amount
	alerted = true
	_flash = 1.0
	velocity += dir * 2.5
	Fx.damage_number(get_tree().current_scene, pos, amount)
	Sfx.play_at("enemy_hit", global_position + Vector3(0, 1.7, 0), 0.0, 1.0, 0.12)
	if health <= 0.0:
		dead = true
		Game.add_xp(xp_reward)
		if scrap_reward > 0:
			Game.add_scrap(scrap_reward)
			Fx.float_text(get_tree().current_scene, global_position + Vector3(0, 2.6, 0), "+%d Schrott" % scrap_reward, Color(1.0, 0.72, 0.38))
		Sfx.play_at("enemy_die", global_position + Vector3(0, 1.7, 0), 0.0, 1.0, 0.1)
		Fx.debris(get_tree().current_scene, global_position + Vector3(0, 1.6, 0), _shell_mat.duplicate(), 9)
		Fx.impact(get_tree().current_scene, global_position + Vector3(0, 1.7, 0), Vector3.UP, Color(1.0, 0.4, 0.15))
		died.emit(self)
		queue_free()


func _physics_process(delta: float) -> void:
	if dead:
		return
	_phase += delta
	_flash = maxf(_flash - delta * 6.0, 0.0)
	_shell_mat.emission_energy_multiplier = _flash * 2.0

	var player: Node3D = Game.player
	var move := Vector3.ZERO
	if player and not player.dead and not Game.ended:
		var to_p: Vector3 = player.aim_point() - (global_position + Vector3(0, 1.7, 0))
		var dist := to_p.length()
		if not alerted and dist < SIGHT_RANGE and _can_see(player):
			alerted = true
			_alert_others()
			Sfx.play_at("enemy_alert", global_position + Vector3(0, 1.7, 0), 0.0, 1.0, 0.08)
		if alerted:
			var flat := Vector3(to_p.x, 0, to_p.z).normalized()
			var yaw := atan2(-flat.x, -flat.z)
			_model.rotation.y = lerp_angle(_model.rotation.y, yaw, 1.0 - exp(-delta * 6.0))
			var side := flat.cross(Vector3.UP)
			_strafe_t -= delta
			if _strafe_t <= 0.0:
				_strafe_t = randf_range(1.5, 3.5)
				_strafe = -_strafe
			if dist > 14.0:
				move += flat
			elif dist < 7.0:
				move -= flat
			move += side * _strafe * 0.8
			if _windup > 0.0:
				move = Vector3.ZERO
			_update_fire(delta, player, dist)

	if move.length() > 0.01:
		move = move.normalized()
		if not _has_floor(move):
			_strafe = -_strafe
			move = Vector3.ZERO
	var hv := Vector3(velocity.x, 0, velocity.z).move_toward(move * SPEED, 14.0 * delta)
	velocity.x = hv.x
	velocity.z = hv.z
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	move_and_slide()

	# Gangbild: Rumpf wippt, Beine pumpen gegeneinander
	var gait := hv.length() / SPEED
	_model.position.y = sin(_phase * 2.0) * 0.05 + sin(_phase * 9.0) * 0.04 * gait
	for i in _legs.size():
		var base := -0.25 if i % 2 == 0 else 0.25
		_legs[i].rotation.x = base + sin(_phase * 9.0 + i * PI * 0.5) * 0.3 * gait
	if global_position.y < -200.0:
		queue_free()


func _update_fire(delta: float, player: Node3D, dist: float) -> void:
	if _windup > 0.0:
		_windup -= delta
		var s := 1.0 + (0.55 - _windup) * 3.0
		_eye.scale = Vector3(s, s, 1.0)
		_eye_mat.emission_energy_multiplier = 3.0 + (0.55 - _windup) * 16.0
		if _windup <= 0.0:
			_eye.scale = Vector3.ONE
			_eye_mat.emission_energy_multiplier = 3.0
			_shoot(player, dist)
		return
	_fire_t -= delta
	if _fire_t <= 0.0:
		if dist < SIGHT_RANGE and _can_see(player):
			_windup = 0.55
			_fire_t = randf_range(1.6, 2.8)
			Sfx.play_at("enemy_charge", global_position + Vector3(0, 1.7, 0), 0.0, 1.0, 0.06)
		else:
			_fire_t = 0.4


func _shoot(player: Node3D, dist: float) -> void:
	var from := _eye.global_position
	var lead: Vector3 = player.velocity * (dist / BOLT_SPEED) * 0.6
	var target: Vector3 = player.aim_point() + lead
	var bolt := Projectile.new()
	bolt.velocity = (target - from).normalized() * BOLT_SPEED
	bolt.position = from
	get_tree().current_scene.add_child(bolt)
	Sfx.play_at("enemy_shot", from, 0.0, 1.0, 0.08)


func _can_see(player: Node3D) -> bool:
	var from := global_position + Vector3(0, 1.75, 0)
	var q := PhysicsRayQueryParameters3D.create(from, player.aim_point(), Game.LAYER_WORLD)
	return get_world_3d().direct_space_state.intersect_ray(q).is_empty()


func _has_floor(dir: Vector3) -> bool:
	var from := global_position + dir * 1.3 + Vector3(0, 0.6, 0)
	var q := PhysicsRayQueryParameters3D.create(from, from + Vector3(0, -2.2, 0), Game.LAYER_WORLD)
	return not get_world_3d().direct_space_state.intersect_ray(q).is_empty()


func _alert_others() -> void:
	for other in get_tree().get_nodes_in_group("enemy"):
		if other != self and other.global_position.distance_to(global_position) < 30.0:
			other.alerted = true
