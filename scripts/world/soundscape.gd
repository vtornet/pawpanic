class_name Soundscape
extends Node
## Decide qué suena según dónde está el jugador y qué pasa en la partida:
## música, capas de ambiente, puertas al entrar en un edificio y los animales que ladran o maúllan.

var world: World

var _t := 0.0
var _was_indoor := false
var _known_calls := {}
var _urgent_until := 0.0
var _animal_cd := 0.0


func _process(delta: float) -> void:
	_t -= delta
	if _t > 0.0:
		return
	_t = 0.5
	_update_mix()
	_animals(0.5)


func _clock() -> float:
	return Time.get_ticks_msec() / 1000.0


func _update_mix() -> void:
	var s := Game.s
	if s.get("step", "") != "jugando":
		Sound.set_music("menu")
		Sound.set_ambience({"campo_dia": -14.0})
		return
	var p := world.player.global_position
	var hour: float = s["minute"] / 60.0
	var night := hour >= 19.5
	var place := _place_at(p) if world.player.indoor else ""
	var in_shelter := _in_shelter(p)

	# Al cruzar una puerta.
	if world.player.indoor != _was_indoor:
		_was_indoor = world.player.indoor
		if place != "" or in_shelter:
			Sound.play("puerta_madera", -8.0)
			if place == "tienda" and _was_indoor:
				Sound.play("campanilla_tienda", -6.0)

	# Avisos urgentes nuevos: un rato de música con más ritmo.
	for c in s["calls"]:
		if not _known_calls.has(c["id"]):
			_known_calls[c["id"]] = true
			if c.get("urgent", false):
				_urgent_until = _clock() + 120.0

	var layers := {}
	if world.player.indoor:
		match place:
			"clinica": layers = {"murmullo_gente": -16.0, "clinica_monitor": -18.0}
			"ayuntamiento": layers = {"oficina_ambiente": -8.0}
			"tienda": layers = {"murmullo_gente": -18.0}
			"peluqueria": layers = {"secador": -16.0, "perro_jadeo": -22.0}
			"crea": layers = {"rio": -22.0}
			_:
				if in_shelter and Game.occupancy() > 0:
					layers = {"interior_caseta": -6.0 if Game.occupancy() >= 3 else -12.0}
	else:
		var town := absf(p.x) < 75 and absf(p.z) < 75
		if night:
			layers["atardecer_grillos"] = -2.0
		else:
			layers["pueblo_dia" if town else "campo_dia"] = -2.0
		var river := absf(p.x + 80.0)
		if river < 30.0 and p.z > -80.0:
			layers["rio"] = lerpf(-4.0, -26.0, river / 30.0)
		if p.x > 55 and p.x < 145 and p.z > 65 and p.z < 145 and not night:
			layers["pinar_cigarras"] = -4.0 if Game.month_index() in [5, 6, 7, 8] else -16.0
		if town and not night and (absf(p.x) < 15 or absf(p.z) < 15):
			layers["trafico_lejano"] = -20.0
		if in_shelter and Game.occupancy() >= 3:
			layers["perrera_coro"] = (-12.0 if not night else -18.0) + minf(6.0, Game.occupancy() * 0.4)
	if s["events"].has("temporal"):
		layers["lluvia_tormenta"] = -10.0 if world.player.indoor else -2.0
		if not world.player.indoor:
			layers["viento_fuerte"] = -8.0
	if s["events"].has("incendio") and not world.player.indoor:
		layers["incendio_lejano"] = -10.0
	Sound.set_ambience(layers)

	# Música.
	var mood := "dia"
	if place in ["clinica", "ayuntamiento", "crea"]:
		mood = "interior"
	elif _clock() < _urgent_until or s["events"].has("incendio") or s["events"].has("temporal"):
		mood = "urgente"
	elif hour >= 18.5:
		mood = "tarde"
	Sound.set_music(mood)


## Edificio del pueblo en el que está el jugador ("" si ninguno).
func _place_at(p: Vector3) -> String:
	for k: String in World.PLACES:
		var pl: Dictionary = World.PLACES[k]
		var pos: Vector3 = pl["pos"]
		if Vector2(p.x - pos.x, p.z - pos.z).length() < pl["depth"] / 2.0 + 2.5:
			return k
	return ""


func _in_shelter(p: Vector3) -> bool:
	if Game.s.get("land", "") == "":
		return false
	var base: Vector3 = Game.s["land_pos"]
	var half := Game.land_size() / 2.0 + 2.0
	return absf(p.x - base.x) <= half and absf(p.z - base.z) <= half


## De vez en cuando, algún animal cercano ladra, maúlla o rebuzna.
func _animals(dt: float) -> void:
	_animal_cd -= dt
	if _animal_cd > 0.0 or Game.paused:
		return
	var p := world.player.global_position
	var hour: float = Game.s.get("minute", 600) / 60.0
	var candidates := []
	for entry in world.animal_nodes():
		var node: Node3D = entry[0]
		if not is_instance_valid(node):
			continue
		var d := node.global_position.distance_to(p)
		if d > 35.0:
			continue
		candidates.append([node, entry[1], d, entry[2]])
	if candidates.is_empty():
		_animal_cd = 2.0
		return
	var pick: Array = candidates[randi() % candidates.size()]
	var a := Game.animal(pick[1])
	if a.is_empty():
		return
	var name := Sound.animal_call(a)
	# Al atardecer, algún aullido.
	if a["species"] == "perro" and hour >= 19.5 and randf() < 0.25:
		name = "perro_aullido"
	if name != "":
		var on_street: bool = pick[3]
		Sound.play_at(name, pick[0].global_position + Vector3(0, 0.5, 0), -4.0 if on_street else -8.0, 40.0, 0.08, 2.5)
	# Más animales cerca = más ruido, pero sin agobiar.
	_animal_cd = randf_range(4.0, 9.0) / clampf(sqrt(candidates.size()), 1.0, 3.0)
