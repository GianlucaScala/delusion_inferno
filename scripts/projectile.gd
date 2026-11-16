extends Area3D
## Langsamer Schweißbolzen der Fugenläufer. Man kann ihm ausweichen.

const Fx := preload("res://scripts/fx.gd")

var velocity := Vector3.ZERO
var damage := 12.0
var _life := 6.0


func _ready() -> void:
	collision_layer = 0
	collision_mask = Game.LAYER_WORLD | Game.LAYER_PLAYER
	var shape := SphereShape3D.new()
	shape.radius = 0.18
	var cs := CollisionShape3D.new()
	cs.shape = shape
	add_child(cs)

	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.16, 0.16, 0.5)
	mesh.material = Fx.glow_material(Color(1.0, 0.25, 0.1), 6.0)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)

	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.3, 0.12)
	light.light_energy = 1.6
	light.omni_range = 6.0
	add_child(light)

	body_entered.connect(_on_body)
	if velocity.length() > 0.1:
		look_at(global_position + velocity, Vector3.UP if absf(velocity.normalized().y) < 0.99 else Vector3.RIGHT)


func _physics_process(delta: float) -> void:
	global_position += velocity * delta
	_life -= delta
	if _life <= 0.0:
		queue_free()


func _on_body(body: Node) -> void:
	if body.is_in_group("player") and body.has_method("take_damage"):
		body.take_damage(damage, global_position, velocity.normalized())
	Fx.impact(get_tree().current_scene, global_position, -velocity.normalized(), Color(1.0, 0.3, 0.12))
	Sfx.play_at("impact", global_position, -2.0, 0.8, 0.15)
	queue_free()
