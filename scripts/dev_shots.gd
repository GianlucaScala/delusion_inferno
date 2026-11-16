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

const VIEWS_2 := [
	["20_basin", Vector3(-3.5, 0.1, 5.0), -0.95, 0.12],
	["21_hangs", Vector3(0, 0.1, -7.0), -0.25, 0.1],
	["22_down", Vector3(7.5, 0.1, -7.5), -0.9, -0.85],
	["23_naht_gate", Vector3(16, 0.1, -112.0), 0.0, 0.12],
	["24_naht", Vector3(16, 0.1, -130.0), -0.35, 0.08],
	["25_vesper", Vector3(22.5, 0.1, -143.5), -1.15, 0.0],
	["26_mast", Vector3(16, 0.1, -214.0), 0.0, 0.5],
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
			if Game.layer == 2:
				await _test_layer2(player)
			else:
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
	var views: Array = VIEWS_2 if Game.layer == 2 else VIEWS
	for e in get_tree().get_nodes_in_group("enemy"):
		if Game.layer == 2:
			e.set_physics_process(false)
	for view in views:
		if "--only-swing" in OS.get_cmdline_user_args():
			break
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
	if Game.layer == 2:
		# Gesprächsfenster mit Antworten
		var vesper := _find_npc("vesper")
		player.global_position = vesper.global_position + Vector3(-2.2, 0.1, 1.2)
		_look_at(player, vesper.global_position + Vector3(0, 1.3, 0))
		await _frames(8)
		vesper.interact(player)
		Game.talk_choose(0)
		for i in 6:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://shots/27_talk.png")
		print("shot 27_talk")
		return

	# Mitten im Schwung: aus dem Lauf an den Träger über der Schlucht
	while player.dead:
		await _frames(10)
	for e in get_tree().get_nodes_in_group("enemy"):
		e.set_physics_process(false)
	player.health = Game.max_health()
	player.grapple_cd = 0.0
	player.global_position = Vector3(0, 0.1, -20)
	player.velocity = Vector3(0, 0, -7)
	player.set_look(0.0, 0.0)
	await _frames(6)
	_look_at(player, Vector3(14.5, 21.0, -44))
	await _frames(2)
	player._try_grapple()
	print("swing shot hooked: ", player.grappling)
	await _frames(40)
	player.set_look(-0.9, 0.3)
	for i in 3:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://shots/09_swing.png")
	print("shot 09_swing")


func _check(label: String, ok: bool, detail: Variant = "") -> void:
	print("%s  %s  %s" % ["PASS" if ok else "FAIL", label, str(detail)])


func _test(player: Node3D) -> void:
	var trace := "--trace" in OS.get_cmdline_user_args()
	await _frames(30)

	# 0) Ton: alle Dateien geladen, Loops laufen wirklich im Kreis
	_check("all sounds loaded", Sfx._streams.size() == Sfx.GAIN.size(), "%d / %d" % [Sfx._streams.size(), Sfx.GAIN.size()])
	var amb: AudioStreamPlayer = Sfx._music["ambient_loop"]["player"]
	_check("ambient is playing", amb.playing and amb.stream.loop_mode == AudioStreamWAV.LOOP_FORWARD, amb.stream.get_length())

	# 4) Schießen und Klaue (zuerst, solange die Gegner noch am Platz stehen)
	var enemy: Node3D = null
	for e in get_tree().get_nodes_in_group("enemy"):
		if e.get("active") == null:
			enemy = e
			break
	var before: float = enemy.health
	player.global_position = enemy.global_position + Vector3(-6, 0, 0)
	player.velocity = Vector3.ZERO
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

	# 1) Passiv am Seil: von der abgerissenen Rampe hinauf aufs Verteilerdeck
	player.global_position = Vector3(20.5, 3.0, -72)
	player.velocity = Vector3.ZERO
	await _frames(20)
	_look_at(player, Vector3(38.5, 19.2, -72))
	await _frames(5)
	player._try_grapple()
	_check("grapple fires at beam", player.grappling, player._grapple_point)
	var fling := 0.0
	var hooked_frames := 0
	for i in 300:
		await get_tree().physics_frame
		if player.grappling:
			hooked_frames += 1
		elif not player.is_on_floor():
			fling = maxf(fling, Vector3(player.velocity.x, 0, player.velocity.z).length())
		if trace and i % 10 == 0:
			print("  f%03d pos %s vel %s rope %.1f hooked %s floor %s" % [i, player.global_position, player.velocity, player._rope_len, player.grappling, player.is_on_floor()])
	var p := player.global_position
	_check("lands on distributor deck", p.x > 36.0 and p.x < 72.0 and absf(p.y - 8.0) < 0.6, p)
	_check("arrival flings past the anchor", fling >= 10.0 and hooked_frames < 150, "%.1f m/s after %.2f s on the rope" % [fling, hooked_frames / 60.0])

	# 2) Pendel: Seil halten (S), Länge bleibt, Figur schwingt durch
	player.global_position = Vector3(27.0, 13.0, -72)
	player.velocity = Vector3.ZERO
	_look_at(player, Vector3(38.5, 19.2, -72))
	await _frames(2)
	Input.action_press("move_back")
	player._try_grapple()
	var rope: float = player._rope_len
	var worst := 0.0
	var min_x := 99.0
	var max_x := -99.0
	var top_speed := 0.0
	for i in 150:
		await get_tree().physics_frame
		if not player.grappling:
			break
		worst = maxf(worst, player._grapple_point.distance_to(player.aim_point()) - rope)
		min_x = minf(min_x, player.global_position.x)
		max_x = maxf(max_x, player.global_position.x)
		top_speed = maxf(top_speed, player.velocity.length())
	_check("rope never stretches while held", player.grappling and worst < 0.25, "rope %.1f m, worst overshoot %.2f m" % [rope, worst])
	_check("pendulum swings through", max_x - min_x > 8.0 and top_speed > 8.0, "x %.1f..%.1f, top speed %.1f" % [min_x, max_x, top_speed])

	# 3) Abspringen nimmt den Schwung mit, Gasstoß legt nach
	Input.action_release("move_back")
	while player.grappling and player.velocity.x < 6.0:
		await get_tree().physics_frame
	var before_speed: float = player.velocity.length()
	player._end_grapple("jump")
	_check("jump-off keeps momentum", player.velocity.length() >= before_speed and before_speed > 6.0, "%.1f -> %.1f m/s" % [before_speed, player.velocity.length()])
	await _frames(6)
	var gas_before: float = player.gas
	var speed_before: float = player.velocity.length()
	player._gas_burst(Vector3.ZERO)
	_check("gas burst uses a charge and adds speed", player.gas < gas_before and player.velocity.length() > speed_before, "gas %.1f -> %.1f, %.1f -> %.1f m/s" % [gas_before, player.gas, speed_before, player.velocity.length()])

	# 3b) Aus dem Lauf an den Träger über der Schlucht: Bogen statt Gerade
	player.global_position = Vector3(0, 0.1, -20)
	player.velocity = Vector3.ZERO
	player.set_look(0.0, 0.0)
	await _frames(10)
	Input.action_press("move_forward")
	Input.action_press("sprint")
	await _frames(40)
	_look_at(player, Vector3(14.5, 21.0, -44))
	await _frames(2)
	player._try_grapple()
	Input.action_release("move_forward")
	Input.action_release("sprint")
	var hooked_at: Vector3 = player.global_position
	var swing_top := 0.0
	var bend := 0.0
	var line: Vector3 = (player._grapple_point - player.aim_point()).normalized()
	for i in 200:
		await get_tree().physics_frame
		if not player.grappling:
			break
		swing_top = maxf(swing_top, player.velocity.length())
		var rel: Vector3 = player.global_position - hooked_at
		bend = maxf(bend, (rel - line * rel.dot(line)).length())
		if trace and i % 6 == 0:
			print("  s%03d pos %s vel %s rope %.1f" % [i, player.global_position, player.velocity, player._rope_len])
	_check("running hook bends into an arc", player.grappling == false and bend > 1.0 and swing_top > 15.0, "%.1f m off the straight line, top speed %.1f" % [bend, swing_top])
	player.global_position = Vector3(54, 8.1, -75)
	player.velocity = Vector3.ZERO
	await _frames(20)
	player.health = Game.max_health()

	# 5) Haken über die gebrochene Brücke
	player.global_position = Vector3(54, 8.1, -98.5)
	player.velocity = Vector3.ZERO
	await _frames(20)
	_look_at(player, Vector3(54, 14.4, -112))
	await _frames(5)
	player._try_grapple()
	_check("grapple fires at portal", player.grappling, player._grapple_point)
	for i in 240:
		await get_tree().physics_frame
		if trace and i % 10 == 0:
			print("  g%03d pos %s vel %s hooked %s" % [i, player.global_position, player.velocity, player.grappling])
	p = player.global_position
	_check("crosses the bridge gap", p.z < -109.5 and p.z > -150.0 and absf(p.y - 8.0) < 0.6, p)

	# 6) Boss: aktivieren, Welle abwarten, niederkämpfen
	player.global_position = Vector3(54, 8.1, -121)
	player.velocity = Vector3.ZERO
	await _frames(30)
	var boss: Node3D = get_parent().get_node("Level")._boss
	_check("boss activates on entry", boss.active)
	_check("boss music fades in", Sfx._music.has("boss_music_loop") and Sfx._music["boss_music_loop"]["target"] == 1.0)
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

	# 7) Tor öffnen und in den Schacht fallen
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
	for i in 400:
		await get_tree().physics_frame
		if Game.transitioning:
			break
	Input.action_release("move_forward")
	Input.action_release("sprint")
	_check("falling into the shaft starts the descent to layer II", Game.transitioning, player.global_position)
	_check("ambient looped past its 16 s", amb.playing and amb.get_playback_position() < amb.stream.get_length(), "pos %.1f s" % amb.get_playback_position())
	print("TEST DONE")


# --- Layer II -----------------------------------------------------------

func _find_npc(look: String) -> Node:
	for node in get_tree().get_nodes_in_group("interactable"):
		if node.get("look") == look:
			return node
	return null


func _kill_all() -> void:
	for e in get_tree().get_nodes_in_group("enemy"):
		e.take_damage(9999.0, e.global_position)


## Klickt sich durch ein Gespräch. prefer: Textstücke in der Reihenfolge, in
## der Antworten gewählt werden sollen; jedes wird höchstens einmal benutzt.
func _talk_auto(prefer: Array) -> void:
	var used := {}
	for step in 60:
		if not Game.talking:
			return
		if Game._talk_choices.is_empty():
			Game.talk_advance()
		else:
			var pick := Game._talk_choices.size() - 1
			var found := false
			for want in prefer:
				if used.has(want) or found:
					continue
				for i in Game._talk_choices.size():
					if String(Game._talk_choices[i]["text"]).contains(want):
						pick = i
						used[want] = true
						found = true
						break
			Game.talk_choose(pick)
		await _frames(2)


## Stellt die Figur hin, hakt den Punkt an und wartet passiv ab.
func _hop(player: Node3D, from: Vector3, target: Vector3, frames := 260) -> Vector3:
	player.global_position = from
	player.velocity = Vector3.ZERO
	player.grapple_cd = 0.0
	await _frames(15)
	_look_at(player, target)
	await _frames(4)
	player._try_grapple()
	if not player.grappling:
		print("  hop: hook did not fire from ", from)
	await _frames(frames)
	return player.global_position


func _test_layer2(player: Node3D) -> void:
	var level: Node = get_parent().get_node("Level")
	await _frames(30)
	_check("layer II builds with its own mood", level.layer_id == 2 and level.fog_color.r > level.fog_color.b, level.fog_color)
	_check("enemies and people are in place", get_tree().get_nodes_in_group("enemy").size() == 7 and _find_npc("vesper") != null and _find_npc("trader") != null)

	# 1) Fisher
	var fisher := _find_npc("fisher")
	player.global_position = fisher.global_position + Vector3(-1.6, 0.1, 0.8)
	await _frames(10)
	_check("fisher is in reach, prompt shows", player._focus == fisher, player._prompt)
	fisher.interact(player)
	_check("talk opens and blocks movement", Game.talking and Game.busy())
	await _talk_auto(["Wer bist", "Wie komme ich", "Wo geht es weiter"])
	_check("fisher sets the route to Naht", not Game.talking and Game.has_flag("l2_met_fisher") and Game.has_flag("fisher_who") and Game.objective.contains("Naht"), Game.objective)

	# 2) Die Hänge: drei passive Sprünge
	_kill_all()
	var p: Vector3 = await _hop(player, Vector3(0, 0.1, -8), Vector3(0, 6.4, -29))
	_check("hop 1 lands on the first hang", p.z < -27.5 and p.z > -55.0 and absf(p.x) < 8.0 and absf(p.y) < 0.6, p)
	p = await _hop(player, Vector3(2, 0.1, -54), Vector3(14, 6.4, -76))
	_check("hop 2 lands on the second hang", p.z < -74.5 and p.z > -104.0 and p.x > 4.0 and p.x < 32.0 and absf(p.y) < 0.6, p)
	p = await _hop(player, Vector3(16, 0.1, -103), Vector3(16, 7.4, -124))
	_check("hop 3 lands inside Naht", p.z < -122.5 and p.z > -186.0 and p.x > -10.0 and p.x < 42.0 and absf(p.y) < 0.6, p)
	_check("arrival sets checkpoint and objective", Game.has_flag("t2:naht") and Game.saved_checkpoint != null, Game.objective)

	# 3) Vesper: Auftrag annehmen
	var vesper := _find_npc("vesper")
	player.global_position = vesper.global_position + Vector3(-1.8, 0.1, 0)
	player.velocity = Vector3.ZERO
	await _frames(10)
	vesper.interact(player)
	await _talk_auto(["Arm zeigen", "War ich", "Wer ist die CSRU", "Was willst du", "Ich mache es"])
	_check("quest accepted, mast area wakes up", Game.has_flag("l2_quest") and Game.has_flag("vesper_honest") and level._mast_switch.enabled and get_tree().get_nodes_in_group("enemy").size() == 6, Game.objective)

	# 4) Krämer: kaufen, und nicht kaufen können
	var trader := _find_npc("trader")
	Game.scrap = 100
	trader.interact(player)
	await _talk_auto(["Gaskartusche", "Nichts"])
	_check("trader sells the gas cartridge", Game.gas_charges() == 3.0 and Game.scrap == 40, "scrap %d" % Game.scrap)
	Game.scrap = 10
	trader.interact(player)
	await _talk_auto(["Panzerplatte", "Nichts"])
	_check("no scrap, no deal", not Game.upgrades.has("plating") and Game.scrap == 10 and not Game.talking)

	# 5) Zum Signalmast, einschalten, zurück
	p = await _hop(player, Vector3(16, 0.1, -185.6), Vector3(16, 6.4, -208))
	_check("hop to the mast platform", p.z < -206.5 and p.z > -248.0 and absf(p.y) < 0.6, p)
	_kill_all()
	player.health = Game.max_health()
	player.global_position = level._mast_switch.global_position + Vector3(0, 0.1, 1.5)
	player.velocity = Vector3.ZERO
	await _frames(10)
	level._mast_switch.interact(player)
	await _frames(100)
	_check("mast is on, beacon lit", Game.has_flag("l2_mast_on") and level._beacon_light.light_energy > 4.0, Game.objective)
	p = await _hop(player, Vector3(16, 0.1, -206.6), Vector3(16, 7.4, -184))
	_check("hop back into Naht", p.z > -186.0 and p.z < -122.5 and absf(p.y) < 0.6, p)

	# 6) Vesper: Belohnung und Finale
	var level_before := Game.level * 10000 + Game.xp
	var scrap_before := Game.scrap
	player.global_position = vesper.global_position + Vector3(-1.8, 0.1, 0)
	player.velocity = Vector3.ZERO
	await _frames(10)
	vesper.interact(player)
	await _talk_auto(["Ich kämpfe"])
	_check("reward paid, finale triggered", Game.level * 10000 + Game.xp > level_before and Game.scrap == scrap_before + 40 and Game.has_flag("l2_finale") and Game.has_flag("vesper_fight"), "scrap %d -> %d" % [scrap_before, Game.scrap])
	Engine.time_scale = 6.0
	for i in 2400:
		await get_tree().physics_frame
		if Game.ended:
			break
	Engine.time_scale = 1.0
	_check("CSRU broadcast ends the act", Game.ended)

	# 7) Spielstand: schreiben, löschen, zurücklesen
	var snapshot := JSON.stringify(Game.to_save())
	var want_level := Game.level
	var want_scrap := Game.scrap
	Game.new_game()
	var wiped := Game.layer == 1 and Game.flags.is_empty() and Game.upgrades.is_empty() and Game.level == 1
	Game.from_save(JSON.parse_string(snapshot))
	_check("save round trip restores progress", wiped and Game.layer == 2 and Game.level == want_level and Game.has_flag("l2_mast_on") and Game.upgrades.has("gas_tank") and Game.scrap == want_scrap and Game.saved_checkpoint != null, "layer %d, level %d, scrap %d" % [Game.layer, Game.level, Game.scrap])
	print("TEST DONE")
