class_name Ambience
extends Node3D
## Vida del pueblo: el sol según la hora (mañana, mediodía, atardecer), farolas,
## vecinos que pasean por las aceras y coches que circulan.

signal talk(npc_id: String)

var env: Environment
var sun: DirectionalLight3D
var sky_mat: ProceduralSkyMaterial

var _lamps: Array[OmniLight3D] = []
var _lamp_bulbs: Array[StandardMaterial3D] = []
var _walkers: Array = []   # {node, path, i, speed}
var _cars: Array = []      # {node, path, i, speed, cur}
var _lamps_on := false

const DAY_SKY_TOP := Color(0.35, 0.55, 0.85)
const DAY_SKY_HORIZON := Color(0.75, 0.82, 0.9)
const DUSK_SKY_TOP := Color(0.25, 0.3, 0.55)
const DUSK_SKY_HORIZON := Color(0.98, 0.6, 0.35)
const NIGHT_SKY_TOP := Color(0.04, 0.06, 0.15)
const NIGHT_SKY_HORIZON := Color(0.12, 0.14, 0.25)


func setup(p_env: Environment, p_sun: DirectionalLight3D, p_sky: ProceduralSkyMaterial) -> void:
	env = p_env
	sun = p_sun
	sky_mat = p_sky
	_build_lamps()
	_build_walkers()
	_build_cars()


# =====================================================================
# Sol y cielo
# =====================================================================

func _process(delta: float) -> void:
	_update_sky()
	if Game.paused:
		return
	for w in _walkers:
		_move_walker(w, delta)
	for c in _cars:
		_move_car(c, delta)


func _update_sky() -> void:
	var hour: float = Game.s.get("minute", 12 * 60) / 60.0
	# Sale a las 6:30 y se pone a las 21:00 (con la jornada terminando a esa hora).
	var f := clampf((hour - 6.5) / 14.5, 0.0, 1.0)
	var elevation := sin(f * PI) * 62.0 - 3.0
	sun.rotation_degrees = Vector3(-elevation, -100.0 + f * 200.0, 0)
	var day := clampf(elevation / 32.0, 0.0, 1.0)       # 0 = sol bajo, 1 = pleno día
	var dusk := clampf(1.0 - absf(elevation - 8.0) / 24.0, 0.0, 1.0) * float(hour > 15.0)  # tarde dorada
	sun.light_energy = 0.15 + 0.75 * day
	sun.light_color = Color(1, 0.98, 0.94).lerp(Color(1.0, 0.62, 0.35), dusk * 0.85)
	env.ambient_light_energy = 0.3 + 0.27 * day
	env.ambient_light_color = Color(0.62, 0.66, 0.72).lerp(Color(0.55, 0.5, 0.6), dusk)
	var top := DAY_SKY_TOP.lerp(DUSK_SKY_TOP, dusk)
	var horizon := DAY_SKY_HORIZON.lerp(DUSK_SKY_HORIZON, dusk)
	if elevation < 2.0:
		var night := clampf((2.0 - elevation) / 6.0, 0.0, 1.0)
		top = top.lerp(NIGHT_SKY_TOP, night)
		horizon = horizon.lerp(NIGHT_SKY_HORIZON, night)
	sky_mat.sky_top_color = top
	sky_mat.sky_horizon_color = horizon
	env.fog_light_color = horizon.lerp(top, 0.3)
	var on := hour >= 19.5 or hour < 7.5
	if on != _lamps_on:
		_lamps_on = on
		for l in _lamps:
			l.visible = on
		for m in _lamp_bulbs:
			m.emission_enabled = on


# =====================================================================
# Farolas
# =====================================================================

func _build_lamps() -> void:
	var spots: Array = []
	for z in [-60.0, -30.0, 30.0]:
		spots.append(Vector3(5.5, 0, z))
	for x in [-60.0, -30.0, 30.0, 60.0]:
		spots.append(Vector3(x, 0, -5.5))
	spots.append_array([Vector3(-9, 0, -9), Vector3(9, 0, 9), Vector3(9, 0, -9), Vector3(-9, 0, 9)])
	for p in spots:
		add_child(Shapes.box(Vector3(0.15, 4.5, 0.15), Color(0.2, 0.2, 0.22), p + Vector3(0, 2.25, 0)))
		var bulb := Shapes.box(Vector3(0.5, 0.25, 0.5), Color(1, 0.95, 0.75), p + Vector3(0, 4.55, 0))
		var m := bulb.material_override as StandardMaterial3D
		m.emission = Color(1, 0.85, 0.5)
		m.emission_energy_multiplier = 3.0
		_lamp_bulbs.append(m)
		add_child(bulb)
		var light := OmniLight3D.new()
		light.position = p + Vector3(0, 4.2, 0)
		light.omni_range = 11.0
		light.light_energy = 1.6
		light.light_color = Color(1, 0.85, 0.55)
		light.visible = false
		_lamps.append(light)
		add_child(light)


# =====================================================================
# Vecinos que pasean
# =====================================================================

const NEIGHBOR_NAMES := ["Paqui", "Don Manuel", "Antoñito", "Reme", "Juan Carlos", "Loli", "Pepe", "Charo", "Fran", "Mari Ángeles"]


func _build_walkers() -> void:
	# Recorridos por las aceras: alrededor de la plaza y a lo largo de las calles principales.
	var loops := [
		[Vector3(-11, 0, -11), Vector3(11, 0, -11), Vector3(11, 0, 11), Vector3(-11, 0, 11)],
		[Vector3(5.5, 0, -70), Vector3(5.5, 0, 30), Vector3(-5.5, 0, 30), Vector3(-5.5, 0, -70)],
		[Vector3(-70, 0, 5.5), Vector3(70, 0, 5.5), Vector3(70, 0, -5.5), Vector3(-70, 0, -5.5)],
		[Vector3(-22, 0, -10), Vector3(-22, 0, 30), Vector3(-40, 0, 30), Vector3(-40, 0, -10)],
		[Vector3(22, 0, -32), Vector3(40, 0, -32), Vector3(40, 0, 32), Vector3(22, 0, 32)],
	]
	var r := RandomNumberGenerator.new()
	r.seed = 42
	var shirts := [Color(0.8, 0.3, 0.3), Color(0.3, 0.5, 0.8), Color(0.9, 0.8, 0.3), Color(0.5, 0.35, 0.7), Color(0.35, 0.7, 0.45), Color(0.95, 0.95, 0.95)]
	var hair := [Color(0.12, 0.08, 0.05), Color(0.55, 0.4, 0.25), Color(0.85, 0.72, 0.45), Color(0.8, 0.8, 0.8)]
	for i in 10:
		var path: Array = loops[i % loops.size()]
		var look := {"shirt": shirts[i % shirts.size()], "pants": Color(0.2, 0.22, 0.3).lightened(r.randf() * 0.3),
			"hair": hair[r.randi() % hair.size()], "long_hair": r.randf() < 0.5}
		var n := Npc.create("vecino_%d" % i, NEIGHBOR_NAMES[i], "vecino/a", look)
		n.set_solid(false)
		n.talked.connect(talk.emit)
		var start := r.randi() % path.size()
		n.position = path[start].lerp(path[(start + 1) % path.size()], r.randf())
		add_child(n)
		_walkers.append({"node": n, "path": path if i % 2 == 0 else _reversed(path), "i": (start + 1) % path.size(), "speed": r.randf_range(1.1, 1.6), "pause": 0.0})


func _reversed(a: Array) -> Array:
	var b := a.duplicate()
	b.reverse()
	return b


func _move_walker(w: Dictionary, delta: float) -> void:
	var n: Npc = w["node"]
	# Se paran a hablar si el jugador está muy cerca.
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if player and n.global_position.distance_to(player.global_position) < 2.2:
		n.walking = false
		return
	if w["pause"] > 0.0:
		w["pause"] -= delta
		n.walking = false
		return
	var target: Vector3 = w["path"][w["i"]]
	var to := target - n.position
	to.y = 0
	if to.length() < 0.2:
		w["i"] = (w["i"] + 1) % w["path"].size()
		if randf() < 0.3:
			w["pause"] = randf_range(2.0, 6.0)  # se paran un rato en la esquina
		return
	n.walking = true
	var step: Vector3 = to.normalized() * w["speed"] * delta
	n.position += step if step.length() < to.length() else to
	n.rotation.y = lerp_angle(n.rotation.y, atan2(-to.x, -to.z), clampf(delta * 8.0, 0.0, 1.0))


# =====================================================================
# Coches
# =====================================================================

func _build_cars() -> void:
	# Carril derecho: anillo exterior en un sentido y la carretera principal norte-sur ida y vuelta.
	var ring := [Vector3(108.5, 0, -108.5), Vector3(108.5, 0, 108.5), Vector3(-108.5, 0, 108.5), Vector3(-108.5, 0, -108.5)]
	var ring_in := [Vector3(-111.5, 0, -111.5), Vector3(-111.5, 0, 111.5), Vector3(111.5, 0, 111.5), Vector3(111.5, 0, -111.5)]
	var north_south := [Vector3(-2, 0, -150), Vector3(-2, 0, 30), Vector3(2, 0, 30), Vector3(2, 0, -150)]
	var east_west := [Vector3(-150, 0, 2), Vector3(150, 0, 2), Vector3(150, 0, -2), Vector3(-150, 0, -2)]
	var colors := [Color(0.8, 0.15, 0.15), Color(0.2, 0.35, 0.75), Color(0.9, 0.9, 0.9), Color(0.15, 0.15, 0.17), Color(0.95, 0.75, 0.2), Color(0.3, 0.55, 0.35)]
	var plan := [[ring, 0], [ring, 2], [ring_in, 1], [north_south, 0], [north_south, 2], [east_west, 1]]
	for k in plan.size():
		var path: Array = plan[k][0]
		var start: int = plan[k][1]
		var car := _make_car(colors[k % colors.size()])
		car.position = path[start]
		add_child(car)
		_cars.append({"node": car, "path": path, "i": (start + 1) % path.size(), "speed": randf_range(9.0, 12.0), "cur": 0.0})


func _make_car(color: Color) -> Node3D:
	var car := AnimatableBody3D.new()
	car.sync_to_physics = false
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.8, 1.4, 4.0)
	col.shape = shape
	col.position.y = 0.8
	car.add_child(col)
	car.add_child(Shapes.box(Vector3(1.8, 0.8, 4.0), color, Vector3(0, 0.6, 0)))
	car.add_child(Shapes.box(Vector3(1.6, 0.6, 2.0), Color(0.45, 0.6, 0.75), Vector3(0, 1.3, 0.2)))
	for x in [-0.85, 0.85]:
		for z in [-1.3, 1.3]:
			var w := Shapes.cylinder(0.35, 0.25, Color(0.1, 0.1, 0.1), Vector3(x, 0.35, z))
			w.rotation.z = PI / 2
			car.add_child(w)
	# Faros.
	for x in [-0.6, 0.6]:
		car.add_child(Shapes.box(Vector3(0.35, 0.18, 0.05), Color(1, 1, 0.85), Vector3(x, 0.7, -2.02)))
		car.add_child(Shapes.box(Vector3(0.35, 0.15, 0.05), Color(0.8, 0.1, 0.1), Vector3(x, 0.7, 2.02)))
	return car


func _move_car(c: Dictionary, delta: float) -> void:
	var car: Node3D = c["node"]
	var target: Vector3 = c["path"][c["i"]]
	var to := target - car.position
	to.y = 0
	if to.length() < 0.5:
		c["i"] = (c["i"] + 1) % c["path"].size()
		return
	var dir := to.normalized()
	# Frena si el jugador (o un coche) está delante.
	var want: float = c["speed"]
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if player:
		var rel := player.global_position - car.position
		rel.y = 0
		if rel.length() < 9.0 and dir.dot(rel.normalized()) > 0.8:
			want = 0.0
	for other in _cars:
		if other == c:
			continue
		var rel2: Vector3 = other["node"].position - car.position
		if rel2.length() < 8.0 and dir.dot(rel2.normalized()) > 0.9:
			want = 0.0
	c["cur"] = move_toward(c["cur"], want, delta * (14.0 if want < c["cur"] else 5.0))
	var step: Vector3 = dir * c["cur"] * delta
	car.position += step if step.length() < to.length() else to
	car.rotation.y = lerp_angle(car.rotation.y, atan2(-dir.x, -dir.z), clampf(delta * 4.0, 0.0, 1.0))
