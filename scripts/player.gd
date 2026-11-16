extends CharacterBody3D
## Mainy: Third-Person-Steuerung, Schulterkamera, Dienstwaffe (rechts) und
## der gewachsene Techno-Arm (links) mit Enterhaken und Klaue.

const Fx := preload("res://scripts/fx.gd")

signal health_changed(value: float, max_value: float)
signal heat_changed(value: float, overheated: bool)
signal hit_confirmed(killed: bool)
signal damaged
signal died
signal respawned
signal prompt_changed(text: String)

const WALK_SPEED := 4.2
const SPRINT_SPEED := 7.6
const AIM_SPEED := 2.4
const JUMP_VELOCITY := 5.4
const GRAVITY := 15.0
const MOUSE_SENS := 0.0024
const PAD_SENS := 2.6
const FIRE_INTERVAL := 0.2
const DAMAGE := 20.0
const HEAT_PER_SHOT := 0.13
const INTERACT_RANGE := 2.6
const REEL_SPEED := 21.0        # so schnell holt die Winde das Seil ein (m/s)
const REEL_ACCEL := 46.0
const SWING_STEER := 15.0       # Lenken, solange man am Seil hängt
const GAS_IMPULSE := 9.5        # Gasstoß in der Luft
const GAS_CHARGES := 2.0
const GAS_RECHARGE := 2.4       # Sekunden pro Ladung (am Boden sofort voll)
const MAX_SPEED := 32.0
const ARRIVE_FLING := 11.0      # so schnell wirft einen der Haken über den Anker hinaus
const ARRIVE_LIFT := 6.0
const MELEE_COOLDOWN := 0.65
const ENTITY := Color(0.62, 0.18, 1.0)

var health := 100.0
var heat := 0.0
var overheated := false
var aiming := false
var dead := false
var grappling := false
var grapple_ready := false      # Fadenkreuz liegt auf etwas in Reichweite
var grapple_cd := 0.0
var gas := GAS_CHARGES          # Ladungen für den Gasstoß

var _yaw := 0.0
var _pitch := -0.08
var _checkpoint := Vector3.ZERO
var _checkpoint_yaw := 0.0
var _fire_cd := 0.0
var _since_fire := 10.0
var _since_damage := 10.0
var _since_melee := 10.0
var _melee_hit_done := true
var _walk_phase := 0.0
var _shake := 0.0
var _focus: Node = null
var _prompt := ""
var _grapple_point := Vector3.ZERO
var _grapple_time := 0.0
var _rope_len := 0.0
var _reel_rate := 0.0
var _grapple_dir := Vector3.FORWARD     # waagerechte Richtung vom Absprung zum Anker
var _fling_left := 0.0                  # so lange trägt der Wurf noch über Kanten
var _fling_speed := 0.0
var _was_on_floor := true
var _fall_speed := 0.0
var _step_index := 0
var _cam_roll := 0.0

var _pivot: Node3D
var _pitch_node: Node3D
var _arm: SpringArm3D
var _cam: Camera3D
var _model: Node3D
var _leg_l: Node3D
var _leg_r: Node3D
var _arm_l: Node3D
var _arm_r: Node3D
var _muzzle: Node3D
var _muzzle_light: OmniLight3D
var _claw: Node3D
var _cable: MeshInstance3D
var _hook: MeshInstance3D
var _arm_glow: StandardMaterial3D


func _ready() -> void:
	collision_layer = Game.LAYER_PLAYER
	collision_mask = Game.LAYER_WORLD | Game.LAYER_ENEMY
	floor_max_angle = deg_to_rad(48.0)
	floor_snap_length = 0.4
	add_to_group("player")

	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.34
	capsule.height = 1.8
	var cs := CollisionShape3D.new()
	cs.shape = capsule
	cs.position.y = 0.9
	add_child(cs)

	_build_model()
	_build_camera()
	_build_grapple_visuals()
	health = Game.max_health()
	Game.stats_changed.connect(_on_stats_changed)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


# --- Aufbau -------------------------------------------------------------

func _part(parent: Node3D, size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = mat
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	parent.add_child(mi)
	return mi


func _limb(parent: Node3D, pivot_pos: Vector3, size: Vector3, mat: Material) -> Node3D:
	var pivot := Node3D.new()
	pivot.position = pivot_pos
	parent.add_child(pivot)
	_part(pivot, size, Vector3(0, -size.y * 0.5, 0), mat)
	return pivot


func _mat(color: Color, roughness := 0.8, metallic := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	m.metallic = metallic
	return m


func _build_model() -> void:
	_model = Node3D.new()
	_model.name = "Model"
	add_child(_model)

	var suit := _mat(Color(0.15, 0.16, 0.18), 0.7)
	var plate := _mat(Color(0.36, 0.36, 0.38), 0.5, 0.3)
	var skin := _mat(Color(0.74, 0.7, 0.66), 0.9)
	var hair := _mat(Color(0.035, 0.035, 0.045), 0.9)
	var flesh := _mat(Color(0.5, 0.16, 0.2), 0.45)
	var bone := _mat(Color(0.3, 0.28, 0.27), 0.4, 0.5)
	_arm_glow = Fx.glow_material(ENTITY, 2.0)

	# Beine, Exoskelett-Overall, Rock für die Silhouette
	_leg_l = _limb(_model, Vector3(-0.12, 0.95, 0), Vector3(0.16, 0.95, 0.18), suit)
	_leg_r = _limb(_model, Vector3(0.12, 0.95, 0), Vector3(0.16, 0.95, 0.18), suit)
	_part(_leg_l, Vector3(0.2, 0.3, 0.24), Vector3(0, -0.8, -0.01), plate)
	_part(_leg_r, Vector3(0.2, 0.3, 0.24), Vector3(0, -0.8, -0.01), plate)
	_part(_model, Vector3(0.4, 0.62, 0.24), Vector3(0, 1.27, 0), suit)
	_part(_model, Vector3(0.5, 0.36, 0.36), Vector3(0, 0.84, 0.0), suit)
	_part(_model, Vector3(0.56, 0.16, 0.42), Vector3(0, 0.62, 0.0), suit)
	_part(_model, Vector3(0.44, 0.07, 0.3), Vector3(0, 1.0, 0), plate)             # Gürtel
	# Wirbelsäule des Exoskeletts
	for i in 4:
		_part(_model, Vector3(0.12, 0.09, 0.1), Vector3(0, 1.08 + i * 0.14, 0.15), plate)
	_part(_model, Vector3(0.025, 0.42, 0.02), Vector3(0, 1.3, 0.2), _arm_glow)
	# Kopf: kein Helm, keine Maske, zu viel Haar
	_part(_model, Vector3(0.2, 0.24, 0.22), Vector3(0, 1.76, 0), skin)
	_part(_model, Vector3(0.26, 0.12, 0.28), Vector3(0, 1.89, 0.01), hair)
	_part(_model, Vector3(0.26, 0.34, 0.1), Vector3(0, 1.72, 0.13), hair)
	_part(_model, Vector3(0.06, 0.26, 0.2), Vector3(-0.12, 1.74, 0.02), hair)
	_part(_model, Vector3(0.06, 0.2, 0.2), Vector3(0.12, 1.77, 0.02), hair)
	_part(_model, Vector3(0.1, 0.1, 0.05), Vector3(-0.06, 1.83, -0.11), hair)

	# Rechter Arm: normal, Schulterpanzer, Handschuh, Dienstwaffe
	_arm_r = _limb(_model, Vector3(0.27, 1.52, 0), Vector3(0.11, 0.6, 0.12), suit)
	_part(_arm_r, Vector3(0.2, 0.16, 0.22), Vector3(0.02, -0.02, 0), plate)
	_part(_arm_r, Vector3(0.13, 0.14, 0.14), Vector3(0, -0.56, 0), plate)
	_part(_arm_r, Vector3(0.06, 0.42, 0.12), Vector3(0, -0.8, 0.0), plate)
	_part(_arm_r, Vector3(0.03, 0.14, 0.03), Vector3(0, -1.05, 0.0), Fx.glow_material(Color(1.0, 0.7, 0.3), 1.5))
	_muzzle = Node3D.new()
	_muzzle.position = Vector3(0, -1.14, 0)
	_arm_r.add_child(_muzzle)
	_muzzle_light = OmniLight3D.new()
	_muzzle_light.light_color = Color(1.0, 0.75, 0.4)
	_muzzle_light.light_energy = 0.0
	_muzzle_light.omni_range = 7.0
	_muzzle.add_child(_muzzle_light)

	# Linker Arm: gewachsen, zu lang, halb Fleisch, halb Maschine
	_arm_l = Node3D.new()
	_arm_l.position = Vector3(-0.3, 1.52, 0)
	_model.add_child(_arm_l)
	_part(_arm_l, Vector3(0.24, 0.22, 0.26), Vector3(-0.02, 0.0, 0), flesh)
	_part(_arm_l, Vector3(0.17, 0.46, 0.19), Vector3(-0.02, -0.3, 0), flesh)
	_part(_arm_l, Vector3(0.2, 0.1, 0.22), Vector3(-0.02, -0.52, 0), bone)
	_part(_arm_l, Vector3(0.2, 0.52, 0.22), Vector3(-0.03, -0.84, 0), bone)
	_part(_arm_l, Vector3(0.03, 0.44, 0.03), Vector3(-0.14, -0.84, 0.0), _arm_glow)
	_part(_arm_l, Vector3(0.03, 0.3, 0.03), Vector3(0.07, -0.76, 0.1), _arm_glow)
	_part(_arm_l, Vector3(0.16, 0.12, 0.18), Vector3(-0.03, -1.14, 0), flesh)
	_claw = Node3D.new()
	_claw.position = Vector3(-0.03, -1.2, 0)
	_arm_l.add_child(_claw)
	for i in 3:
		var finger := _part(_claw, Vector3(0.035, 0.3, 0.035), Vector3(-0.06 + i * 0.06, -0.14, -0.03 + absf(i - 1) * 0.04), bone)
		finger.rotation.x = 0.15
	# Schläuche vom Arm in den Rücken
	for i in 2:
		var hose := _part(_model, Vector3(0.05, 0.05, 0.4), Vector3(-0.2 + i * 0.05, 1.5 - i * 0.14, 0.2), bone)
		hose.rotation.y = 0.5


func _build_camera() -> void:
	_pivot = Node3D.new()
	_pivot.name = "CamPivot"
	_pivot.position = Vector3(0, 1.55, 0)
	add_child(_pivot)
	_pitch_node = Node3D.new()
	_pivot.add_child(_pitch_node)
	_arm = SpringArm3D.new()
	_arm.position = Vector3(0.55, 0.12, 0)
	_arm.spring_length = 3.3
	_arm.margin = 0.15
	_arm.collision_mask = Game.LAYER_WORLD
	var probe := SphereShape3D.new()
	probe.radius = 0.2
	_arm.shape = probe
	_arm.add_excluded_object(get_rid())
	_pitch_node.add_child(_arm)
	_cam = Camera3D.new()
	_cam.fov = 68.0
	_cam.near = 0.1
	_cam.far = 2500.0
	_arm.add_child(_cam)
	_cam.make_current()
	# Schwaches Eigenlicht, damit die Figur vor dunklem Beton lesbar bleibt
	var fill := OmniLight3D.new()
	fill.position = Vector3(0, 0.6, 1.4)
	fill.light_color = Color(0.75, 0.82, 0.95)
	fill.light_energy = 0.5
	fill.omni_range = 4.5
	fill.light_specular = 0.0
	_pitch_node.add_child(fill)


func _build_grapple_visuals() -> void:
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.05, 0.05, 1.0)
	mesh.material = Fx.glow_material(ENTITY, 3.0)
	_cable = MeshInstance3D.new()
	_cable.mesh = mesh
	_cable.top_level = true
	_cable.visible = false
	_cable.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_cable)
	var hook_mesh := BoxMesh.new()
	hook_mesh.size = Vector3.ONE * 0.22
	hook_mesh.material = Fx.glow_material(ENTITY, 6.0)
	_hook = MeshInstance3D.new()
	_hook.mesh = hook_mesh
	_hook.top_level = true
	_hook.visible = false
	add_child(_hook)


# --- Öffentliche Helfer -------------------------------------------------

func set_look(yaw: float, pitch: float) -> void:
	_yaw = yaw
	_pitch = pitch
	if _model:
		_model.rotation.y = yaw


func set_checkpoint(pos: Vector3, yaw: float) -> void:
	_checkpoint = pos
	_checkpoint_yaw = yaw


func get_camera() -> Camera3D:
	return _cam


func aim_point() -> Vector3:
	return global_position + Vector3(0, 1.2, 0)


func take_damage(amount: float, _pos := Vector3.ZERO, _dir := Vector3.ZERO) -> void:
	if dead or Game.ended:
		return
	health = maxf(health - amount, 0.0)
	_since_damage = 0.0
	_shake = minf(_shake + 0.25, 0.6)
	health_changed.emit(health, Game.max_health())
	damaged.emit()
	Sfx.play("hurt", 0.0, 1.0, 0.08)
	if health <= 0.0:
		_die()


func _on_stats_changed() -> void:
	# Stufenaufstieg und Fleisch-Punkte heilen voll
	health = Game.max_health()
	health_changed.emit(health, Game.max_health())


# --- Eingabe ------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var sens := MOUSE_SENS * (0.6 if aiming else 1.0)
		_yaw -= event.relative.x * sens
		_pitch = clampf(_pitch - event.relative.y * sens, -1.25, 1.1)
	elif event.is_action_pressed("pause"):
		if Game.reading:
			Game.close_log()
		elif Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event is InputEventMouseButton and event.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event.is_action_pressed("interact"):
		if Game.reading:
			Game.close_log()
		elif _focus and not dead:
			_focus.interact(self)


func _process(delta: float) -> void:
	# Gamepad-Kamera
	var look := Vector2(Input.get_joy_axis(0, JOY_AXIS_RIGHT_X), Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y))
	if look.length() > 0.18:
		var s := PAD_SENS * (0.55 if aiming else 1.0) * delta
		_yaw -= look.x * s
		_pitch = clampf(_pitch - look.y * s, -1.25, 1.1)

	_shake = maxf(_shake - delta * 1.8, 0.0)
	_pivot.rotation.y = _yaw
	_pitch_node.rotation.x = _pitch
	var rush := clampf((velocity.length() - 8.0) / 22.0, 0.0, 1.0)    # 0 = zu Fuß, 1 = voller Schwung
	var target_len := 1.7 if aiming else lerpf(3.3, 4.6, rush)
	var target_fov := 46.0 if aiming else lerpf(68.0, 92.0, rush)
	var k := 1.0 - exp(-delta * 10.0)
	_arm.spring_length = lerpf(_arm.spring_length, target_len, k)
	_cam.fov = lerpf(_cam.fov, target_fov, k)
	_cam.h_offset = randf_range(-1, 1) * _shake * 0.08
	_cam.v_offset = randf_range(-1, 1) * _shake * 0.08
	var side := velocity.dot(_pivot.global_transform.basis.x)
	_cam_roll = lerpf(_cam_roll, clampf(-side * 0.012, -0.16, 0.16) * rush, 1.0 - exp(-delta * 5.0))
	_cam.rotation.z = _cam_roll
	_muzzle_light.light_energy = maxf(_muzzle_light.light_energy - delta * 40.0, 0.0)
	_arm_glow.emission_energy_multiplier = lerpf(_arm_glow.emission_energy_multiplier, 7.0 if grappling else 2.0 + sin(Time.get_ticks_msec() * 0.003) * 0.6, k)
	_update_cable()


func _physics_process(delta: float) -> void:
	_fire_cd -= delta
	_since_fire += delta
	_since_damage += delta
	_since_melee += delta
	grapple_cd = maxf(grapple_cd - delta, 0.0)
	if dead:
		velocity.x = 0.0
		velocity.z = 0.0
		velocity.y -= GRAVITY * delta
		move_and_slide()
		return

	var blocked := Game.busy()
	if grappling:
		_grapple_move(delta, blocked)
	else:
		_walk_move(delta, blocked)

	if not blocked:
		if Input.is_action_pressed("fire"):
			_try_fire()
		if Input.is_action_just_pressed("fire") and overheated:
			Sfx.play("shot_dry")
		if Input.is_action_just_pressed("melee"):
			_try_melee()
	_update_melee()
	_update_heat(delta)
	_update_model(delta)
	_update_focus()
	_probe_grapple()

	# Gas lädt nach: am Boden sofort, in der Luft langsam
	if is_on_floor():
		gas = GAS_CHARGES
	else:
		gas = minf(gas + delta / GAS_RECHARGE, GAS_CHARGES)
	_update_motion_audio()

	if _since_damage > 5.0 and health < Game.max_health():
		health = minf(health + 9.0 * delta, Game.max_health())
		health_changed.emit(health, Game.max_health())
	if global_position.y < _checkpoint.y - 45.0 and not Game.ended:
		_die()


func _walk_move(delta: float, blocked: bool) -> void:
	var input := Vector2.ZERO
	if not blocked:
		input = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	aiming = Input.is_action_pressed("aim") and not blocked

	var dir := Basis(Vector3.UP, _yaw) * Vector3(input.x, 0, input.y)
	var speed := WALK_SPEED
	if aiming:
		speed = AIM_SPEED
	elif Input.is_action_pressed("sprint") and input.y < -0.3:
		speed = SPRINT_SPEED
	var hv := Vector3(velocity.x, 0, velocity.z)
	if _fling_left > 0.0:
		# Kurz nach der Ankunft: bleibt man an einer Kante hängen, trägt der Wurf darüber
		_fling_left = 0.0 if is_on_floor() else _fling_left - delta
		var along := hv.dot(_grapple_dir)
		if along < _fling_speed and not is_on_floor():
			hv += _grapple_dir * (_fling_speed - along)
	if is_on_floor():
		# Mit viel Schwung gelandet: ausrutschen statt sofort stehen
		var grip := 32.0 if hv.length() < SPRINT_SPEED + 1.0 else 13.0
		hv = hv.move_toward(dir * speed, grip * delta)
	elif hv.length() <= speed + 0.5:
		if dir.length() > 0.1:
			hv = hv.move_toward(dir * speed, 9.0 * delta)
	else:
		# Schwung behalten: Lenken dreht die Flugrichtung, macht aber nicht schneller
		var carried := hv.length()
		hv = (hv + dir * 11.0 * delta).limit_length(carried)
		hv *= 1.0 - 0.1 * delta
	velocity.x = hv.x
	velocity.z = hv.z

	if is_on_floor():
		if not blocked and Input.is_action_just_pressed("jump"):
			velocity.y = JUMP_VELOCITY
			Sfx.play("jump", 0.0, 1.0, 0.08)
	else:
		velocity.y -= GRAVITY * delta
		if not blocked and Input.is_action_just_pressed("jump"):
			_gas_burst(dir)
	move_and_slide()

	if not blocked and Input.is_action_just_pressed("grapple"):
		_try_grapple()


## Gasstoß: kurzer Schub in Eingaberichtung (oder Blickrichtung), nur in der Luft.
func _gas_burst(input_dir: Vector3) -> void:
	if gas < 1.0 or dead:
		return
	gas -= 1.0
	var d := -_cam.global_transform.basis.z
	if input_dir.length() > 0.1:
		d = (input_dir.normalized() + Vector3(0, 0.25, 0)).normalized()
	if velocity.y < 0.0:
		velocity.y *= 0.35
	velocity = (velocity + d * GAS_IMPULSE + Vector3(0, 2.5, 0)).limit_length(MAX_SPEED)
	_shake = minf(_shake + 0.12, 0.6)
	Sfx.play("gas", 0.0, 1.0, 0.06)
	Fx.gas_puff(get_tree().current_scene, global_position + Vector3(0, 0.95, 0), -d)


func _update_motion_audio() -> void:
	var speed := velocity.length()
	var airborne := not is_on_floor()
	var wind := clampf((speed - 7.0) / 22.0, 0.0, 1.0) if airborne or speed > 9.0 else 0.0
	Sfx.loop("wind_loop", wind, 0.75 + speed / 50.0)
	var reel := clampf(_reel_rate / REEL_SPEED, 0.0, 1.0)
	Sfx.loop("reel_loop", 0.45 + reel * 0.55 if grappling else 0.0, 0.7 + reel * 0.7)
	if not airborne and not _was_on_floor and _fall_speed > 4.0:
		Sfx.play("land", clampf((_fall_speed - 12.0) * 0.5, -8.0, 4.0), 1.0, 0.08)
		_shake = minf(_shake + clampf(_fall_speed / 60.0, 0.0, 0.35), 0.6)
	_was_on_floor = not airborne
	_fall_speed = -velocity.y if airborne else 0.0


# --- Enterhaken ---------------------------------------------------------

## Sucht den Punkt, an den der Haken greifen würde. Leeres Dictionary = nichts.
func _find_grapple_target() -> Dictionary:
	var cam_pos := _cam.global_position
	var cam_dir := -_cam.global_transform.basis.z
	var space := get_world_3d().direct_space_state
	var skip := cam_pos.distance_to(_pivot.global_position)
	var q := PhysicsRayQueryParameters3D.create(cam_pos + cam_dir * skip, cam_pos + cam_dir * (skip + Game.grapple_range()), Game.LAYER_WORLD)
	q.exclude = [get_rid()]
	var hit := space.intersect_ray(q)
	if hit.is_empty():
		return {}
	var point: Vector3 = hit.position
	var normal: Vector3 = hit.normal
	if point.distance_to(aim_point()) < 3.0:
		return {}
	if normal.y > 0.6:
		point += Vector3(0, 1.6, 0)                       # Boden: darauf landen
	elif normal.y < -0.6:
		point += Vector3(0, -1.0, 0)                      # Decke: darunter hängen
	else:
		# Wand: liegt knapp darüber eine Kante? Dann über die Kante ziehen.
		var top := point - normal * 0.7 + Vector3(0, 3.2, 0)
		var q2 := PhysicsRayQueryParameters3D.create(top, top + Vector3(0, -3.4, 0), Game.LAYER_WORLD)
		var ledge := space.intersect_ray(q2)
		if not ledge.is_empty() and ledge.normal.y > 0.7 and ledge.position.y < top.y - 0.3:
			point = ledge.position + Vector3(0, 2.0, 0)
		else:
			point += normal * 0.6
	return {"point": point, "anchor": hit.position}


func _probe_grapple() -> void:
	grapple_ready = not grappling and grapple_cd <= 0.0 and not _find_grapple_target().is_empty()


func _try_grapple() -> void:
	if grapple_cd > 0.0 or grappling or dead:
		return
	var target := _find_grapple_target()
	if target.is_empty():
		return
	grappling = true
	aiming = false
	_grapple_point = target["point"]
	_grapple_time = 0.0
	_fling_left = 0.0
	_rope_len = _grapple_point.distance_to(aim_point())
	_reel_rate = 0.0
	var flat := _grapple_point - aim_point()
	flat.y = 0.0
	_grapple_dir = flat.normalized() if flat.length() > 1.5 else Basis(Vector3.UP, _yaw) * Vector3.FORWARD
	_hook.global_position = target["anchor"]
	_hook.visible = true
	_cable.visible = true
	# Ruck beim Einhaken: sofort Zug auf dem Seil, Füße vom Boden
	velocity += (_grapple_point - aim_point()).normalized() * 5.0
	if is_on_floor():
		velocity.y = maxf(velocity.y, 3.0)
	Fx.impact(get_tree().current_scene, target["anchor"], Vector3.UP, ENTITY)
	Sfx.play("hook_fire", 0.0, 1.0, 0.06)
	Sfx.play_at("hook_hit", target["anchor"], 0.0, 1.0, 0.08)
	_shake = minf(_shake + 0.15, 0.6)


## Am Seil: Die Winde regelt nur die Geschwindigkeit in Seilrichtung. Alles
## quer dazu (Schwerkraft, Lenken, mitgebrachter Schwung) bleibt frei. Daraus
## wird ein Bogen statt einer Geraden.
##   nichts drücken   einholen und dabei schwingen
##   S halten         Seil halten: reines Pendel
##   A / D / W        in den Schwung lenken
##   Leertaste        abspringen, Schwung mitnehmen
##   Q                loslassen
func _grapple_move(delta: float, blocked: bool) -> void:
	_grapple_time += delta
	var to := _grapple_point - aim_point()
	var dist := to.length()
	var dir := to / maxf(dist, 0.001)
	if not blocked and Input.is_action_just_pressed("jump"):
		_end_grapple("jump")
		return
	if not blocked and Input.is_action_just_pressed("grapple") and _grapple_time > 0.15:
		_end_grapple("drop")
		return
	if dist < 1.7:
		_end_grapple("arrive")
		return

	var input := Vector2.ZERO
	if not blocked:
		input = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var hold := input.y > 0.5
	velocity.y -= GRAVITY * delta
	velocity += Basis(Vector3.UP, _yaw) * Vector3(input.x, 0, minf(input.y, 0.0)) * SWING_STEER * delta

	var closing := velocity.dot(dir)
	var regulated := closing
	if dist >= _rope_len - 0.05:
		regulated = maxf(regulated, 0.0)                 # straffes Seil gibt nicht nach
	if not hold:
		var want := minf(REEL_SPEED, 7.0 + dist * 1.4)   # kurz vor dem Anker abbremsen
		regulated = move_toward(regulated, want, REEL_ACCEL * delta)
		_rope_len = minf(_rope_len, dist)
	velocity += dir * (regulated - closing)
	# Anflughilfe: Wer nicht selbst lenkt, kreist nicht um den Anker, sondern
	# wird hingezogen. Mit A/D/W oder S bleibt der volle Schwung erhalten.
	if input == Vector2.ZERO:
		var near := clampf(1.0 - (dist - 2.0) / 8.0, 0.0, 1.0)
		var tangent := velocity - dir * velocity.dot(dir)
		velocity -= tangent * (1.0 - exp(-near * 9.0 * delta))
	velocity = velocity.limit_length(MAX_SPEED)
	_reel_rate = maxf(regulated, 0.0)
	move_and_slide()

	# Seil als Zwangsbedingung: weiter als die Seillänge geht es nicht
	var to2 := _grapple_point - aim_point()
	var d2 := to2.length()
	if d2 > _rope_len:
		var n := to2 / d2
		move_and_collide(n * (d2 - _rope_len))
		var outward := velocity.dot(n)
		if outward < 0.0:
			velocity -= n * outward
	if not hold and _grapple_time > 0.5 and get_real_velocity().length() < 0.8:
		_end_grapple("arrive")                           # hängt irgendwo fest


func _end_grapple(how: String) -> void:
	grappling = false
	grapple_cd = Game.grapple_cooldown()
	_reel_rate = 0.0
	_hook.visible = false
	_cable.visible = false
	match how:
		"jump":
			# Abspringen: Schwung behalten, dazu ein Stoß nach oben und in Flugrichtung
			var hv := Vector3(velocity.x, 0, velocity.z)
			if hv.length() > 1.0:
				velocity += hv.normalized() * 2.5
			velocity.y = maxf(velocity.y, 0.0) + 5.5
			Fx.gas_puff(get_tree().current_scene, global_position + Vector3(0, 0.95, 0), Vector3.DOWN)
			Sfx.play("gas", -6.0, 1.25, 0.06)
		"arrive":
			# Nicht abbremsen: mit Schwung über den Anker hinaus
			var along := maxf(Vector3(velocity.x, 0, velocity.z).dot(_grapple_dir), ARRIVE_FLING)
			velocity = _grapple_dir * along + Vector3(0, maxf(velocity.y, ARRIVE_LIFT), 0)
			_fling_left = 0.45
			_fling_speed = along
			Sfx.play("whoosh", -2.0, 1.1, 0.1)
	velocity = velocity.limit_length(MAX_SPEED)
	if how != "arrive" and velocity.length() > 12.0:
		Sfx.play("whoosh", 0.0, 1.0, 0.1)


func _update_cable() -> void:
	if not grappling:
		return
	var from := _claw.global_position
	var to := _hook.global_position
	var length := from.distance_to(to)
	if length < 0.1:
		return
	var dir := (to - from) / length
	var up := Vector3.UP if absf(dir.y) < 0.99 else Vector3.RIGHT
	_cable.global_transform = Transform3D(Basis.looking_at(dir, up) * Basis.from_scale(Vector3(1, 1, length)), (from + to) * 0.5)


# --- Waffe & Klaue ------------------------------------------------------

func _try_fire() -> void:
	if _fire_cd > 0.0 or overheated or dead:
		return
	_fire_cd = FIRE_INTERVAL
	_since_fire = 0.0
	heat += HEAT_PER_SHOT * Game.heat_mult()
	if heat >= 1.0:
		heat = 1.0
		overheated = true
	heat_changed.emit(heat, overheated)

	var cam_pos := _cam.global_position
	var cam_dir := -_cam.global_transform.basis.z
	var space := get_world_3d().direct_space_state
	var mask := Game.LAYER_WORLD | Game.LAYER_ENEMY

	# 1) Wohin zeigt das Fadenkreuz? Start erst auf Höhe der Figur, damit
	#    nichts hinter ihrem Rücken getroffen wird.
	var skip := cam_pos.distance_to(_pivot.global_position)
	var q := PhysicsRayQueryParameters3D.create(cam_pos + cam_dir * skip, cam_pos + cam_dir * 400.0, mask)
	q.exclude = [get_rid()]
	var hit := space.intersect_ray(q)
	var target: Vector3 = hit.position if hit else cam_pos + cam_dir * 400.0

	# 2) Der Schuss selbst fliegt von der Mündung dorthin.
	var from := _muzzle.global_position
	var shot_dir := (target - from).normalized()
	var q2 := PhysicsRayQueryParameters3D.create(from, target + shot_dir * 0.5, mask)
	q2.exclude = [get_rid()]
	var hit2 := space.intersect_ray(q2)
	var end := target
	var scene := get_tree().current_scene
	if hit2:
		end = hit2.position
		var col: Object = hit2.collider
		if col and col.has_method("take_damage"):
			col.take_damage(DAMAGE * Game.damage_mult(), end, shot_dir)
			hit_confirmed.emit(col.get("dead") == true)
			Fx.impact(scene, end, hit2.normal, Color(1.0, 0.3, 0.15))
		else:
			Fx.impact(scene, end, hit2.normal, Color(1.0, 0.75, 0.4))
			Sfx.play_at("impact", end, 0.0, 1.0, 0.15)
	Fx.tracer(scene, from, end, Color(1.0, 0.8, 0.5))
	Sfx.play("shot", 0.0, 1.0 + heat * 0.12, 0.04)

	_muzzle_light.light_energy = 5.0
	_pitch = minf(_pitch + 0.012, 1.1)
	_shake = minf(_shake + 0.12, 0.6)


func _update_heat(delta: float) -> void:
	if heat <= 0.0:
		return
	if _since_fire > 0.45 or overheated:
		heat = maxf(heat - (0.55 if overheated else 0.4) * delta, 0.0)
		if heat <= 0.0:
			overheated = false
		heat_changed.emit(heat, overheated)


func _try_melee() -> void:
	if _since_melee < MELEE_COOLDOWN or grappling or dead:
		return
	_since_melee = 0.0
	_melee_hit_done = false
	Sfx.play("whoosh", 0.0, 1.25, 0.08)
	if is_on_floor():
		var fwd := Basis(Vector3.UP, _yaw) * Vector3.FORWARD
		velocity += fwd * 5.0


func _update_melee() -> void:
	# Der Treffer sitzt kurz nach dem Ausholen
	if _melee_hit_done or _since_melee < 0.12:
		return
	_melee_hit_done = true
	var fwd := Basis(Vector3.UP, _yaw) * Vector3.FORWARD
	var origin := aim_point()
	var any := false
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if enemy.dead:
			continue
		var center: Vector3 = enemy.global_position + Vector3(0, 1.4, 0)
		var to := center - origin
		var reach: float = 2.7 + (enemy.get("body_radius") if enemy.get("body_radius") else 0.5)
		if Vector3(to.x, 0, to.z).length() > reach or absf(to.y) > 4.0:
			continue
		if to.normalized().dot(fwd) < 0.2:
			continue
		enemy.take_damage(Game.melee_damage(), origin + to * 0.6, fwd)
		hit_confirmed.emit(enemy.dead)
		Fx.impact(get_tree().current_scene, origin + to * 0.6, -fwd, ENTITY)
		any = true
	if any:
		_shake = minf(_shake + 0.3, 0.6)
		Sfx.play("claw_hit", 0.0, 1.0, 0.08)


# --- Figur --------------------------------------------------------------

func _update_model(delta: float) -> void:
	var speed := Vector3(velocity.x, 0, velocity.z).length()
	var face_cam := aiming or _since_fire < 0.8 or _since_melee < 0.5
	var target_yaw := _model.rotation.y
	if grappling:
		# Am Seil: Blick in Flugrichtung, im Stand zum Anker
		var to := _grapple_point - global_position
		var face := Vector3(velocity.x, 0, velocity.z)
		if face.length() < 4.0:
			face = Vector3(to.x, 0, to.z)
		target_yaw = atan2(-face.x, -face.z)
	elif face_cam:
		target_yaw = _yaw
	elif speed > 0.3:
		target_yaw = atan2(-velocity.x, -velocity.z)
	_model.rotation.y = lerp_angle(_model.rotation.y, target_yaw, 1.0 - exp(-delta * 12.0))
	# In der Luft legt sich die Figur in die Flugrichtung
	var lean := 0.0
	if not is_on_floor() and not face_cam:
		lean = -clampf((velocity.length() - 6.0) / 24.0, 0.0, 1.0) * 0.75
	_model.rotation.x = lerpf(_model.rotation.x, lean, 1.0 - exp(-delta * 8.0))

	var k := 1.0 - exp(-delta * 14.0)
	var swing := 0.0
	if grappling:
		swing = 0.5
	elif is_on_floor() and speed > 0.3:
		_walk_phase += delta * (5.0 + speed * 1.3)
		var step := int(_walk_phase / PI)
		if step != _step_index:
			_step_index = step
			Sfx.play("step1" if step % 2 == 0 else "step2", clampf(speed - 6.0, -4.0, 2.0), 1.0, 0.1)
		swing = sin(_walk_phase) * clampf(speed / SPRINT_SPEED, 0.25, 1.0) * 0.85
	elif not is_on_floor():
		swing = 0.35
	_leg_l.rotation.x = lerpf(_leg_l.rotation.x, swing, k)
	_leg_r.rotation.x = lerpf(_leg_r.rotation.x, -swing, k)

	# Rechts: Waffe
	var gun_target := -swing * 0.2 + 0.15
	if aiming or _since_fire < 0.8:
		gun_target = PI * 0.5 + _pitch
	_arm_r.rotation.x = lerpf(_arm_r.rotation.x, gun_target, k)

	# Links: der Arm. Hängt schwer, greift zum Haken, schlägt als Klaue.
	var arm_target := -swing * 0.45 + 0.05
	var arm_side := 0.0
	var arm_yaw := 0.0
	if grappling:
		var local: Vector3 = _model.global_transform.basis.inverse() * (_hook.global_position - _arm_l.global_position)
		arm_target = PI * 0.5 + atan2(local.y, Vector2(local.x, local.z).length())
		arm_yaw = atan2(-local.x, -local.z)
	elif _since_melee < 0.45:
		var t := _since_melee / 0.45
		arm_target = lerpf(2.7, 0.6, t) if t > 0.25 else lerpf(0.2, 2.7, t / 0.25)
		arm_side = sin(t * PI) * 0.7
		k = 1.0
	_arm_l.rotation.x = lerpf(_arm_l.rotation.x, arm_target, k)
	_arm_l.rotation.z = lerpf(_arm_l.rotation.z, arm_side, k)
	_arm_l.rotation.y = lerp_angle(_arm_l.rotation.y, arm_yaw, k)
	_model.position.y = absf(sin(_walk_phase)) * 0.04 if swing != 0.0 and is_on_floor() else 0.0


func _update_focus() -> void:
	var best: Node = null
	var best_d := INTERACT_RANGE
	for node in get_tree().get_nodes_in_group("interactable"):
		if not node.enabled:
			continue
		var d: float = node.global_position.distance_to(global_position)
		if d < best_d:
			best_d = d
			best = node
	_focus = best
	var text: String = best.prompt if best and not Game.reading else ""
	if text != _prompt:
		_prompt = text
		prompt_changed.emit(text)


# --- Tod & Rückkehr -----------------------------------------------------

func _die() -> void:
	if dead:
		return
	dead = true
	if grappling:
		_end_grapple("drop")
	Sfx.play("death")
	Sfx.stop_loops()
	health = 0.0
	health_changed.emit(health, Game.max_health())
	died.emit()
	await get_tree().create_timer(1.6).timeout
	if grappling:
		_end_grapple("drop")
	global_position = _checkpoint
	velocity = Vector3.ZERO
	gas = GAS_CHARGES
	set_look(_checkpoint_yaw, -0.08)
	health = Game.max_health()
	heat = 0.0
	overheated = false
	dead = false
	_since_damage = 10.0
	health_changed.emit(health, Game.max_health())
	heat_changed.emit(heat, overheated)
	respawned.emit()
