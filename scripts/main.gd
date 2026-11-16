extends Node3D
## Einstieg: baut Atmosphäre, Level, Spielfigur und HUD zusammen.

const Level := preload("res://scripts/level_01.gd")
const PlayerScript := preload("res://scripts/player.gd")
const Hud := preload("res://scripts/hud.gd")

const FOG := Color(0.15, 0.18, 0.205)


func _ready() -> void:
	_setup_environment()

	var level := Level.new()
	level.name = "Level"
	add_child(level)

	var player := PlayerScript.new()
	player.name = "Player"
	add_child(player)
	player.global_position = level.spawn_point
	player.set_look(level.spawn_yaw, -0.05)
	player.set_checkpoint(level.spawn_point, level.spawn_yaw)
	Game.player = player

	var hud := Hud.new()
	hud.name = "HUD"
	add_child(hud)
	hud.bind_player(player)

	var args := OS.get_cmdline_user_args()
	var dev_mode := ""
	for candidate in ["shots", "smoke", "test"]:
		if ("--" + candidate) in args:
			dev_mode = candidate
	if dev_mode != "":
		var dev: Node = load("res://scripts/dev_shots.gd").new()
		dev.mode = dev_mode
		add_child(dev)
	else:
		level.start_story()


func _setup_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = FOG
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.42, 0.5, 0.56)
	env.ambient_light_energy = 0.42

	# Tiefennebel verschluckt alles, was weiter als ein paar hundert Meter weg ist
	env.fog_enabled = true
	env.fog_light_color = FOG
	env.fog_light_energy = 1.0
	env.fog_sun_scatter = 0.0
	env.fog_density = 0.0034
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
	sun.light_color = Color(0.62, 0.72, 0.82)
	sun.light_energy = 0.7
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 260.0
	sun.light_volumetric_fog_energy = 0.3
	add_child(sun)
