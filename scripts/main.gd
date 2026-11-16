extends Node3D
## Einstieg: zeigt beim Start das Menü (falls es einen Spielstand gibt) und
## baut dann Atmosphäre, den aktuellen Layer, Spielfigur und HUD zusammen.

const LEVELS := {
	1: preload("res://scripts/level_01.gd"),
	2: preload("res://scripts/level_02.gd"),
}
const PlayerScript := preload("res://scripts/player.gd")
const Hud := preload("res://scripts/hud.gd")
const StartMenu := preload("res://scripts/start_menu.gd")


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var dev_mode := ""
	for candidate in ["shots", "smoke", "test"]:
		if ("--" + candidate) in args:
			dev_mode = candidate
	if not Game.booted:
		Game.booted = true
		if dev_mode != "":
			Game.saving_enabled = false          # Tests fassen den echten Spielstand nicht an
			for arg in args:
				if arg.begins_with("--layer="):
					Game.layer = int(arg.trim_prefix("--layer="))
			if "--continue" in args:                 # Spielstand laden wie über "Fortsetzen"
				Game.load_save()
		elif Game.has_save():
			add_child(StartMenu.new())
			return

	var level: Node3D = LEVELS.get(Game.layer, LEVELS[1]).new()
	level.name = "Level"
	add_child(level)                             # _ready des Layers setzt Stimmung und baut die Welt
	_setup_environment(level)

	var spawn: Vector3 = level.spawn_point
	var yaw: float = level.spawn_yaw
	if Game.saved_checkpoint != null:
		var p: Array = Game.saved_checkpoint["pos"]
		spawn = Vector3(p[0], p[1], p[2])
		yaw = Game.saved_checkpoint["yaw"]
	var player := PlayerScript.new()
	player.name = "Player"
	add_child(player)
	player.global_position = spawn
	player.set_look(yaw, -0.05)
	player.set_checkpoint(spawn, yaw)
	Game.player = player

	var hud := Hud.new()
	hud.name = "HUD"
	add_child(hud)
	hud.bind_player(player)

	if dev_mode != "":
		var dev: Node = load("res://scripts/dev_shots.gd").new()
		dev.mode = dev_mode
		add_child(dev)
	else:
		level.start_story()


func _setup_environment(level: Node3D) -> void:
	var fog: Color = level.fog_color
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = fog
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = level.ambient_color
	env.ambient_light_energy = level.ambient_energy

	# Tiefennebel verschluckt alles, was weiter als ein paar hundert Meter weg ist
	env.fog_enabled = true
	env.fog_light_color = fog
	env.fog_light_energy = 1.0
	env.fog_sun_scatter = 0.0
	env.fog_density = level.fog_density
	env.fog_sky_affect = 1.0

	# Volumetrischer Nebel für Lichthöfe um Lampen in der Nähe
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.004
	env.volumetric_fog_albedo = Color(0.75, 0.82, 0.88)
	env.volumetric_fog_length = 110.0
	env.volumetric_fog_ambient_inject = 0.4

	env.glow_enabled = true
	env.glow_intensity = 0.9
	env.glow_bloom = 0.08
	env.glow_hdr_threshold = 1.0
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_white = 4.0
	env.ssao_enabled = true
	env.ssao_radius = 2.0
	env.ssao_intensity = 2.5
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.08
	env.adjustment_saturation = 0.82

	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	# Fahles Restlicht von weit oben
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-62, 28, 0)
	sun.light_color = level.sun_color
	sun.light_energy = level.sun_energy
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 260.0
	sun.light_volumetric_fog_energy = 0.3
	add_child(sun)
