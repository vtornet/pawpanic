class_name Npc
extends Node3D
## Persona con la que se puede hablar. Modelo provisional hecho con cajas,
## respira, mira al jugador cuando se acerca y saluda con la cabeza.

signal talked(npc_id: String)

var npc_id := ""
var display_name := ""
var role := ""

var _head: Node3D
var _torso: Node3D
var _arm_l: Node3D
var _arm_r: Node3D
var _leg_l: Node3D
var _leg_r: Node3D
var walking := false   # lo activa quien lo mueve (vecinos que pasean)
var _body: StaticBody3D
var _t := 0.0
var _seed := 0.0


## look: {"shirt": Color, "pants": Color, "skin": Color, "hair": Color, "coat": Color (opcional),
##        "vest": Color (opcional), "cap": Color (opcional), "long_hair": bool}
static func create(id: String, p_name: String, p_role: String, look: Dictionary) -> Npc:
	var n := Npc.new()
	n.add_to_group("npc")
	n.npc_id = id
	n.display_name = p_name
	n.role = p_role
	n._seed = float(hash(id) % 1000)
	n._build(look)
	var it := Interactable.create("Hablar con %s (%s)" % [p_name, p_role], func() -> void:
		n.nod()
		n.talked.emit(id), 2.3)
	it.position.y = 1.0
	n.add_child(it)
	return n


func _build(look: Dictionary) -> void:
	var skin: Color = look.get("skin", Color(0.93, 0.76, 0.62))
	var shirt: Color = look.get("shirt", Color(0.3, 0.5, 0.7))
	var pants: Color = look.get("pants", Color(0.2, 0.22, 0.3))
	var hair: Color = look.get("hair", Color(0.2, 0.14, 0.1))
	# Colisión para no atravesarlo.
	var body := StaticBody3D.new()
	_body = body
	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.3
	cap.height = 1.7
	col.shape = cap
	col.position.y = 0.85
	body.add_child(col)
	add_child(body)
	# Piernas (con cadera para poder andar).
	for x in [-0.12, 0.12]:
		var hip := Node3D.new()
		hip.position = Vector3(x, 0.8, 0)
		add_child(hip)
		hip.add_child(Shapes.box(Vector3(0.2, 0.8, 0.22), pants, Vector3(0, -0.4, 0)))
		hip.add_child(Shapes.box(Vector3(0.22, 0.1, 0.3), Color(0.15, 0.12, 0.1), Vector3(0, -0.75, -0.04)))
		if x < 0:
			_leg_l = hip
		else:
			_leg_r = hip
	# Torso (se mueve al respirar).
	_torso = Node3D.new()
	_torso.position.y = 0.8
	add_child(_torso)
	_torso.add_child(Shapes.box(Vector3(0.5, 0.62, 0.28), shirt, Vector3(0, 0.31, 0)))
	if look.has("coat"):  # bata
		_torso.add_child(Shapes.box(Vector3(0.54, 0.85, 0.32), look["coat"], Vector3(0, 0.2, 0)))
	if look.has("vest"):  # chaleco
		_torso.add_child(Shapes.box(Vector3(0.53, 0.45, 0.31), look["vest"], Vector3(0, 0.38, 0)))
	# Brazos.
	_arm_l = Node3D.new()
	_arm_l.position = Vector3(-0.32, 0.58, 0)
	_torso.add_child(_arm_l)
	_arm_l.add_child(Shapes.box(Vector3(0.14, 0.58, 0.16), look.get("coat", shirt), Vector3(0, -0.27, 0)))
	_arm_l.add_child(Shapes.box(Vector3(0.12, 0.12, 0.12), skin, Vector3(0, -0.6, 0)))
	_arm_r = Node3D.new()
	_arm_r.position = Vector3(0.32, 0.58, 0)
	_torso.add_child(_arm_r)
	_arm_r.add_child(Shapes.box(Vector3(0.14, 0.58, 0.16), look.get("coat", shirt), Vector3(0, -0.27, 0)))
	_arm_r.add_child(Shapes.box(Vector3(0.12, 0.12, 0.12), skin, Vector3(0, -0.6, 0)))
	# Cabeza.
	_head = Node3D.new()
	_head.position.y = 0.66
	_torso.add_child(_head)
	_head.add_child(Shapes.box(Vector3(0.08, 0.08, 0.08), skin, Vector3(0, 0.02, 0)))  # cuello
	_head.add_child(Shapes.box(Vector3(0.34, 0.36, 0.32), skin, Vector3(0, 0.22, 0)))
	_head.add_child(Shapes.box(Vector3(0.36, 0.12, 0.34), hair, Vector3(0, 0.42, 0.01)))
	_head.add_child(Shapes.box(Vector3(0.36, 0.2, 0.08), hair, Vector3(0, 0.32, 0.15)))
	if look.get("long_hair", false):
		_head.add_child(Shapes.box(Vector3(0.38, 0.4, 0.1), hair, Vector3(0, 0.12, 0.17)))
	for x in [-0.07, 0.07]:
		_head.add_child(Shapes.box(Vector3(0.05, 0.05, 0.02), Color(0.1, 0.1, 0.1), Vector3(x, 0.26, -0.165)))
	_head.add_child(Shapes.box(Vector3(0.1, 0.025, 0.02), Color(0.6, 0.3, 0.3), Vector3(0, 0.14, -0.165)))
	if look.has("cap"):  # gorra (agente, voluntario)
		_head.add_child(Shapes.box(Vector3(0.38, 0.1, 0.36), look["cap"], Vector3(0, 0.45, 0)))
		_head.add_child(Shapes.box(Vector3(0.3, 0.03, 0.18), look["cap"], Vector3(0, 0.41, -0.24)))
	# Nombre encima.
	var l := Shapes.label(display_name, Vector3(0, 2.05, 0), 32)
	l.pixel_size = 0.005
	l.modulate = Color(1, 0.95, 0.8)
	add_child(l)


## Los que pasean no bloquean al jugador.
func set_solid(value: bool) -> void:
	_body.collision_layer = 1 if value else 0


func _process(delta: float) -> void:
	_t += delta
	var swing := sin(_t * 7.0) * 0.5 if walking else 0.0
	_leg_l.rotation.x = lerpf(_leg_l.rotation.x, swing, clampf(delta * 10.0, 0.0, 1.0))
	_leg_r.rotation.x = lerpf(_leg_r.rotation.x, -swing, clampf(delta * 10.0, 0.0, 1.0))
	if walking:
		_arm_l.rotation.x = -swing * 0.6
		_arm_r.rotation.x = swing * 0.6
		return
	# Respiración y brazos.
	_torso.scale.y = 1.0 + sin(_t * 1.6 + _seed) * 0.012
	_arm_l.rotation.x = sin(_t * 0.9 + _seed) * 0.05
	_arm_r.rotation.x = -sin(_t * 0.9 + _seed) * 0.05
	# Mira al jugador si está cerca.
	var player := get_tree().get_first_node_in_group("player") as Node3D
	var target_yaw := sin(_t * 0.3 + _seed) * 0.3
	if player:
		var to := player.global_position - global_position
		if Vector2(to.x, to.z).length() < 7.0:
			var local := global_transform.basis.inverse() * to
			target_yaw = clampf(atan2(-local.x, -local.z), -1.1, 1.1)
	_head.rotation.y = lerp_angle(_head.rotation.y, target_yaw, clampf(delta * 4.0, 0.0, 1.0))
	_head.rotation.x = sin(_t * 0.7 + _seed) * 0.04


## Pequeño gesto al empezar a hablar.
func nod() -> void:
	var tw := create_tween()
	tw.tween_property(_head, "rotation:x", 0.25, 0.15)
	tw.tween_property(_head, "rotation:x", 0.0, 0.2)
	tw.parallel().tween_property(_arm_r, "rotation:x", -1.2, 0.2)
	tw.tween_property(_arm_r, "rotation:x", 0.0, 0.4)
