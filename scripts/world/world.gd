class_name World
extends Node3D
## El pueblo, el refugio y los animales que hay en la calle.
## Se reconstruye a partir de Game cuando algo cambia.

signal open_panel(kind: String)
signal prompt_changed(text: String)
signal message(text: String)

const PLACES := {
	"clinica": {"name": "Clínica veterinaria", "pos": Vector3(30, 0, -20), "color": Color(0.85, 0.95, 1.0), "size": Vector3(12, 5, 9)},
	"peluqueria": {"name": "Peluquería canina", "pos": Vector3(-30, 0, -20), "color": Color(1.0, 0.85, 0.9), "size": Vector3(9, 4, 8)},
	"tienda": {"name": "Tienda de piensos", "pos": Vector3(30, 0, 22), "color": Color(0.95, 0.9, 0.7), "size": Vector3(11, 4.5, 9)},
	"ayuntamiento": {"name": "Ayuntamiento · Banco · SEPRONA", "pos": Vector3(-30, 0, 22), "color": Color(0.9, 0.85, 0.75), "size": Vector3(14, 7, 10)},
}

var player: PlayerController
var _street: Node3D
var _shelter: Node3D
var _street_nodes := {}   # id -> Node3D
var _shelter_sig := ""
var _current: Interactable


func _ready() -> void:
	_build_environment()
	_build_town()
	_shelter = Node3D.new()
	_shelter.name = "Refugio"
	add_child(_shelter)
	_street = Node3D.new()
	_street.name = "Calle"
	add_child(_street)

	player = PlayerController.new()
	player.name = "Jugador"
	add_child(player)
	place_player_at_shelter()

	Game.world_changed.connect(_sync)
	Game.changed.connect(_sync_shelter)
	_sync()


func place_player_at_shelter() -> void:
	player.global_position = Game.s["land_pos"] + Vector3(0, 0.2, -14)


# =====================================================================
# Escenario
# =====================================================================

func _build_environment() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	var sky := Sky.new()
	var mat := ProceduralSkyMaterial.new()
	mat.sky_top_color = Color(0.35, 0.55, 0.85)
	mat.sky_horizon_color = Color(0.75, 0.82, 0.9)
	mat.ground_horizon_color = Color(0.6, 0.65, 0.6)
	sky.sky_material = mat
	e.background_mode = Environment.BG_SKY
	e.sky = sky
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.62, 0.66, 0.72)
	e.ambient_light_energy = 0.55
	e.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	# Niebla de profundidad solo a lo lejos.
	e.fog_enabled = true
	e.fog_mode = Environment.FOG_MODE_DEPTH
	e.fog_depth_begin = 120.0
	e.fog_depth_end = 320.0
	e.fog_density = 0.6
	e.fog_light_color = Color(0.78, 0.84, 0.9)
	env.environment = e
	add_child(env)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -30, 0)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 120
	sun.light_energy = 0.85
	add_child(sun)

	add_child(Shapes.wall(Vector3(340, 1, 340), Vector3(0, -0.5, 0), Color(0.45, 0.62, 0.32)))
	# Carreteras principales en cruz y anillo.
	var road := Color(0.3, 0.3, 0.32)
	add_child(Shapes.box(Vector3(8, 0.05, 320), road, Vector3(0, 0.02, 0)))
	add_child(Shapes.box(Vector3(320, 0.05, 8), road, Vector3(0, 0.02, 0)))
	for z in [-110.0, 110.0]:
		add_child(Shapes.box(Vector3(240, 0.05, 6), road, Vector3(0, 0.02, z)))
	for x in [-110.0, 110.0]:
		add_child(Shapes.box(Vector3(6, 0.05, 240), road, Vector3(x, 0.02, 0)))
	# Plaza.
	add_child(Shapes.box(Vector3(20, 0.06, 20), Color(0.82, 0.78, 0.68), Vector3(0, 0.03, 0)))
	add_child(Shapes.cylinder(1.5, 1.0, Color(0.7, 0.7, 0.72), Vector3(0, 0.5, 0)))
	# Río al suroeste.
	add_child(Shapes.box(Vector3(14, 0.04, 260), Color(0.3, 0.5, 0.75), Vector3(-80, 0.03, 60)))
	# Pinar al sureste.
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 70:
		var p := Vector3(rng.randf_range(60, 140), 0, rng.randf_range(70, 140))
		if p.distance_to(Vector3(85, 0, 95)) < 8:
			continue
		_tree(p, rng)
	# Casas del pueblo (decoración).
	for i in 26:
		var p := Vector3(rng.randf_range(-70, 70), 0, rng.randf_range(-70, 45))
		if absf(p.x) < 9 or absf(p.z) < 9 or _near_place(p, 16):
			continue
		var h := rng.randf_range(4, 8)
		add_child(Shapes.wall(Vector3(rng.randf_range(6, 10), h, rng.randf_range(6, 10)), p + Vector3(0, h / 2, 0),
			Color.from_hsv(rng.randf_range(0.05, 0.12), 0.15, rng.randf_range(0.8, 0.95))))
	# Lugares de los avisos: carteles.
	for spot in Game.SPOTS:
		if spot["name"] == "Plaza del pueblo":
			continue
		add_child(Shapes.box(Vector3(0.15, 2.2, 0.15), Color(0.4, 0.3, 0.2), spot["pos"] + Vector3(6, 1.1, 6)))
		var l := Shapes.label(spot["name"], spot["pos"] + Vector3(6, 2.8, 6), 40)
		l.pixel_size = 0.012
		add_child(l)


func _tree(p: Vector3, rng: RandomNumberGenerator) -> void:
	var h := rng.randf_range(4, 7)
	add_child(Shapes.wall(Vector3(0.5, h, 0.5), p + Vector3(0, h / 2, 0), Color(0.4, 0.28, 0.15)))
	add_child(Shapes.cylinder(rng.randf_range(1.5, 2.3), 3.0, Color(0.2, 0.42, 0.22), p + Vector3(0, h + 0.5, 0)))


func _near_place(p: Vector3, r: float) -> bool:
	for k in PLACES:
		if p.distance_to(PLACES[k]["pos"]) < r:
			return true
	return false


func _build_town() -> void:
	for key: String in PLACES:
		var pl: Dictionary = PLACES[key]
		var size: Vector3 = pl["size"]
		var pos: Vector3 = pl["pos"]
		add_child(Shapes.wall(size, pos + Vector3(0, size.y / 2, 0), pl["color"]))
		# Fachada hacia la carretera principal (x = 0).
		var front := Vector3(-signf(pos.x) * (size.x / 2 + 0.05), 0, 0)
		add_child(Shapes.box(Vector3(0.1, 2.4, 1.6), Color(0.35, 0.25, 0.18), pos + front + Vector3(0, 1.2, 0)))
		var sign_label := Shapes.label(pl["name"].to_upper(), pos + front * 1.05 + Vector3(0, size.y + 1.2, 0), 64)
		sign_label.pixel_size = 0.02
		add_child(sign_label)
		var door := Interactable.create("Entrar en: " + pl["name"], open_panel.emit.bind(key), 3.5)
		door.position = pos + front * 1.15 + Vector3(0, 1, 0)
		add_child(door)


# =====================================================================
# Refugio (crece con el terreno y las construcciones)
# =====================================================================

func _sync_shelter() -> void:
	var sig := "%s|%d|%s" % [Game.s["land"], Game.s["tier"], str(Game.s["buildings"])]
	if sig == _shelter_sig:
		return
	_shelter_sig = sig
	for c in _shelter.get_children():
		c.queue_free()
	var base: Vector3 = Game.s["land_pos"]
	_shelter.position = base
	if Game.s["land"] == "":
		return
	var size := float(Game.land_size())
	var half := size / 2.0
	_shelter.add_child(Shapes.box(Vector3(size, 0.05, size), Color(0.7, 0.62, 0.45), Vector3(0, 0.03, 0)))
	var fence_h := 1.8 if Game.has_building("vallado") else 1.0
	var fc := Color(0.45, 0.45, 0.48) if Game.has_building("vallado") else Color(0.55, 0.4, 0.25)
	_shelter.add_child(Shapes.wall(Vector3(size, fence_h, 0.2), Vector3(0, fence_h / 2, half), fc))
	_shelter.add_child(Shapes.wall(Vector3(0.2, fence_h, size), Vector3(-half, fence_h / 2, 0), fc))
	_shelter.add_child(Shapes.wall(Vector3(0.2, fence_h, size), Vector3(half, fence_h / 2, 0), fc))
	var seg := half - 2.5
	_shelter.add_child(Shapes.wall(Vector3(seg, fence_h, 0.2), Vector3(-(2.5 + seg / 2), fence_h / 2, -half), fc))
	_shelter.add_child(Shapes.wall(Vector3(seg, fence_h, 0.2), Vector3(2.5 + seg / 2, fence_h / 2, -half), fc))
	var title := Shapes.label(Game.s["name"].to_upper(), Vector3(0, 3.6, -half), 72)
	title.pixel_size = 0.015
	_shelter.add_child(title)

	if Game.s["tier"] == 0:
		var sign_l := Shapes.label("Terreno comprado · pendiente de construir", Vector3(0, 2, 0), 48)
		_shelter.add_child(sign_l)
		return

	# Caseta principal.
	_shelter.add_child(Shapes.wall(Vector3(8, 3, 5), Vector3(0, 1.5, 2), Color(0.85, 0.8, 0.7)))
	_shelter.add_child(Shapes.box(Vector3(8.6, 0.3, 5.6), Color(0.6, 0.25, 0.2), Vector3(0, 3.15, 2)))
	var door := Interactable.create("Refugio: dejar / sacar animales, cuidar, dormir", open_panel.emit.bind("refugio"), 3.0)
	door.position = Vector3(0, 1, -0.7)
	_shelter.add_child(door)
	_shelter.add_child(Shapes.box(Vector3(1.4, 2.2, 0.1), Color(0.35, 0.25, 0.18), Vector3(0, 1.1, -0.52)))

	# Construcciones adicionales en fila a lo largo del terreno.
	var slots_pos := [Vector3(-half + 4, 0, half - 4), Vector3(half - 4, 0, half - 4), Vector3(-half + 4, 0, 2),
		Vector3(half - 4, 0, 2), Vector3(-half + 4, 0, -half + 5), Vector3(half - 4, 0, -half + 5),
		Vector3(-half / 2, 0, half - 4), Vector3(half / 2, 0, half - 4), Vector3(-half / 2, 0, -half + 5),
		Vector3(half / 2, 0, -half + 5)]
	var i := 0
	for b in Catalog.BUILDINGS:
		var n: int = Game.s["buildings"].get(b["id"], 0)
		if b["id"] == "vallado" or n == 0:
			continue
		for k in n:
			if i >= slots_pos.size():
				break
			var p: Vector3 = slots_pos[i]
			i += 1
			_building_visual(b["id"], p)


func _building_visual(id: String, p: Vector3) -> void:
	var colors := {"caniles": Color(0.7, 0.7, 0.72), "limpieza": Color(0.6, 0.85, 0.95), "cuarentena": Color(0.95, 0.9, 0.5),
		"gatera": Color(0.95, 0.75, 0.6), "patio": Color(0.4, 0.75, 0.35), "consulta": Color(0.95, 0.97, 1.0),
		"almacen": Color(0.6, 0.5, 0.4), "quirofano": Color(0.85, 0.95, 0.9), "placas": Color(0.2, 0.25, 0.45)}
	var names := {"caniles": "Caniles", "limpieza": "Limpieza", "cuarentena": "Cuarentena", "gatera": "Gatera",
		"patio": "Patio de paseo", "consulta": "Consulta veterinaria", "almacen": "Almacén", "quirofano": "Quirófano", "placas": "Placas solares"}
	var c: Color = colors.get(id, Color.WHITE)
	match id:
		"patio":
			_shelter.add_child(Shapes.box(Vector3(6, 0.08, 6), c, p + Vector3(0, 0.05, 0)))
		"placas":
			var panel := Shapes.box(Vector3(5, 0.1, 3), c, p + Vector3(0, 1.2, 0))
			panel.rotation_degrees.x = -25
			_shelter.add_child(panel)
		"caniles":
			_shelter.add_child(Shapes.wall(Vector3(5, 1.6, 3), p + Vector3(0, 0.8, 0), c))
			_shelter.add_child(Shapes.box(Vector3(5.2, 0.15, 3.2), Color(0.4, 0.4, 0.42), p + Vector3(0, 1.7, 0)))
		_:
			_shelter.add_child(Shapes.wall(Vector3(5, 2.6, 4), p + Vector3(0, 1.3, 0), c))
	var bl := Shapes.label(names.get(id, id), p + Vector3(0, 3.4, 0), 44)
	bl.pixel_size = 0.012
	_shelter.add_child(bl)


# =====================================================================
# Animales en la calle y escapados
# =====================================================================

func _sync() -> void:
	_sync_shelter()
	var wanted := {}
	for a in Game.s["animals"]:
		if a["location"] in ["calle", "escapado"]:
			wanted[a["id"]] = a
	for id in _street_nodes.keys():
		if not wanted.has(id):
			_street_nodes[id].queue_free()
			_street_nodes.erase(id)
	for id in wanted:
		var a: Dictionary = wanted[id]
		var node: Node3D = _street_nodes.get(id)
		if node == null:
			node = _make_street_animal(a)
			_street.add_child(node)
			_street_nodes[id] = node
		node.global_position = a["pos"]
		var beacon: Node3D = node.get_meta("beacon")
		var escaped: bool = a["location"] == "escapado"
		# El marcador de un escapado está en la última señal recibida, no en su posición real.
		beacon.global_position = (a.get("seen_pos", a["pos"]) if escaped else a["pos"]) + Vector3(0, 0, 0)
		var label: Label3D = beacon.get_meta("label")
		if escaped:
			label.text = "📡 %s (señal %s)" % [a["name"], "continua" if Game.has_equipment("rastreador") else "de las " + str(a.get("seen_at", "?"))]
			label.modulate = Color(1, 0.6, 0.2)
		else:
			label.text = "⚠ AVISO: %s" % a["origin"]
			label.modulate = Color(1, 0.35, 0.3)


func _make_street_animal(a: Dictionary) -> Node3D:
	var root := Node3D.new()
	var s := 1.3 if a["size"] == "grande" else (1.0 if a["size"] == "mediano" else 0.75)
	if a["species"] == "gato":
		s = 0.6
	var coat := Color.from_hsv(randf_range(0.05, 0.12), randf_range(0.2, 0.6), randf_range(0.35, 0.9))
	var vis := Node3D.new()
	vis.scale = Vector3.ONE * s
	root.add_child(vis)
	vis.add_child(Shapes.box(Vector3(0.5, 0.42, 0.85), coat, Vector3(0, 0.45, 0)))
	vis.add_child(Shapes.box(Vector3(0.38, 0.36, 0.36), coat, Vector3(0, 0.75, -0.5)))
	vis.add_child(Shapes.box(Vector3(0.1, 0.1, 0.1), Color(0.1, 0.1, 0.1), Vector3(0, 0.72, -0.7)))
	var ear_h := 0.22 if a["species"] == "gato" else 0.16
	for x in [-0.12, 0.12]:
		vis.add_child(Shapes.box(Vector3(0.09, ear_h, 0.07), coat.darkened(0.3), Vector3(x, 0.98, -0.48)))
		for z in [-0.28, 0.28]:
			vis.add_child(Shapes.box(Vector3(0.11, 0.25, 0.11), coat.darkened(0.15), Vector3(x * 1.4, 0.12, z)))
	vis.add_child(Shapes.box(Vector3(0.07, 0.07, 0.35), coat.darkened(0.2), Vector3(0, 0.62, 0.55)))
	if a["injured"]:
		vis.add_child(Shapes.box(Vector3(0.14, 0.14, 0.14), Color(0.8, 0.1, 0.1), Vector3(0.2, 0.25, 0.28)))
	root.set_meta("vis", vis)

	var info := Interactable.create("", _on_pick.bind(a["id"]), 2.6)
	info.prompt = "Recoger a %s (%s %s%s)" % [a["name"], a["species"], a["size"], ", herido" if a["injured"] else ""]
	info.position.y = 0.5
	root.add_child(info)

	var beacon := Node3D.new()
	root.add_child(beacon)
	beacon.top_level = true
	var pillar := Shapes.cylinder(0.25, 30.0, Color(1, 0.4, 0.2), Vector3(0, 15, 0))
	var m := pillar.material_override as StandardMaterial3D
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(1, 0.45, 0.2, 0.35)
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	beacon.add_child(pillar)
	var label := Shapes.label("", Vector3(0, 6, 0), 40)
	label.fixed_size = true
	label.pixel_size = 0.0012
	beacon.add_child(label)
	beacon.set_meta("label", label)
	root.set_meta("beacon", beacon)
	return root


func _on_pick(id: int) -> void:
	message.emit(Game.pick_up(id))


# =====================================================================
# Interacción
# =====================================================================

func _process(delta: float) -> void:
	# Animalitos de la calle: pequeño movimiento para que parezcan vivos.
	var t := Time.get_ticks_msec() * 0.001
	for id in _street_nodes:
		var vis: Node3D = _street_nodes[id].get_meta("vis")
		vis.rotation.y = sin(t * 0.7 + id) * 0.8
		vis.position.y = absf(sin(t * 3.0 + id)) * 0.05
	_update_interaction()


func _update_interaction() -> void:
	var best: Interactable = null
	var best_d := INF
	if not player.ui_open:
		var p := player.global_position
		for n in get_tree().get_nodes_in_group("interactable"):
			var it := n as Interactable
			if it == null or not it.is_visible_in_tree():
				continue
			var d := Vector2(it.global_position.x - p.x, it.global_position.z - p.z).length()
			if d < it.radius and d < best_d:
				best = it
				best_d = d
	if best != _current:
		_current = best
		prompt_changed.emit("[E] " + best.prompt if best else "")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact") and _current and not player.ui_open:
		_current.action.call()
		get_viewport().set_input_as_handled()
