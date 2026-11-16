extends Node3D
## Etwas, das man mit [E] benutzen kann (Terminal, Schalter).

var prompt := "Benutzen"
var enabled := true
var one_shot := false
var on_use: Callable


func _init() -> void:
	add_to_group("interactable")


func interact(who: Node) -> void:
	if not enabled:
		return
	if one_shot:
		enabled = false
	if on_use.is_valid():
		on_use.call(who)
