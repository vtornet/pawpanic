class_name Interiors
extends RefCounted
## Edificios huecos por los que se puede entrar, con mobiliario interactivo.
## Cada edificio se construye en coordenadas locales con la puerta en la pared -Z,
## y luego se gira para que la puerta mire a la carretera.

const WALL := 0.3
const DOOR_W := 2.4
const DOOR_H := 2.7


## Habitación con cuatro paredes, puerta en -Z, suelo, techo y luz interior.
static func room(width: float, depth: float, height: float, wall_color: Color, floor_color: Color, roof_color: Color) -> Node3D:
	var r := Node3D.new()
	var hw := width / 2.0
	var hd := depth / 2.0
	# Suelo interior.
	r.add_child(Shapes.box(Vector3(width, 0.06, depth), floor_color, Vector3(0, 0.03, 0)))
	# Paredes laterales y trasera.
	r.add_child(Shapes.wall(Vector3(WALL, height, depth), Vector3(-hw, height / 2, 0), wall_color))
	r.add_child(Shapes.wall(Vector3(WALL, height, depth), Vector3(hw, height / 2, 0), wall_color))
	r.add_child(Shapes.wall(Vector3(width, height, WALL), Vector3(0, height / 2, hd), wall_color))
	# Pared delantera con hueco de puerta.
	var side := (width - DOOR_W) / 2.0
	r.add_child(Shapes.wall(Vector3(side, height, WALL), Vector3(-(DOOR_W / 2 + side / 2), height / 2, -hd), wall_color))
	r.add_child(Shapes.wall(Vector3(side, height, WALL), Vector3(DOOR_W / 2 + side / 2, height / 2, -hd), wall_color))
	r.add_child(Shapes.wall(Vector3(DOOR_W, height - DOOR_H, WALL), Vector3(0, DOOR_H + (height - DOOR_H) / 2, -hd), wall_color))
	# Marco de la puerta.
	var frame := wall_color.darkened(0.45)
	r.add_child(Shapes.box(Vector3(0.12, DOOR_H, WALL + 0.06), frame, Vector3(-DOOR_W / 2, DOOR_H / 2, -hd)))
	r.add_child(Shapes.box(Vector3(0.12, DOOR_H, WALL + 0.06), frame, Vector3(DOOR_W / 2, DOOR_H / 2, -hd)))
	r.add_child(Shapes.box(Vector3(DOOR_W + 0.12, 0.12, WALL + 0.06), frame, Vector3(0, DOOR_H, -hd)))
	# Ventanas (decorativas) en la fachada.
	for x in [-(DOOR_W / 2 + side / 2), DOOR_W / 2 + side / 2]:
		if side > 1.6:
			r.add_child(Shapes.box(Vector3(minf(side - 0.8, 2.2), 1.1, WALL + 0.04), Color(0.55, 0.75, 0.9), Vector3(x, 1.7, -hd)))
	# Techo.
	r.add_child(Shapes.wall(Vector3(width + 0.6, 0.25, depth + 0.6), Vector3(0, height + 0.12, 0), roof_color))
	# Luz interior.
	var light := OmniLight3D.new()
	light.position = Vector3(0, height - 0.5, 0)
	light.omni_range = maxf(width, depth) * 0.9
	light.light_energy = 1.4
	light.light_color = Color(1.0, 0.95, 0.85)
	light.shadow_enabled = false
	r.add_child(light)
	# Lámpara visible.
	r.add_child(Shapes.box(Vector3(1.2, 0.08, 0.4), Color(1, 1, 0.9), Vector3(0, height - 0.08, 0)))
	return r


static func _interact(parent: Node3D, prompt: String, action: Callable, pos: Vector3, radius: float = 1.9) -> void:
	var i := Interactable.create(prompt, action, radius)
	i.position = pos
	parent.add_child(i)


## Cartel fijo en la pared. Por defecto mira hacia la puerta (-Z);
## con toward_door = false mira hacia el fondo (para carteles en la pared de la entrada).
## Coloca a un personaje (mirando hacia la puerta) y conecta su conversación.
static func _person(parent: Node3D, id: String, look: Dictionary, pos: Vector3, talk: Callable) -> void:
	var info: Dictionary = Dialogues.PEOPLE[id]
	var n := Npc.create(id, info["name"], info["role"], look)
	n.position = pos
	n.talked.connect(talk)
	parent.add_child(n)


static func _sign(parent: Node3D, text: String, pos: Vector3, px: float = 0.008, toward_door: bool = true) -> void:
	var l := Shapes.label(text, pos, 40)
	l.pixel_size = px
	l.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	l.double_sided = false
	l.rotation.y = PI if toward_door else 0.0
	parent.add_child(l)


# ---------------------------------------------------------------------
# Clínica veterinaria
# ---------------------------------------------------------------------
static func clinic(open: Callable, talk: Callable) -> Node3D:
	var w := 13.0
	var d := 10.0
	var r := room(w, d, 4.0, Color(0.88, 0.95, 1.0), Color(0.85, 0.88, 0.9), Color(0.35, 0.5, 0.6))
	var steel := Color(0.75, 0.78, 0.8)
	var green := Color(0.3, 0.6, 0.55)
	# Recepción a la derecha de la entrada.
	r.add_child(Shapes.wall(Vector3(3.2, 1.1, 0.7), Vector3(3.2, 0.55, -2.2), Color(0.95, 0.95, 0.97)))
	r.add_child(Shapes.box(Vector3(3.3, 0.06, 0.8), green, Vector3(3.2, 1.13, -2.2)))
	r.add_child(Shapes.box(Vector3(0.5, 0.35, 0.05), Color(0.1, 0.1, 0.12), Vector3(3.6, 1.35, -2.0)))  # monitor
	_sign(r, "RECEPCIÓN", Vector3(3.2, 2.3, -1.9))
	_person(r, "recepcion", {"shirt": Color(0.3, 0.6, 0.55), "pants": Color(0.25, 0.25, 0.3), "hair": Color(0.15, 0.1, 0.08), "long_hair": true}, Vector3(3.2, 0.06, -1.3), talk)
	# Sala de espera a la izquierda.
	for x in [-5.0, -4.2, -3.4]:
		r.add_child(Shapes.box(Vector3(0.6, 0.45, 0.6), green, Vector3(x, 0.23, -3.8)))
		r.add_child(Shapes.box(Vector3(0.6, 0.5, 0.1), green, Vector3(x, 0.7, -4.05)))
	_sign(r, "SALA DE ESPERA", Vector3(-4.2, 2.3, -4.75), 0.006, false)
	# Consulta al fondo: mesa de exploración, armario de medicamentos, báscula.
	r.add_child(Shapes.wall(Vector3(0.15, 3.0, 4.0), Vector3(-0.5, 1.5, 3.0), Color(0.8, 0.9, 0.95)))  # tabique
	r.add_child(Shapes.wall(Vector3(2.0, 0.9, 0.9), Vector3(-3.5, 0.45, 2.6), steel))
	r.add_child(Shapes.box(Vector3(2.05, 0.05, 0.95), Color(0.9, 0.92, 0.95), Vector3(-3.5, 0.92, 2.6)))
	_sign(r, "CONSULTA", Vector3(-3.5, 2.6, 4.7))
	_person(r, "veterinaria", {"shirt": Color(0.4, 0.6, 0.75), "coat": Color(0.97, 0.97, 0.97), "pants": Color(0.4, 0.6, 0.75), "hair": Color(0.55, 0.4, 0.25), "long_hair": true}, Vector3(-2.0, 0.06, 3.1), talk)
	r.add_child(Shapes.wall(Vector3(2.4, 2.2, 0.5), Vector3(-4.5, 1.1, 4.6), Color(0.95, 0.95, 0.95)))  # armario
	for i in 3:
		r.add_child(Shapes.box(Vector3(2.2, 0.04, 0.3), Color(0.7, 0.85, 0.95), Vector3(-4.5, 0.6 + i * 0.6, 4.3)))
	r.add_child(Shapes.box(Vector3(0.9, 0.08, 0.6), steel, Vector3(-1.5, 0.04, 1.2)))  # báscula
	# Quirófano / hospitalización a la derecha del fondo.
	r.add_child(Shapes.wall(Vector3(2.2, 0.95, 1.0), Vector3(3.5, 0.48, 3.0), steel))
	r.add_child(Shapes.cylinder(0.5, 0.1, Color(1, 1, 0.9), Vector3(3.5, 3.4, 3.0)))  # foco
	for i in 3:
		r.add_child(Shapes.wall(Vector3(1.0, 0.8, 0.8), Vector3(1.4 + i * 1.1, 0.4, 4.5), Color(0.85, 0.85, 0.88)))  # jaulas de hospitalización
	_sign(r, "HOSPITALIZACIÓN", Vector3(2.5, 2.6, 4.7), 0.006)
	return r


# ---------------------------------------------------------------------
# Peluquería canina
# ---------------------------------------------------------------------
static func grooming(open: Callable, talk: Callable) -> Node3D:
	var r := room(10.0, 8.0, 3.6, Color(1.0, 0.88, 0.92), Color(0.92, 0.92, 0.9), Color(0.6, 0.35, 0.45))
	# Bañera.
	r.add_child(Shapes.wall(Vector3(2.2, 0.9, 1.1), Vector3(-2.5, 0.45, 2.6), Color(0.95, 0.95, 0.97)))
	r.add_child(Shapes.box(Vector3(1.9, 0.05, 0.8), Color(0.45, 0.7, 0.95), Vector3(-2.5, 0.92, 2.6)))
	r.add_child(Shapes.box(Vector3(0.08, 0.8, 0.08), Color(0.7, 0.7, 0.72), Vector3(-2.5, 1.4, 3.2)))  # grifo
	_sign(r, "BAÑO", Vector3(-2.5, 2.3, 3.8))
	_interact(r, "Bañera: baño y desparasitación", open.bind("peluqueria"), Vector3(-2.5, 1, 1.6))
	# Mesa de corte y secador.
	r.add_child(Shapes.wall(Vector3(1.6, 0.85, 0.8), Vector3(2.3, 0.43, 2.4), Color(0.6, 0.6, 0.65)))
	r.add_child(Shapes.box(Vector3(0.1, 1.6, 0.1), Color(0.3, 0.3, 0.3), Vector3(3.3, 1.65, 2.6)))
	r.add_child(Shapes.box(Vector3(0.6, 0.25, 0.25), Color(0.9, 0.4, 0.55), Vector3(3.0, 2.4, 2.6)))
	_person(r, "peluquera", {"shirt": Color(0.9, 0.45, 0.6), "vest": Color(0.25, 0.25, 0.3), "pants": Color(0.15, 0.15, 0.2), "hair": Color(0.7, 0.2, 0.25), "long_hair": true}, Vector3(1.0, 0.06, 2.9), talk)
	# Mostrador.
	r.add_child(Shapes.wall(Vector3(2.4, 1.05, 0.6), Vector3(2.8, 0.53, -2.4), Color(0.95, 0.8, 0.85)))
	_interact(r, "Mostrador de la peluquería", open.bind("peluqueria"), Vector3(2.8, 1, -3.2))
	# Estantería de champús.
	r.add_child(Shapes.wall(Vector3(0.4, 2.0, 2.4), Vector3(-4.7, 1.0, -1.0), Color(0.85, 0.85, 0.85)))
	for i in 6:
		r.add_child(Shapes.cylinder(0.1, 0.3, Color.from_hsv(i / 6.0, 0.5, 0.95), Vector3(-4.45, 1.2 + (i % 2) * 0.5, -1.9 + i * 0.35)))
	return r


# ---------------------------------------------------------------------
# Tienda de piensos y limpieza
# ---------------------------------------------------------------------
static func shop(open: Callable, talk: Callable) -> Node3D:
	var r := room(12.0, 10.0, 4.0, Color(0.96, 0.92, 0.78), Color(0.75, 0.68, 0.55), Color(0.55, 0.3, 0.2))
	var wood := Color(0.55, 0.4, 0.25)
	# Estanterías con sacos y productos.
	for row in 3:
		var x := -4.0 + row * 3.0
		r.add_child(Shapes.wall(Vector3(0.8, 2.2, 4.5), Vector3(x, 1.1, 2.0), wood))
		for k in 5:
			for lvl in 2:
				var c: Color = [Color(0.85, 0.3, 0.2), Color(0.2, 0.5, 0.8), Color(0.9, 0.75, 0.3), Color(0.3, 0.65, 0.35)][(row + k + lvl) % 4]
				for side in [-1.0, 1.0]:
					r.add_child(Shapes.box(Vector3(0.25, 0.55, 0.7), c, Vector3(x + side * 0.53, 0.5 + lvl * 0.9, 0.2 + k * 0.85)))
	_sign(r, "PIENSOS", Vector3(-4.0, 2.8, 2.0))
	_sign(r, "HIGIENE Y LIMPIEZA", Vector3(-1.0, 2.8, 2.0), 0.006)
	_sign(r, "GATOS", Vector3(2.0, 2.8, 2.0))
	_interact(r, "Estanterías: comprar productos", open.bind("tienda"), Vector3(-2.5, 1, -0.5), 1.6)
	# Mostrador con caja.
	r.add_child(Shapes.wall(Vector3(3.0, 1.05, 0.8), Vector3(3.6, 0.53, -2.6), wood))
	r.add_child(Shapes.box(Vector3(0.5, 0.3, 0.4), Color(0.2, 0.2, 0.22), Vector3(4.3, 1.2, -2.6)))
	_sign(r, "CAJA", Vector3(3.6, 2.3, -2.3))
	_person(r, "dependiente", {"shirt": Color(0.85, 0.85, 0.8), "vest": Color(0.2, 0.45, 0.25), "pants": Color(0.3, 0.25, 0.2), "hair": Color(0.45, 0.45, 0.45)}, Vector3(3.6, 0.06, -1.7), talk)
	# Palé de sacos junto a la entrada.
	for i in 4:
		r.add_child(Shapes.box(Vector3(0.9, 0.3, 0.6), Color(0.85, 0.3, 0.2), Vector3(-4.5, 0.2 + i * 0.32, -3.4)))
	return r


# ---------------------------------------------------------------------
# Ayuntamiento · Banco · SEPRONA
# ---------------------------------------------------------------------
static func town_hall(open: Callable, talk: Callable) -> Node3D:
	var r := room(15.0, 11.0, 5.0, Color(0.92, 0.88, 0.8), Color(0.7, 0.68, 0.65), Color(0.45, 0.25, 0.2))
	var desks := [
		{"x": -4.5, "name": "BANCO", "color": Color(0.2, 0.35, 0.6), "who": "banco",
			"look": {"shirt": Color(0.9, 0.92, 0.95), "vest": Color(0.15, 0.2, 0.35), "pants": Color(0.15, 0.2, 0.35), "hair": Color(0.1, 0.08, 0.06)}},
		{"x": 0.0, "name": "REGISTRO Y SUBVENCIONES", "color": Color(0.6, 0.2, 0.2), "who": "registro",
			"look": {"shirt": Color(0.6, 0.45, 0.6), "pants": Color(0.25, 0.25, 0.3), "hair": Color(0.3, 0.2, 0.15), "long_hair": true}},
		{"x": 4.5, "name": "SEPRONA", "color": Color(0.2, 0.4, 0.25), "who": "seprona",
			"look": {"shirt": Color(0.3, 0.38, 0.25), "pants": Color(0.3, 0.38, 0.25), "hair": Color(0.1, 0.08, 0.06), "cap": Color(0.25, 0.32, 0.2)}},
	]
	for dk in desks:
		r.add_child(Shapes.wall(Vector3(3.2, 1.1, 0.8), Vector3(dk["x"], 0.55, 3.0), dk["color"]))
		r.add_child(Shapes.box(Vector3(3.3, 0.06, 0.9), Color(0.85, 0.8, 0.7), Vector3(dk["x"], 1.13, 3.0)))
		r.add_child(Shapes.wall(Vector3(3.2, 3.0, 0.1), Vector3(dk["x"], 1.5, 5.3), dk["color"].lightened(0.5)))
		_sign(r, dk["name"], Vector3(dk["x"], 3.2, 5.2), 0.007)
		_person(r, dk["who"], dk["look"], Vector3(dk["x"], 0.06, 3.9), talk)
	# Bancos de espera y bandera.
	for x in [-4.0, 4.0]:
		r.add_child(Shapes.wall(Vector3(2.4, 0.45, 0.6), Vector3(x, 0.23, -2.5), Color(0.5, 0.35, 0.22)))
	r.add_child(Shapes.box(Vector3(0.06, 3.0, 0.06), Color(0.8, 0.8, 0.8), Vector3(-6.8, 1.5, 4.5)))
	r.add_child(Shapes.box(Vector3(0.05, 0.6, 0.9), Color(0.8, 0.15, 0.15), Vector3(-6.8, 2.6, 4.0)))
	r.add_child(Shapes.box(Vector3(0.06, 0.25, 0.9), Color(0.95, 0.8, 0.1), Vector3(-6.78, 2.6, 4.0)))
	return r


# ---------------------------------------------------------------------
# Caseta del refugio: 4 caniles al fondo, comedero, armario de limpieza.
# ---------------------------------------------------------------------
const SHELTER_W := 11.0
const SHELTER_D := 8.0


static func shelter_house(open: Callable, feed: Callable, clean: Callable) -> Node3D:
	var r := room(SHELTER_W, SHELTER_D, 3.2, Color(0.88, 0.83, 0.72), Color(0.65, 0.65, 0.62), Color(0.6, 0.25, 0.2))
	var grey := Color(0.6, 0.6, 0.62)
	# Caniles: tabiques bajos y rejas delanteras.
	for i in 5:
		var x := -SHELTER_W / 2 + 0.15 + i * 2.6 + 0.2
		r.add_child(Shapes.wall(Vector3(0.12, 1.3, 2.4), Vector3(x, 0.65, SHELTER_D / 2 - 1.35), grey))
	for i in 4:
		var cx := kennel_pos(i).x
		for b in 6:
			r.add_child(Shapes.box(Vector3(0.04, 1.2, 0.04), Color(0.3, 0.3, 0.32), Vector3(cx - 1.0 + b * 0.4, 0.6, SHELTER_D / 2 - 2.55)))
		r.add_child(Shapes.box(Vector3(2.3, 0.06, 0.06), Color(0.3, 0.3, 0.32), Vector3(cx, 1.2, SHELTER_D / 2 - 2.55)))
		r.add_child(Shapes.box(Vector3(1.0, 0.12, 0.7), Color(0.55, 0.35, 0.5), Vector3(cx - 0.5, 0.06, SHELTER_D / 2 - 0.7)))  # cama
		r.add_child(Shapes.cylinder(0.18, 0.08, Color(0.2, 0.4, 0.8), Vector3(cx + 0.7, 0.05, SHELTER_D / 2 - 1.8)))  # cuenco
	# Comedero y sacos (izquierda de la entrada).
	r.add_child(Shapes.wall(Vector3(1.8, 0.9, 0.8), Vector3(-4.0, 0.45, -2.6), Color(0.55, 0.4, 0.25)))
	for i in 3:
		r.add_child(Shapes.box(Vector3(0.6, 0.8, 0.4), Color(0.85, 0.3, 0.2), Vector3(-4.6 + i * 0.6, 1.3, -2.6)))
	_interact(r, "Comedero: dar de comer y agua a todos", feed, Vector3(-4.0, 1, -1.8), 1.6)
	# Armario de limpieza (derecha de la entrada).
	r.add_child(Shapes.wall(Vector3(1.4, 2.0, 0.7), Vector3(4.4, 1.0, -2.8), Color(0.3, 0.5, 0.7)))
	r.add_child(Shapes.box(Vector3(0.05, 1.3, 0.05), Color(0.8, 0.7, 0.2), Vector3(3.5, 0.65, -3.0)))  # fregona
	_interact(r, "Armario de limpieza: limpiar instalaciones", clean, Vector3(4.2, 1, -1.9), 1.6)
	# Tablón / mesa de gestión en el centro.
	r.add_child(Shapes.wall(Vector3(1.6, 0.8, 0.8), Vector3(0, 0.4, -1.4), Color(0.5, 0.38, 0.25)))
	r.add_child(Shapes.box(Vector3(0.5, 0.04, 0.35), Color(0.15, 0.15, 0.18), Vector3(0.2, 0.83, -1.4)))  # portátil
	_interact(r, "Mesa del refugio: animales, cuidados, vehículo, dormir", open.bind("refugio"), Vector3(0, 1, -2.2), 1.6)
	return r


## Centro de cada canil en coordenadas locales de la caseta.
static func kennel_pos(i: int) -> Vector3:
	var x := -SHELTER_W / 2 + 0.35 + i * 2.6 + 1.3
	return Vector3(x, 0.06, SHELTER_D / 2 - 1.5)
