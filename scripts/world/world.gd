class_name World
extends Node3D
## El pueblo, el refugio y los animales que hay en la calle.
## Se reconstruye a partir de Game cuando algo cambia.

signal open_panel(kind: String)
signal talk(npc_id: String)
signal prompt_changed(text: String)
signal message(text: String)

## Edificios del pueblo. "depth" es la profundidad de la sala (de la puerta al fondo)
## y "height" la altura de las paredes: sirven para poner el cartel de la fachada.
const PLACES := {
	"clinica": {"name": "Clínica veterinaria", "pos": Vector3(30, 0, -20), "depth": 10.0, "height": 4.0},
	"peluqueria": {"name": "Peluquería canina", "pos": Vector3(-30, 0, -20), "depth": 8.0, "height": 3.6},
	"tienda": {"name": "Tienda de piensos", "pos": Vector3(30, 0, 22), "depth": 10.0, "height": 4.0},
	"ayuntamiento": {"name": "Ayuntamiento · Banco · SEPRONA", "pos": Vector3(-30, 0, 22), "depth": 11.0, "height": 5.0},
}

var player: PlayerController
var _street: Node3D
var _shelter: Node3D
var _street_nodes := {}   # id -> Node3D
var _shelter_sig := ""
var _shelter_animals: Node3D
var _staff_root: Node3D
var _staff_sig := ""
var _visitors_root: Node3D
var _visitors_sig := ""
var _visitor_nodes := {}  # request id -> Npc
var _animals_sig := ""
var _current: Interactable


func _ready() -> void:
	_build_environment()
	_build_town()
	_shelter = Node3D.new()
	_shelter.name = "Refugio"
	add_child(_shelter)
	_shelter_animals = Node3D.new()
	_shelter_animals.name = "AnimalesRefugio"
	add_child(_shelter_animals)
	_staff_root = Node3D.new()
	_staff_root.name = "Personal"
	add_child(_staff_root)
	_visitors_root = Node3D.new()
	_visitors_root.name = "Visitas"
	add_child(_visitors_root)
	_street = Node3D.new()
	_street.name = "Calle"
	add_child(_street)

	player = PlayerController.new()
	player.name = "Jugador"
	add_child(player)
	place_player_at_shelter()

	Game.world_changed.connect(_sync)
	Game.changed.connect(_sync_shelter)
	Game.changed.connect(_sync_shelter_animals)
	Game.changed.connect(_sync_staff)
	Game.changed.connect(_sync_visitors)
	Game.adopted.connect(_on_adopted)
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
		var pos: Vector3 = pl["pos"]
		var building: Node3D
		match key:
			"clinica": building = Interiors.clinic(open_panel.emit, talk.emit)
			"peluqueria": building = Interiors.grooming(open_panel.emit, talk.emit)
			"tienda": building = Interiors.shop(open_panel.emit, talk.emit)
			"ayuntamiento": building = Interiors.town_hall(open_panel.emit, talk.emit)
		building.name = key
		# La puerta (pared -Z local) mira hacia la carretera central (x = 0).
		building.rotation.y = PI / 2 if pos.x > 0 else -PI / 2
		building.position = pos
		add_child(building)
		# Cartel grande en la fachada.
		var front_dist: float = pl["depth"] / 2.0 + 0.3
		var sign_label := Shapes.label(pl["name"].to_upper(), Vector3(0, pl["height"] + 1.0, -front_dist), 64)
		sign_label.pixel_size = 0.02
		building.add_child(sign_label)
		# Felpudo delante de la puerta.
		building.add_child(Shapes.box(Vector3(2.4, 0.04, 1.2), Color(0.45, 0.3, 0.2), Vector3(0, 0.02, -front_dist - 0.6)))


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

	# Caseta principal: se puede entrar.
	var house := Interiors.shelter_house(open_panel.emit,
		func() -> void: message.emit(Game.feed_all()),
		func() -> void: message.emit(Game.clean_all()))
	house.name = "Caseta"
	house.position = HOUSE_POS
	_shelter.add_child(house)
	# Al entrar con animales, se dejan en la caseta.
	var drop := Interactable.create("Dejar en el refugio a los animales que llevas", func() -> void: message.emit(Game.deposit_all()), 2.2)
	drop.position = HOUSE_POS + Vector3(0, 1, -Interiors.SHELTER_D / 2 - 0.8)
	drop.set_meta("only_if_carrying", true)
	_shelter.add_child(drop)

	# Construcciones adicionales en fila a lo largo del terreno.
	var slots_pos := building_slots(half)
	_building_spots.clear()
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
			_building_spots.append({"id": b["id"], "pos": p})


const HOUSE_POS := Vector3(0, 0, 3)
var _building_spots: Array = []


## Huecos para construcciones alrededor de la caseta, según el tamaño del terreno.
func building_slots(half: float) -> Array:
	var out := []
	var inner := half - 4.0
	var side := half - 3.0  # pegado a la valla, sin pisar la caseta
	for z in [inner, -inner + 1.0, 0.0]:
		for x in [-side, side]:
			out.append(Vector3(x, 0, z))
	if half > 12:
		for x in [-inner / 2.0, inner / 2.0]:
			out.append(Vector3(x, 0, inner))
			out.append(Vector3(x, 0, -inner + 1.0))
	return out


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
# Animales dentro del refugio: en los caniles de la caseta y junto a las construcciones
# =====================================================================

func _sync_shelter_animals() -> void:
	var list := Game.sheltered()
	var sig := "%s|%s" % [_shelter_sig, ",".join(PackedStringArray(list.map(func(a: Dictionary) -> String: return "%d:%d" % [a["id"], int(a["hygiene"] < 30)])))]
	if sig == _animals_sig:
		return
	_animals_sig = sig
	for c in _shelter_animals.get_children():
		c.queue_free()
	if Game.s["tier"] == 0:
		return
	# Plazas visibles: 4 caniles en la caseta y luego las de cada construcción con plazas.
	var spots: Array = []
	for i in 4:
		spots.append(HOUSE_POS + Interiors.kennel_pos(i))
	for b in _building_spots:
		var per := 6 if b["id"] == "gatera" else (4 if b["id"] == "caniles" else 0)
		for k in per:
			spots.append(b["pos"] + Vector3(-2.0 + (k % 4) * 1.3, 0.06, 2.6 + (k / 4) * 1.0))
	var half := Game.land_size() / 2.0
	for i in list.size():
		var a: Dictionary = list[i]
		var node := AnimalMesh.build(a)
		node.set_meta("id", a["id"])
		var p: Vector3
		if i < spots.size():
			p = spots[i]
		else:
			# Sobreocupación: animales sueltos por el patio.
			var r := RandomNumberGenerator.new()
			r.seed = a["id"]
			p = Vector3(r.randf_range(-half + 2, half - 2), 0.06, r.randf_range(-half + 2, -2))
		node.position = Game.s["land_pos"] + p
		node.rotation.y = PI  # mirando hacia la entrada
		var info := Interactable.create("%s · %s %s · salud %d · %s" % [a["name"], a["species"], a["size"], a["health"],
			"listo para adopción" if Game.is_adoptable(a) else "falta: " + ", ".join(Game.missing_for_adoption(a))],
			open_panel.emit.bind("refugio"), 1.3)
		info.position.y = 0.5
		node.add_child(info)
		_shelter_animals.add_child(node)


# =====================================================================
# Personal y voluntarios en el refugio
# =====================================================================

const STAFF_LOOKS := {
	"voluntario": {"shirt": Color(0.95, 0.95, 0.95), "vest": Color(0.4, 0.8, 0.3), "pants": Color(0.25, 0.3, 0.45)},
	"cuidador": {"shirt": Color(0.2, 0.55, 0.45), "pants": Color(0.2, 0.3, 0.3)},
	"limpiador": {"shirt": Color(0.3, 0.5, 0.8), "pants": Color(0.3, 0.5, 0.8)},
	"paseador": {"shirt": Color(0.95, 0.6, 0.2), "pants": Color(0.25, 0.25, 0.3), "cap": Color(0.95, 0.6, 0.2)},
	"peluquero": {"shirt": Color(0.9, 0.45, 0.6), "pants": Color(0.2, 0.2, 0.25)},
	"veterinario": {"shirt": Color(0.4, 0.6, 0.75), "coat": Color(0.97, 0.97, 0.97), "pants": Color(0.4, 0.6, 0.75)},
}
const STAFF_ROLE_NAMES := {"voluntario": "voluntario/a", "cuidador": "cuidador/a", "limpiador": "limpieza",
	"paseador": "paseador/a", "peluquero": "peluquero/a", "veterinario": "veterinario/a"}


func _sync_staff() -> void:
	var sig := "%s|%s|%d" % [str(Game.s["staff"]), Game.s["land"], Game.s["tier"]]
	if sig == _staff_sig:
		return
	_staff_sig = sig
	for c in _staff_root.get_children():
		c.queue_free()
	if Game.s["tier"] == 0:
		return
	var half := Game.land_size() / 2.0
	var spots := [Vector3(-3.5, 0.06, -4.5), Vector3(3.5, 0.06, -4.5), Vector3(-7.5, 0.06, -7.0), Vector3(7.5, 0.06, -7.0),
		Vector3(-2.0, 0.06, -8.0), Vector3(2.0, 0.06, -8.0), Vector3(-half + 2.5, 0.06, -2.0), Vector3(half - 2.5, 0.06, -2.0)]
	var i := 0
	var hair := [Color(0.15, 0.1, 0.08), Color(0.55, 0.4, 0.25), Color(0.85, 0.7, 0.4), Color(0.3, 0.2, 0.15), Color(0.6, 0.6, 0.6)]
	for role in STAFF_LOOKS:
		for k in Game.staff_count(role):
			if i >= spots.size():
				return
			var look: Dictionary = STAFF_LOOKS[role].duplicate()
			look["hair"] = hair[(i * 3 + k) % hair.size()]
			look["long_hair"] = (i + k) % 2 == 0
			var nm: String = Dialogues.STAFF_NAMES[(i * 7 + 3) % Dialogues.STAFF_NAMES.size()]
			var n := Npc.create("staff_%s_%d" % [role, k], nm, STAFF_ROLE_NAMES[role], look)
			n.position = Game.s["land_pos"] + spots[i]
			n.rotation.y = 0.0  # mirando hacia la entrada
			n.talked.connect(talk.emit)
			_staff_root.add_child(n)
			i += 1


# =====================================================================
# Familias que vienen a adoptar
# =====================================================================

const VISITOR_SHIRTS := [Color(0.85, 0.3, 0.3), Color(0.3, 0.45, 0.85), Color(0.95, 0.75, 0.25), Color(0.55, 0.35, 0.7),
	Color(0.3, 0.7, 0.5), Color(0.9, 0.5, 0.2), Color(0.4, 0.4, 0.45)]
const VISITOR_HAIR := [Color(0.12, 0.08, 0.05), Color(0.55, 0.4, 0.25), Color(0.85, 0.72, 0.45), Color(0.75, 0.75, 0.75), Color(0.35, 0.2, 0.12)]


func _visitor_look(rq: Dictionary) -> Dictionary:
	var seed: int = rq.get("look", rq["id"])
	var old: bool = "jubilad" in rq["who"]
	return {"shirt": VISITOR_SHIRTS[seed % VISITOR_SHIRTS.size()], "pants": Color(0.2, 0.22, 0.3),
		"hair": Color(0.8, 0.8, 0.8) if old else VISITOR_HAIR[(seed / 7) % VISITOR_HAIR.size()],
		"long_hair": seed % 2 == 0}


func _visitor_spot(i: int) -> Vector3:
	var half := Game.land_size() / 2.0
	return Game.s["land_pos"] + Vector3(-3.0 + i * 3.0, 0.06, -half + 3.0)


func _sync_visitors() -> void:
	var list := Game.visitors()
	var sig := ",".join(PackedStringArray(list.map(func(r: Dictionary) -> String: return str(r["id"]))))
	if sig == _visitors_sig:
		return
	_visitors_sig = sig
	var wanted := {}
	for r in list:
		wanted[r["id"]] = r
	for id in _visitor_nodes.keys():
		if not wanted.has(id):
			_visitor_nodes[id].queue_free()
			_visitor_nodes.erase(id)
	var i := 0
	for id in wanted:
		var rq: Dictionary = wanted[id]
		if not _visitor_nodes.has(id):
			var root := Node3D.new()
			var n := Npc.create("adoptante_%d" % id, rq["who"], "quiere adoptar", _visitor_look(rq))
			n.talked.connect(talk.emit)
			root.add_child(n)
			if "niños" in rq["who"]:
				var kid := Npc.create("adoptante_%d" % id, "", "", {"shirt": Color(0.95, 0.85, 0.2), "pants": Color(0.3, 0.45, 0.8), "hair": _visitor_look(rq)["hair"]})
				kid.scale = Vector3.ONE * 0.6
				kid.position = Vector3(0.8, 0, -0.2)
				kid.talked.connect(talk.emit)
				root.add_child(kid)
			_visitors_root.add_child(root)
			_visitor_nodes[id] = root
		_visitor_nodes[id].global_position = _visitor_spot(i)
		_visitor_nodes[id].rotation.y = PI  # mirando hacia la caseta
		i += 1


## La familia se marcha con su nuevo compañero hacia la salida.
func _on_adopted(rq: Dictionary, a: Dictionary) -> void:
	var start := _visitor_spot(0)
	if _visitor_nodes.has(rq["id"]):
		start = _visitor_nodes[rq["id"]].global_position
		_visitor_nodes[rq["id"]].queue_free()
		_visitor_nodes.erase(rq["id"])
	var group := Node3D.new()
	add_child(group)
	group.global_position = start
	var walker := Npc.create("adoptado_%d" % rq["id"], rq["who"], "", _visitor_look(rq))
	walker.remove_from_group("npc")
	for c in walker.get_children():
		if c is Interactable:
			c.queue_free()
	group.add_child(walker)
	var pet := AnimalMesh.build(a)
	pet.position = Vector3(0.9, 0, -0.6)
	group.add_child(pet)
	var heart := Shapes.label("♥", Vector3(0.9, 1.4, -0.6), 64)
	heart.modulate = Color(1, 0.4, 0.5)
	group.add_child(heart)
	var exit: Vector3 = Game.s["land_pos"] + Vector3(0, 0.06, -Game.land_size() / 2.0 - 30.0)
	group.look_at(Vector3(exit.x, start.y, exit.z), Vector3.UP)
	var tw := create_tween()
	tw.tween_property(group, "global_position", exit, 14.0)
	tw.parallel().tween_property(heart, "position:y", 2.2, 2.0)
	tw.tween_callback(group.queue_free)
	_visitors_sig = ""  # recolocar al resto


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
	var root := AnimalMesh.build(a)

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
	label.no_depth_test = true  # el aviso se ve a través de los edificios
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
		AnimalMesh.animate(_street_nodes[id], t, id)
	for n in _shelter_animals.get_children():
		AnimalMesh.animate(n, t, n.get_meta("id", 0))
	_update_interaction()


func _update_interaction() -> void:
	var best: Interactable = null
	var best_d := INF
	if not player.ui_open:
		var p := player.global_position
		var look := player.look_dir()
		var look2 := Vector2(look.x, look.z).normalized()
		for n in get_tree().get_nodes_in_group("interactable"):
			var it := n as Interactable
			if it == null or not it.is_visible_in_tree():
				continue
			if it.has_meta("only_if_carrying") and Game.carried().is_empty():
				continue
			var to := Vector2(it.global_position.x - p.x, it.global_position.z - p.z)
			var d := to.length()
			if d > it.radius:
				continue
			# Se prefiere lo que tienes delante.
			var facing := look2.dot(to.normalized()) if d > 0.01 else 1.0
			if d > 1.0 and facing < 0.1:
				continue
			var score := d - facing * 1.2
			if score < best_d:
				best = it
				best_d = score
	if best != _current:
		_current = best
		prompt_changed.emit("[E] " + best.prompt if best else "")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact") and _current and not player.ui_open:
		_current.action.call()
		get_viewport().set_input_as_handled()
