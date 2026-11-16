extends CharacterBody3D
## DER PFÖRTNER: Wächter vor dem Schacht nach Layer II.
## Halb Baumaschine, halb etwas, das einmal ein Gesicht hatte.
##
## Phase 1: Bolzenfächer + Schockwelle (springen oder weghaken).
## Phase 2 (ab 50 %): schneller, ruft Fugenläufer, Doppelwelle.

const Fx := preload("res://scripts/fx.gd")
const Projectile := preload("res://scripts/projectile.gd")
const ENTITY := Color(0.62, 0.18, 1.0)

signal died(boss: Node)
signal health_changed(value: float, max_value: float)
signal phase_two

const MAX_HEALTH := 900.0
const SPEED := 2.3
const GRAVITY := 15.0
const BOLT_SPEED := 19.0
const WAVE_RADIUS := 19.0
const WAVE_TIME := 1.25

var boss_name := "DER PFÖRTNER"
var health := MAX_HEALTH
var dead := false
var alerted := false
var active := false
var body_radius := 1.7
var xp_reward := 320

var _phase := 1
var _t := 0.0
var _attack_t := 2.5
var _attack_index := 0
var _windup := 0.0
var _windup_kind := ""
var _flash := 0.0
var _waves: Array = []     # [alter, bereits getroffen]

var _model: Node3D
var _core: Node3D
var _eyes_mat: StandardMaterial3D
var _shell_mat: StandardMaterial3D
var _legs: Array[Node3D] = []


func _ready() -> void:
	collision_layer = Game.LAYER_ENEMY
	collision_mask = Game.LAYER_WORLD | Game.LAYER_PLAYER
	add_to_group("enemy")
	var capsule := CapsuleShape3D.new()
	capsule.radius = body_radius
	capsule.height = 6.4
	var cs := CollisionShape3D.new()
	cs.shape = capsule
	cs.position.y = 3.2
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
	_core = Node3D.new()
	_core.position.y = 4.2
	_model.add_child(_core)

	_shell_mat = StandardMaterial3D.new()
	_shell_mat.albedo_color = Color(0.8, 0.78, 0.72)
	_shell_mat.roughness = 0.65
	_shell_mat.emission_enabled = true
	_shell_mat.emission = ENTITY
	_shell_mat.emission_energy_multiplier = 0.0
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.06, 0.06, 0.07)
	dark.roughness = 0.45
	dark.metallic = 0.5
	var flesh := StandardMaterial3D.new()
	flesh.albedo_color = Color(0.34, 0.11, 0.15)
	flesh.roughness = 0.5
	_eyes_mat = Fx.glow_material(ENTITY, 4.0)
	var aura := OmniLight3D.new()
	aura.light_color = Color(0.8, 0.6, 1.0)
	aura.light_energy = 3.0
	aura.omni_range = 16.0
	aura.position = Vector3(0, 0.5, -4.0)
	_core.add_child(aura)

	# Rumpf: Maschinenblock, darunter hängt Gewachsenes
	_box(_core, Vector3(2.6, 1.8, 3.0), Vector3(0, 0.4, 0.2), dark)
	_box(_core, Vector3(2.2, 0.6, 2.4), Vector3(0, 1.55, 0.3), _shell_mat)
	_box(_core, Vector3(1.6, 1.3, 1.8), Vector3(0, -1.0, 0.3), flesh)
	_box(_core, Vector3(1.0, 0.9, 1.1), Vector3(0.1, -2.0, 0.4), flesh)
	# Maske: ein zu großes, zu ruhiges Gesicht
	_box(_core, Vector3(1.3, 1.9, 0.25), Vector3(0, 0.2, -1.45), _shell_mat)
	_box(_core, Vector3(0.9, 0.5, 0.2), Vector3(0, -0.95, -1.4), _shell_mat)
	_box(_core, Vector3(0.34, 0.14, 0.08), Vector3(-0.32, 0.5, -1.6), _eyes_mat)
	_box(_core, Vector3(0.34, 0.14, 0.08), Vector3(0.32, 0.5, -1.6), _eyes_mat)
	_box(_core, Vector3(0.1, 0.5, 0.08), Vector3(0, -0.15, -1.6), _eyes_mat)
	# Krone aus Antennen
	for i in 7:
		var h := 1.2 + absf(3 - i) * -0.22 + 0.9
		_box(_core, Vector3(0.07, h, 0.07), Vector3(-0.9 + i * 0.3, 1.8 + h * 0.5, 0.2), dark)
	# Schläuche
	for i in 5:
		var hose := _box(_core, Vector3(0.12, 2.6, 0.12), Vector3(-1.0 + i * 0.5, -2.0, 1.2), dark)
		hose.rotation.x = 0.25 + i * 0.05
	# Sechs Beine
	for i in 6:
		var side := -1.0 if i % 2 == 0 else 1.0
		var row := float(i / 2) - 1.0
		var hip := Node3D.new()
		hip.position = Vector3(side * 1.3, 0.6, row * 1.2 + 0.2)
		hip.rotation.z = side * 0.75
		hip.rotation.y = -side * row * 0.45
		_core.add_child(hip)
		_box(hip, Vector3(0.22, 2.4, 0.22), Vector3(0, 1.0, 0), dark)
		var knee := Node3D.new()
		knee.position = Vector3(0, 2.2, 0)
		knee.rotation.z = -side * 1.15
		hip.add_child(knee)
		_box(knee, Vector3(0.16, 6.6, 0.16), Vector3(0, -3.3, 0), _shell_mat)
		_legs.append(hip)


func activate() -> void:
	if active or dead:
		return
	active = true
	alerted = true
	Game.boss_started.emit(self, boss_name)
	health_changed.emit(health, MAX_HEALTH)


func take_damage(amount: float, pos := Vector3.ZERO, _dir := Vector3.ZERO) -> void:
	if dead:
		return
	if not active:
		activate()
	health = maxf(health - amount, 0.0)
	_flash = 1.0
	Fx.damage_number(get_tree().current_scene, pos, amount, Color(1.0, 0.85, 1.0))
	Sfx.play_at("enemy_hit", pos, 2.0, 0.7, 0.1)
	health_changed.emit(health, MAX_HEALTH)
	if _phase == 1 and health <= MAX_HEALTH * 0.5:
		_phase = 2
		_attack_t = 1.0
		phase_two.emit()
		Sfx.play("boss_roar", 0.0, 1.15)
	if health <= 0.0:
		_die()


func _die() -> void:
	dead = true
	var scene := get_tree().current_scene
	for i in 4:
		Fx.debris(scene, global_position + Vector3(randf_range(-1.5, 1.5), 2.0 + i, randf_range(-1.5, 1.5)), _shell_mat.duplicate(), 8)
	Fx.shock_ring(scene, global_position + Vector3(0, 0.3, 0), 30.0, 1.0, ENTITY)
	Game.add_xp(xp_reward)
	Game.add_scrap(60)
	Game.boss_ended.emit()
	Sfx.play("boss_die")
	died.emit(self)
	queue_free()


func _physics_process(delta: float) -> void:
	if dead:
		return
	_t += delta
	_flash = maxf(_flash - delta * 5.0, 0.0)
	var charge := 0.0
	if _windup > 0.0 and _windup_kind == "wave":
		charge = 1.0 - _windup / 1.1
	_shell_mat.emission_energy_multiplier = _flash * 1.5 + charge * 3.0
	_eyes_mat.emission_energy_multiplier = 4.0 + charge * 14.0 + (4.0 if _phase == 2 else 0.0)

	var player: Node3D = Game.player
	var move := Vector3.ZERO
	if active and player and not player.dead and not Game.ended:
		var to_p: Vector3 = player.global_position - global_position
		var flat := Vector3(to_p.x, 0, to_p.z)
		var dist := flat.length()
		flat = flat.normalized()
		var yaw := atan2(-flat.x, -flat.z)
		_model.rotation.y = lerp_angle(_model.rotation.y, yaw, 1.0 - exp(-delta * 3.0))
		if _windup <= 0.0:
			if dist > 13.0:
				move = flat
			elif dist < 6.0:
				move = -flat
		_update_attacks(delta, player, dist)
	elif active and player and player.dead:
		_waves.clear()

	_update_waves(delta, player)

	var speed := SPEED * (1.35 if _phase == 2 else 1.0)
	if move != Vector3.ZERO and not _has_floor(move):
		move = Vector3.ZERO
	var hv := Vector3(velocity.x, 0, velocity.z).move_toward(move * speed, 8.0 * delta)
	velocity.x = hv.x
	velocity.z = hv.z
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	move_and_slide()

	# Körper: atmet, hebt sich vor der Welle, sackt beim Schlag durch
	var lift := 0.0
	if _windup > 0.0 and _windup_kind == "wave":
		lift = charge * 1.3
	_core.position.y = lerpf(_core.position.y, 4.2 + sin(_t * 1.4) * 0.15 + lift, 1.0 - exp(-delta * 8.0))
	var gait := hv.length() / SPEED
	for i in _legs.size():
		_legs[i].rotation.x = sin(_t * 5.0 + i * 1.1) * 0.12 * gait


func _update_attacks(delta: float, player: Node3D, dist: float) -> void:
	if _windup > 0.0:
		_windup -= delta
		if _windup <= 0.0:
			if _windup_kind == "wave":
				_slam()
			else:
				_fan(player, dist)
		return
	_attack_t -= delta
	if _attack_t > 0.0:
		return
	_attack_index += 1
	var wave := _attack_index % 3 == 0 or dist < 7.0
	if wave:
		_windup_kind = "wave"
		_windup = 1.1
		Sfx.play_at("boss_charge", global_position + Vector3(0, 4, 0), 0.0)
		_attack_t = 3.0 if _phase == 1 else 2.2
	else:
		_windup_kind = "fan"
		_windup = 0.5
		_attack_t = 2.4 if _phase == 1 else 1.5
	if _phase == 2 and _attack_index % 5 == 0:
		_summon()


func _fan(player: Node3D, dist: float) -> void:
	var from := _core.global_position + _model.global_transform.basis * Vector3(0, 0.2, -1.9)
	var lead: Vector3 = player.velocity * (dist / BOLT_SPEED) * 0.5
	var aim: Vector3 = (player.aim_point() + lead - from).normalized()
	var count := 5 if _phase == 1 else 7
	Sfx.play_at("boss_fan", from, 0.0, 1.0, 0.05)
	for i in count:
		var angle := (float(i) - (count - 1) * 0.5) * 0.11
		var bolt := Projectile.new()
		bolt.velocity = aim.rotated(Vector3.UP, angle) * BOLT_SPEED
		bolt.damage = 14.0
		bolt.position = from
		get_tree().current_scene.add_child(bolt)


func _slam() -> void:
	_core.position.y = 2.6
	_waves.append([0.0, false])
	Sfx.play_at("boss_slam", global_position, 0.0, 1.0, 0.04)
	Fx.shock_ring(get_tree().current_scene, global_position + Vector3(0, 0.25, 0), WAVE_RADIUS, WAVE_TIME, ENTITY)
	if _phase == 2:
		await get_tree().create_timer(0.55).timeout
		if dead:
			return
		_waves.append([0.0, false])
		Fx.shock_ring(get_tree().current_scene, global_position + Vector3(0, 0.25, 0), WAVE_RADIUS, WAVE_TIME, ENTITY)
		Sfx.play_at("boss_slam", global_position, -3.0, 1.2, 0.04)


## Die Welle trifft, wenn ihr Rand über die Spielfigur läuft und die gerade
## Bodenkontakt hat. Springen oder am Haken hängen = ausgewichen.
func _update_waves(delta: float, player: Node3D) -> void:
	for wave in _waves:
		wave[0] += delta
		if wave[1] or player == null or player.dead:
			continue
		var radius: float = lerpf(0.5, WAVE_RADIUS, wave[0] / WAVE_TIME)
		var to: Vector3 = player.global_position - global_position
		var d := Vector2(to.x, to.z).length()
		if absf(d - radius) < 0.9 and player.is_on_floor() and absf(to.y) < 1.5:
			wave[1] = true
			player.take_damage(24.0, player.global_position, to.normalized())
			player.velocity += Vector3(to.x, 0, to.z).normalized() * 7.0 + Vector3(0, 4.0, 0)
	_waves = _waves.filter(func(w: Array) -> bool: return w[0] < WAVE_TIME)


func _summon() -> void:
	var enemy_script: GDScript = load("res://scripts/enemy.gd")
	for side in [-1.0, 1.0]:
		var pos: Vector3 = global_position + _model.global_transform.basis * Vector3(side * 5.0, 0.3, 0.0)
		if not _point_has_floor(pos):
			continue
		var e: Node3D = enemy_script.new()
		e.position = pos
		e.alerted = true
		e.xp_reward = 15
		e.scrap_reward = 0
		get_parent().add_child(e)
		Fx.impact(get_tree().current_scene, pos + Vector3(0, 1, 0), Vector3.UP, ENTITY)


func _has_floor(dir: Vector3) -> bool:
	return _point_has_floor(global_position + dir * 2.6)


func _point_has_floor(pos: Vector3) -> bool:
	var from := pos + Vector3(0, 1.0, 0)
	var q := PhysicsRayQueryParameters3D.create(from, from + Vector3(0, -3.0, 0), Game.LAYER_WORLD)
	return not get_world_3d().direct_space_state.intersect_ray(q).is_empty()
