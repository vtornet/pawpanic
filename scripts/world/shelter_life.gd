class_name ShelterLife
extends Node3D
## Vida dentro del refugio: los animales se mueven por su zona (pasean, se sientan,
## duermen) y el personal recorre sus puntos de trabajo.

var _animals: Array = []   # {node, center, half, state, timer, target, speed, phase, energy, sick}
var _workers: Array = []   # {node, points, i, pause, speed}


func clear_animals() -> void:
	_animals.clear()


func clear_workers() -> void:
	_workers.clear()


## center: posición global del centro de su zona; half: medio tamaño (x, z) de la zona.
func add_animal(node: Node3D, a: Dictionary, center: Vector3, half: Vector2) -> void:
	var speed := 1.3 if a["energy"] == "enérgico" else (0.6 if a["energy"] == "miedoso" else 0.85)
	_animals.append({"node": node, "center": center, "half": half, "state": "stand", "timer": randf_range(0.5, 3.0),
		"target": node.global_position, "speed": speed, "phase": randf() * TAU, "energy": a["energy"],
		"sick": a["sick"] or a["injured"] or a["health"] < 35, "shelf": half == Vector2.ZERO})


func add_worker(node: Npc, points: Array) -> void:
	if points.size() < 2:
		return
	_workers.append({"node": node, "points": points, "i": randi() % points.size(), "pause": randf_range(0.0, 3.0),
		"speed": randf_range(1.0, 1.4)})


func _process(delta: float) -> void:
	if Game.paused:
		return
	var hour: float = Game.s.get("minute", 600) / 60.0
	for an in _animals:
		if not is_instance_valid(an["node"]):
			continue
		_tick_animal(an, delta, hour)
	for w in _workers:
		if not is_instance_valid(w["node"]):
			continue
		_tick_worker(w, delta)


func _tick_animal(an: Dictionary, delta: float, hour: float) -> void:
	var node: Node3D = an["node"]
	an["phase"] += delta * 9.0 * an["speed"]
	an["timer"] -= delta
	var night := hour >= 20.0
	if an["timer"] <= 0.0:
		_choose(an, night)
	if an["state"] == "walk":
		var to: Vector3 = an["target"] - node.global_position
		to.y = 0
		if to.length() < 0.08:
			an["state"] = "stand"
			an["timer"] = randf_range(0.8, 2.5)
		else:
			var step: Vector3 = to.normalized() * an["speed"] * delta
			node.global_position += step if step.length() < to.length() else to
			node.rotation.y = lerp_angle(node.rotation.y, atan2(-to.x, -to.z), clampf(delta * 8.0, 0.0, 1.0))
	AnimalMesh.pose(node, an["state"], an["phase"], delta)


## Decide qué hace a continuación según su carácter, su salud y la hora.
func _choose(an: Dictionary, night: bool) -> void:
	if an["shelf"]:
		an["state"] = "sleep" if randf() < 0.6 else "sit"
		an["timer"] = randf_range(4.0, 10.0)
		return
	var r := randf()
	var walk_p := 0.65 if an["energy"] == "enérgico" else (0.3 if an["energy"] == "miedoso" else 0.45)
	var sleep_p := 0.1
	if an["sick"]:
		walk_p = 0.1
		sleep_p = 0.7
	if night:
		walk_p *= 0.25
		sleep_p = 0.8
	if r < sleep_p:
		an["state"] = "sleep"
		an["timer"] = randf_range(6.0, 14.0)
	elif r < sleep_p + walk_p:
		an["state"] = "walk"
		var half: Vector2 = an["half"]
		var off := Vector3(randf_range(-half.x, half.x), 0, randf_range(-half.y, half.y))
		if an["energy"] == "miedoso":
			off.z = absf(off.z)  # se queda al fondo
		an["target"] = an["center"] + off
		an["timer"] = 6.0
	elif r < sleep_p + walk_p + 0.2:
		an["state"] = "sit"
		an["timer"] = randf_range(3.0, 7.0)
	else:
		an["state"] = "stand"
		an["timer"] = randf_range(1.5, 4.0)


func _tick_worker(w: Dictionary, delta: float) -> void:
	var n: Npc = w["node"]
	if w["pause"] > 0.0:
		w["pause"] -= delta
		n.walking = false
		return
	var target: Vector3 = w["points"][w["i"]]
	var to := target - n.global_position
	to.y = 0
	if to.length() < 0.15:
		w["i"] = (w["i"] + 1) % w["points"].size()
		w["pause"] = randf_range(2.0, 6.0)  # haciendo su tarea en ese punto
		return
	n.walking = true
	var step: Vector3 = to.normalized() * w["speed"] * delta
	n.global_position += step if step.length() < to.length() else to
	n.rotation.y = lerp_angle(n.rotation.y, atan2(-to.x, -to.z), clampf(delta * 8.0, 0.0, 1.0))
