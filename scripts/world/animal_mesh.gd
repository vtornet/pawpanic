class_name AnimalMesh
extends RefCounted
## Modelo provisional de perro o gato hecho con cajas.
## El color del pelaje sale del id, así cada animal se ve siempre igual.


static func coat_for(id: int) -> Color:
	var r := RandomNumberGenerator.new()
	r.seed = id * 7919 + 13
	var palettes := [
		Color(0.92, 0.88, 0.8), Color(0.25, 0.2, 0.17), Color(0.65, 0.45, 0.25),
		Color(0.85, 0.6, 0.3), Color(0.5, 0.5, 0.52), Color(0.95, 0.95, 0.95), Color(0.4, 0.28, 0.18),
	]
	var base: Color = palettes[r.randi() % palettes.size()]
	return base.lightened(r.randf_range(-0.08, 0.08))


## Colores típicos de cada especie (los perros y gatos usan la paleta general).
static func _species_coat(a: Dictionary) -> Color:
	var r := RandomNumberGenerator.new()
	r.seed = a["id"] * 31 + 7
	match a["species"]:
		"burro":
			return [Color(0.52, 0.5, 0.48), Color(0.4, 0.35, 0.3), Color(0.6, 0.58, 0.55)][r.randi() % 3]
		"caballo":
			return [Color(0.45, 0.28, 0.15), Color(0.2, 0.15, 0.12), Color(0.85, 0.82, 0.78), Color(0.65, 0.42, 0.22)][r.randi() % 4]
		"cabra":
			return [Color(0.95, 0.93, 0.88), Color(0.55, 0.38, 0.22), Color(0.25, 0.22, 0.2)][r.randi() % 3]
		"conejo":
			return [Color(0.95, 0.95, 0.95), Color(0.7, 0.55, 0.4), Color(0.45, 0.42, 0.4), Color(0.85, 0.75, 0.6)][r.randi() % 4]
	return coat_for(a["id"])


## Herbívoros y conejos: mismo esqueleto de cuadrúpedo con otras proporciones y detalles.
static func _build_other(a: Dictionary) -> Node3D:
	var root := Node3D.new()
	var sp: String = a["species"]
	var coat := _species_coat(a)
	var dark := coat.darkened(0.3)
	var legs: Array = []
	var vis := Node3D.new()
	vis.name = "Vis"
	root.add_child(vis)
	# Proporciones: [ancho, alto, largo del cuerpo], altura de patas, escala.
	var dims: Array = {"conejo": [0.34, 0.3, 0.45, 0.1, 0.7], "cabra": [0.4, 0.4, 0.8, 0.45, 1.0],
		"burro": [0.5, 0.55, 1.1, 0.6, 1.25], "caballo": [0.55, 0.6, 1.35, 0.8, 1.45]}[sp]
	var w: float = dims[0]
	var h: float = dims[1]
	var l: float = dims[2]
	var leg_h: float = dims[3]
	vis.scale = Vector3.ONE * dims[4]
	var body_y := leg_h + h / 2
	vis.add_child(Shapes.box(Vector3(w, h, l), coat, Vector3(0, body_y, 0)))
	# Cuello y cabeza.
	var head_y := body_y + h * 0.55
	var head_z := -l / 2 - 0.12
	if sp in ["burro", "caballo"]:
		var neck := Shapes.box(Vector3(w * 0.45, h * 1.1, 0.3), coat, Vector3(0, body_y + h * 0.6, -l / 2 + 0.05))
		neck.rotation.x = -0.5  # inclinado hacia delante
		vis.add_child(neck)
		head_y = body_y + h * 1.1
		head_z = -l / 2 - 0.3
		vis.add_child(Shapes.box(Vector3(0.24, 0.26, 0.55), coat, Vector3(0, head_y, head_z)))
		vis.add_child(Shapes.box(Vector3(0.2, 0.18, 0.18), coat.lightened(0.35) if sp == "burro" else dark, Vector3(0, head_y - 0.05, head_z - 0.3)))
		# Crin.
		vis.add_child(Shapes.box(Vector3(0.06, 0.14, 0.7), dark.darkened(0.3), Vector3(0, body_y + h * 0.95, -l / 2 + 0.05)))
	elif sp == "cabra":
		vis.add_child(Shapes.box(Vector3(0.22, 0.24, 0.32), coat, Vector3(0, head_y, head_z)))
		vis.add_child(Shapes.box(Vector3(0.06, 0.12, 0.05), coat.darkened(0.1), Vector3(0, head_y - 0.18, head_z - 0.1)))  # barba
		for x in [-0.07, 0.07]:
			var horn := Shapes.box(Vector3(0.04, 0.18, 0.04), Color(0.7, 0.65, 0.55), Vector3(x, head_y + 0.18, head_z + 0.08))
			horn.rotation.x = 0.5
			vis.add_child(horn)
	else:  # conejo
		head_y = body_y + 0.08
		head_z = -l / 2 - 0.08
		vis.add_child(Shapes.box(Vector3(0.24, 0.22, 0.22), coat, Vector3(0, head_y, head_z)))
		vis.add_child(Shapes.box(Vector3(0.1, 0.1, 0.1), Color(1, 1, 1), Vector3(0, body_y + 0.05, l / 2 + 0.04)))  # rabito
	# Ojos.
	for x in [-0.07, 0.07]:
		vis.add_child(Shapes.box(Vector3(0.04, 0.04, 0.02), Color(0.05, 0.05, 0.05), Vector3(x * (1.3 if sp != "conejo" else 1.0), head_y + 0.05, head_z - (0.28 if sp in ["burro", "caballo"] else 0.12))))
	# Orejas.
	var ear_len: float = {"conejo": 0.3, "burro": 0.3, "caballo": 0.14, "cabra": 0.1}[sp]
	for x in [-0.07, 0.07]:
		var ear := Shapes.box(Vector3(0.06, ear_len, 0.05), dark if sp != "conejo" else coat, Vector3(x, head_y + 0.12 + ear_len / 2, head_z + (0.1 if sp in ["burro", "caballo"] else 0.03)))
		if sp == "cabra":
			ear.rotation.z = signf(x) * 1.2
		vis.add_child(ear)
	# Patas.
	for x in [-w / 2 + 0.06, w / 2 - 0.06]:
		for z in [-l / 2 + 0.1, l / 2 - 0.1]:
			var hip := Node3D.new()
			hip.position = Vector3(x, leg_h, z)
			hip.add_child(Shapes.box(Vector3(0.09 if sp != "conejo" else 0.07, leg_h, 0.09), dark if sp != "conejo" else coat, Vector3(0, -leg_h / 2, 0)))
			if sp in ["burro", "caballo"]:
				hip.add_child(Shapes.box(Vector3(0.1, 0.06, 0.1), Color(0.15, 0.12, 0.1), Vector3(0, -leg_h + 0.03, 0)))  # casco
			vis.add_child(hip)
			legs.append(hip)
	# Cola.
	if sp in ["burro", "caballo"]:
		var tail := Shapes.box(Vector3(0.07, 0.6 if sp == "caballo" else 0.4, 0.07), dark.darkened(0.3), Vector3(0, body_y - 0.15, l / 2 + 0.05))
		tail.rotation.x = -0.25
		vis.add_child(tail)
	elif sp == "cabra":
		vis.add_child(Shapes.box(Vector3(0.05, 0.12, 0.05), coat, Vector3(0, body_y + 0.15, l / 2 + 0.02)))
	if a.get("injured", false):
		vis.add_child(Shapes.box(Vector3(0.14, 0.14, 0.14), Color(0.9, 0.9, 0.9), Vector3(w / 2, leg_h * 0.6, l / 2 - 0.1)))
	vis.set_meta("legs", legs)
	vis.set_meta("base_scale", dims[4])
	return root


## Fauna silvestre: erizo, ave rapaz y tortuga.
static func _build_wild(a: Dictionary) -> Node3D:
	var root := Node3D.new()
	var vis := Node3D.new()
	vis.name = "Vis"
	root.add_child(vis)
	match a["species"]:
		"erizo":
			vis.add_child(Shapes.box(Vector3(0.3, 0.2, 0.36), Color(0.35, 0.28, 0.2), Vector3(0, 0.12, 0)))
			for i in 10:
				var sp := Shapes.box(Vector3(0.03, 0.12, 0.03), Color(0.25, 0.2, 0.15), Vector3(-0.12 + (i % 5) * 0.06, 0.24, -0.1 + (i / 5) * 0.18))
				sp.rotation.x = -0.4 + (i / 5) * 0.8
				vis.add_child(sp)
			vis.add_child(Shapes.box(Vector3(0.12, 0.1, 0.12), Color(0.7, 0.6, 0.5), Vector3(0, 0.08, -0.22)))
			vis.add_child(Shapes.box(Vector3(0.04, 0.04, 0.03), Color(0.05, 0.05, 0.05), Vector3(0, 0.08, -0.29)))
		"ave":
			var brown := Color(0.5, 0.35, 0.2)
			vis.add_child(Shapes.box(Vector3(0.18, 0.28, 0.18), brown, Vector3(0, 0.22, 0)))
			vis.add_child(Shapes.box(Vector3(0.14, 0.13, 0.14), brown.lightened(0.2), Vector3(0, 0.42, -0.02)))
			vis.add_child(Shapes.box(Vector3(0.04, 0.04, 0.06), Color(0.9, 0.75, 0.2), Vector3(0, 0.4, -0.11)))
			for x in [-0.12, 0.12]:
				var wing := Shapes.box(Vector3(0.24, 0.04, 0.16), brown.darkened(0.2), Vector3(x * 1.4, 0.24, 0.02))
				wing.rotation.z = signf(x) * (0.9 if x > 0 else 0.2)  # un ala caída: está herida
				vis.add_child(wing)
				vis.add_child(Shapes.box(Vector3(0.03, 0.1, 0.03), Color(0.9, 0.75, 0.2), Vector3(x * 0.4, 0.05, 0)))
			vis.add_child(Shapes.box(Vector3(0.1, 0.03, 0.14), brown.darkened(0.3), Vector3(0, 0.12, 0.12)))
		"tortuga":
			vis.add_child(Shapes.cylinder(0.2, 0.14, Color(0.4, 0.38, 0.2), Vector3(0, 0.12, 0)))
			vis.add_child(Shapes.cylinder(0.14, 0.08, Color(0.5, 0.45, 0.25), Vector3(0, 0.22, 0)))
			vis.add_child(Shapes.box(Vector3(0.08, 0.07, 0.1), Color(0.45, 0.42, 0.3), Vector3(0, 0.08, -0.24)))
			for x in [-0.14, 0.14]:
				for z in [-0.12, 0.12]:
					vis.add_child(Shapes.box(Vector3(0.06, 0.05, 0.06), Color(0.45, 0.42, 0.3), Vector3(x, 0.03, z)))
	vis.set_meta("legs", [])
	return root


static func build(a: Dictionary) -> Node3D:
	if a["species"] in ["erizo", "ave", "tortuga"]:
		return _build_wild(a)
	if a["species"] in ["conejo", "cabra", "burro", "caballo"]:
		return _build_other(a)
	var root := Node3D.new()
	var cat: bool = a["species"] == "gato"
	var s := 0.6 if cat else (1.3 if a["size"] == "grande" else (1.0 if a["size"] == "mediano" else 0.75))
	var coat := coat_for(a["id"])
	var dark := coat.darkened(0.25)
	var legs: Array = []
	var vis := Node3D.new()
	vis.name = "Vis"
	vis.scale = Vector3.ONE * s
	root.add_child(vis)
	var body_len := 0.75 if cat else 0.85
	vis.add_child(Shapes.box(Vector3(0.45 if cat else 0.5, 0.38 if cat else 0.42, body_len), coat, Vector3(0, 0.45, 0)))
	vis.add_child(Shapes.box(Vector3(0.36, 0.34, 0.32), coat, Vector3(0, 0.74, -0.48)))
	vis.add_child(Shapes.box(Vector3(0.09, 0.09, 0.09), Color(0.1, 0.1, 0.1), Vector3(0, 0.7, -0.66)))
	for x in [-0.09, 0.09]:
		vis.add_child(Shapes.box(Vector3(0.05, 0.05, 0.02), Color(0.05, 0.05, 0.05), Vector3(x, 0.8, -0.645)))
	for x in [-0.12, 0.12]:
		if cat:
			vis.add_child(Shapes.box(Vector3(0.09, 0.16, 0.06), dark, Vector3(x, 0.98, -0.45)))
		else:
			var ear := Shapes.box(Vector3(0.09, 0.2, 0.07), dark, Vector3(x * 1.3, 0.85, -0.42))
			ear.rotation.z = signf(x) * 0.5
			vis.add_child(ear)
		for z in [-0.28, 0.28]:
			# Pata con pivote en la cadera, para poder andar.
			var hip := Node3D.new()
			hip.position = Vector3(x * 1.35, 0.27, z)
			hip.add_child(Shapes.box(Vector3(0.1, 0.27, 0.1), dark, Vector3(0, -0.14, 0)))
			vis.add_child(hip)
			legs.append(hip)
	var tail := Shapes.box(Vector3(0.06, 0.06, 0.5 if cat else 0.32), dark, Vector3(0, 0.62 if cat else 0.6, 0.6 if cat else 0.52))
	tail.rotation.x = 0.6 if cat else 0.4
	vis.add_child(tail)
	if a.get("injured", false):
		vis.add_child(Shapes.box(Vector3(0.14, 0.14, 0.14), Color(0.9, 0.9, 0.9), Vector3(0.24, 0.25, 0.28)))  # venda
	if a.get("dirty_look", false) or a.get("hygiene", 100) < 30:
		vis.add_child(Shapes.box(Vector3(0.52, 0.1, 0.6), Color(0.35, 0.25, 0.15), Vector3(0, 0.3, 0.05)))  # barro
	vis.set_meta("legs", legs)
	vis.set_meta("base_scale", s)
	return root


## Postura: "stand", "walk", "sit" o "sleep". phase avanza con el tiempo para mover las patas.
static func pose(node: Node3D, state: String, phase: float, delta: float) -> void:
	var vis: Node3D = node.get_node_or_null("Vis")
	if vis == null:
		return
	var legs: Array = vis.get_meta("legs", [])
	var k := clampf(delta * 8.0, 0.0, 1.0)
	var target_y := 0.0
	var target_tilt := 0.0
	var target_roll := 0.0
	for i in legs.size():
		var leg: Node3D = legs[i]
		var want := 0.0
		if state == "walk":
			want = sin(phase + (PI if i % 3 == 0 else 0.0)) * 0.6
		elif state == "sit" and i % 2 == 1:
			want = -1.2  # patas traseras recogidas
		elif state == "sleep":
			want = 1.3 if i % 2 == 0 else -1.3
		leg.rotation.x = lerpf(leg.rotation.x, want, k)
	match state:
		"walk":
			target_y = absf(sin(phase)) * 0.04
		"sit":
			target_tilt = 0.3  # delante arriba
			target_y = -0.03
		"sleep":
			target_y = -0.22
			target_roll = 0.0
	vis.position.y = lerpf(vis.position.y, target_y, k)
	vis.rotation.x = lerpf(vis.rotation.x, target_tilt, k)
	vis.rotation.z = lerpf(vis.rotation.z, target_roll, k)


## Pequeño movimiento para que parezcan vivos.
static func animate(node: Node3D, t: float, seed: int) -> void:
	var vis: Node3D = node.get_node_or_null("Vis")
	if vis == null:
		return
	vis.rotation.y = sin(t * 0.6 + seed) * 0.7
	vis.position.y = absf(sin(t * 2.5 + seed)) * 0.04
