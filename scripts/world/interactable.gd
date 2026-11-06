class_name Interactable
extends Node3D
## Algo con lo que el jugador puede interactuar pulsando E.

var prompt := ""
var action: Callable
var radius := 3.0


static func create(p_prompt: String, p_action: Callable, p_radius: float = 3.0) -> Interactable:
	var i := Interactable.new()
	i.prompt = p_prompt
	i.action = p_action
	i.radius = p_radius
	return i


func _ready() -> void:
	add_to_group("interactable")
