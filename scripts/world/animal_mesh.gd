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


static func build(a: Dictionary) -> Node3D:
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
