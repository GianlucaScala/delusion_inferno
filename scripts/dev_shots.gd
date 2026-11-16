extends Node
## Entwicklerwerkzeug, läuft nur mit Kommandozeilen-Argumenten:
##   godot -- --shots [--hud]   Screenshots fester Blickpunkte nach res://shots/
##   godot --headless -- --smoke   ein paar hundert Frames laufen lassen
##   godot --headless -- --test    Haken, Kampf, Boss und Tor automatisch durchspielen

const VIEWS := [
	["01_start", Vector3(0, 0.1, 7.0), 0.0, -0.02],
	["02_bridge", Vector3(0, 0.1, -20.0), 0.55, -0.25],
	["03_abyss", Vector3(-0.8, 0.1, -29.0), 1.35, -0.8],
	["04_ramp", Vector3(16.0, 1.5, -72.0), -1.45, 0.42],
	["05_arena", Vector3(38.5, 8.1, -72.0), -1.45, 0.02],
	["06_gap", Vector3(54, 8.1, -95.0), 0.0, 0.05],
	["07_boss", Vector3(54, 8.1, -121.0), 0.0, 0.16],
	["08_canyon", Vector3(70, 8.1, -56.0), -2.1, 0.1],
]

var mode := "shots"


func _ready() -> void:
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _look_at(player: Node3D, target: Vector3) -> void:
	var to: Vector3 = target - (player.global_position + Vector3(0, 1.6, 0))
	player.set_look(atan2(-to.x, -to.z), atan2(to.y, Vector2(to.x, to.z).length()))


func _run() -> void:
	var player: Node3D = Game.player
	match mode:
		"smoke":
			await _frames(240)
			print("SMOKE OK  enemies=", get_tree().get_nodes_in_group("enemy").size(), " player=", player.global_position)
		"test":
			await _test(player)
		_:
			await _shots(player)
	get_tree().quit()


func _shots(player: Node3D) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://shots"))
	var hud: Node = get_tree().current_scene.get_node("HUD")
	hud.visible = "--hud" in OS.get_cmdline_user_args()
	if hud.visible:
		Game.set_objective("Überlebe den Pförtner")
		Game.add_xp(60)
	for view in VIEWS:
		player.global_position = view[1]
		player.velocity = Vector3.ZERO
		player.set_look(view[2], view[3])
		player.health = Game.max_health()
		for i in 14:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		img.save_png("res://shots/%s.png" % view[0])
		print("shot ", view[0])


func _check(label: String, ok: bool, detail: Variant = "") -> void:
	print("%s  %s  %s" % ["PASS" if ok else "FAIL", label, str(detail)])


func _test(player: Node3D) -> void:
	await _frames(30)

	# 1) Haken von der abgerissenen Rampe hinauf aufs Verteilerdeck
	player.global_position = Vector3(20.5, 3.0, -72)
	player.velocity = Vector3.ZERO
	await _frames(20)
	_look_at(player, Vector3(38.5, 19.2, -72))
	await _frames(5)
	player._try_grapple()
	_check("grapple fires at beam", player.grappling, player._grapple_point)
	await _frames(240)
	var p := player.global_position
	_check("lands on distributor deck", p.x > 36.0 and absf(p.y - 8.0) < 0.6, p)

	# 2) Schießen: ein Fugenläufer muss Schaden nehmen und sterben können
	var enemy: Node3D = null
	for e in get_tree().get_nodes_in_group("enemy"):
		if e.get("active") == null:
			enemy = e
			break
	var before: float = enemy.health
	player.global_position = enemy.global_position + Vector3(-6, 0, 0)
	await _frames(10)
	_look_at(player, enemy.global_position + Vector3(0, 1.4, 0))
	await _frames(3)
	player._try_fire()
	await _frames(3)
	_check("shot damages enemy", enemy.health < before, "%s -> %s" % [before, enemy.health])
	var xp0 := Game.xp + Game.level * 1000
	player.global_position = enemy.global_position + Vector3(-1.8, 0, 0)
	await _frames(5)
	_look_at(player, enemy.global_position + Vector3(0, 1.4, 0))
	player._try_melee()
	await _frames(12)
	player._since_melee = 10.0
	if is_instance_valid(enemy) and not enemy.dead:
		player._try_melee()
		await _frames(12)
	_check("claw kills enemy, grants xp", not is_instance_valid(enemy) or enemy.dead, Game.xp + Game.level * 1000 - xp0)
	for e in get_tree().get_nodes_in_group("enemy"):
		if e.get("active") == null:
			e.take_damage(999.0, e.global_position)

	# 3) Haken über die gebrochene Brücke
	player.global_position = Vector3(54, 8.1, -98.5)
	player.velocity = Vector3.ZERO
	await _frames(20)
	_look_at(player, Vector3(54, 14.4, -112))
	await _frames(5)
	player._try_grapple()
	_check("grapple fires at portal", player.grappling, player._grapple_point)
	await _frames(200)
	p = player.global_position
	_check("crosses the bridge gap", p.z < -109.5 and absf(p.y - 8.0) < 0.6, p)

	# 4) Boss: aktivieren, Welle abwarten, niederkämpfen
	player.global_position = Vector3(54, 8.1, -121)
	await _frames(30)
	var boss: Node3D = get_parent().get_node("Level")._boss
	_check("boss activates on entry", boss.active)
	var hp0: float = player.health
	await _frames(600)
	_check("boss hurts an idle player", player.health < hp0 or player.dead, "%s -> %s" % [hp0, player.health])
	_check("boss stays on plaza", absf(boss.global_position.y - 8.0) < 1.0, boss.global_position)
	while is_instance_valid(boss) and not boss.dead:
		boss.take_damage(150.0, boss.global_position + Vector3(0, 4, 0))
		await _frames(2)
	await _frames(10)
	var level: Node = get_parent().get_node("Level")
	_check("gate switch unlocks", level._gate_switch.enabled)
	_check("leveled up", Game.level > 1 and Game.skill_points > 0, "level %d, points %d" % [Game.level, Game.skill_points])
	_check("spend point raises max health", Game.spend_point("fleisch") and Game.max_health() == 120.0)

	# 5) Tor öffnen und in den Schacht fallen
	while player.dead:
		await _frames(10)
	level._gate_switch.interact(player)
	await _frames(400)
	_check("door is open", level._door.position.y > 19.0, level._door.position.y)
	player.global_position = Vector3(54, 8.1, -152)
	player.set_look(0.0, 0.0)
	await _frames(10)
	Input.action_press("move_forward")
	Input.action_press("sprint")
	await _frames(360)
	Input.action_release("move_forward")
	Input.action_release("sprint")
	_check("falling into the shaft ends the layer", Game.ended, player.global_position)
	print("TEST DONE")
