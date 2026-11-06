class_name Models
extends RefCounted
## Modelos de los packs CC0 de Kenney (assets/kenney/<kit>/<modelo>.glb) y materiales del escenario.
##
## Los modelos de Kenney miran hacia +Z; en Godot «delante» es -Z. spawn() los envuelve en un nodo
## y los gira 180° para que todo el juego siga usando -Z como frente.

const ROOT := "res://assets/kenney/"

static var _scenes := {}
static var _mats := {}
static var _fixed := {}   # material original -> material corregido


## Suelta lo cargado (al cerrar el juego, para no dejar recursos sin liberar).
static func clear() -> void:
	_scenes.clear()
	_mats.clear()
	_fixed.clear()


static func scene(path: String) -> PackedScene:
	if not _scenes.has(path):
		_scenes[path] = load(ROOT + path + ".glb") as PackedScene
	return _scenes[path]


## path: "car/sedan", "nature/tree_oak"... scale: escala uniforme. Devuelve un Node3D con el modelo dentro.
static func spawn(path: String, scale: float = 1.0, pos: Vector3 = Vector3.ZERO, rot_y_deg: float = 0.0) -> Node3D:
	var root := Node3D.new()
	root.position = pos
	root.rotation_degrees.y = rot_y_deg
	var ps := scene(path)
	if ps == null:
		push_warning("Modelo no encontrado: " + path)
		return root
	var m: Node3D = ps.instantiate()
	_fix_materials(m)
	m.rotation_degrees.y = 180.0
	m.scale = Vector3.ONE * scale
	root.add_child(m)
	root.set_meta("model", m)
	return root


## Los modelos del kit de naturaleza traen metallic = 1, que sin reflejos los deja casi negros.
## Se corrigen (una vez por material) y las hojas se acercan a un verde más mediterráneo.
static func _fix_materials(n: Node) -> void:
	if n is MeshInstance3D:
		var mi := n as MeshInstance3D
		if mi.mesh:
			for i in mi.mesh.get_surface_count():
				var src := mi.mesh.surface_get_material(i) as StandardMaterial3D
				if src == null:
					continue
				if not _fixed.has(src):
					var dst := src
					if src.metallic > 0.0 or src.resource_name.begins_with("leafs"):
						dst = src.duplicate() as StandardMaterial3D
						dst.metallic = 0.0
						dst.roughness = 0.9
						if src.resource_name.begins_with("leafs"):
							dst.albedo_color = src.albedo_color.lerp(Color(0.36, 0.66, 0.26), 0.55)
					_fixed[src] = dst
				if _fixed[src] != src:
					mi.set_surface_override_material(i, _fixed[src])
	for c in n.get_children():
		_fix_materials(c)


## Igual que spawn() pero con una caja de colisión del tamaño indicado (centrada en el suelo).
static func spawn_solid(path: String, scale: float, pos: Vector3, rot_y_deg: float, box: Vector3) -> Node3D:
	var root := spawn(path, scale, pos, rot_y_deg)
	var body := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = box
	col.shape = bs
	col.position.y = box.y / 2.0
	body.add_child(col)
	root.add_child(body)
	return root


## Como spawn(), pero centra el modelo sobre su planta (x, z) y lo apoya en el suelo.
## Útil con los muebles, que traen el origen en una esquina. box: si no es cero, añade colisión.
static func prop(path: String, scale: float, pos: Vector3, rot_y_deg: float = 0.0, solid: bool = false) -> Node3D:
	var root := spawn(path, scale, pos, rot_y_deg)
	var m: Node3D = root.get_meta("model", null)
	if m == null:
		return root
	var acc := [null]
	_aabb(m, m.transform, acc)
	if acc[0] != null:
		var a: AABB = acc[0]
		var c := a.get_center()
		m.position -= Vector3(c.x, a.position.y, c.z)
		if solid:
			var body := StaticBody3D.new()
			var col := CollisionShape3D.new()
			var bs := BoxShape3D.new()
			bs.size = a.size
			col.shape = bs
			col.position.y = a.size.y / 2.0
			body.add_child(col)
			root.add_child(body)
	return root


static func _aabb(n: Node, xf: Transform3D, acc: Array) -> void:
	if n is MeshInstance3D and (n as MeshInstance3D).mesh:
		var a: AABB = xf * (n as MeshInstance3D).mesh.get_aabb()
		acc[0] = a if acc[0] == null else (acc[0] as AABB).merge(a)
	for c in n.get_children():
		if c is Node3D:
			_aabb(c, xf * (c as Node3D).transform, acc)


## AnimationPlayer del modelo (personajes), o null.
static func anim_player(root: Node) -> AnimationPlayer:
	return root.find_child("AnimationPlayer", true, false) as AnimationPlayer


# ---------------------------------------------------------------------
# Materiales del escenario
# ---------------------------------------------------------------------

static func terrain(a: Color, b: Color, c: Color, scale: float = 0.045, detail: float = 0.35) -> ShaderMaterial:
	var key := "t%s%s%s%f" % [a, b, c, scale]
	if not _mats.has(key):
		var m := ShaderMaterial.new()
		m.shader = load("res://shaders/terrain.gdshader")
		m.set_shader_parameter("color_a", a)
		m.set_shader_parameter("color_b", b)
		m.set_shader_parameter("color_c", c)
		m.set_shader_parameter("scale", scale)
		m.set_shader_parameter("detail", detail)
		_mats[key] = m
	return _mats[key]


static func grass() -> ShaderMaterial:
	return terrain(Color(0.47, 0.7, 0.33), Color(0.38, 0.6, 0.28), Color(0.62, 0.74, 0.38))


static func dirt() -> ShaderMaterial:
	return terrain(Color(0.76, 0.64, 0.45), Color(0.68, 0.55, 0.38), Color(0.55, 0.62, 0.36), 0.12, 0.5)


## Patio del refugio: hierba pisada con calvas de tierra.
static func yard() -> ShaderMaterial:
	return terrain(Color(0.56, 0.66, 0.36), Color(0.74, 0.62, 0.43), Color(0.45, 0.62, 0.3), 0.09, 0.5)


static func road(along_x: bool, width: float, center: Vector3, center_line: bool = true) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/road.gdshader")
	m.set_shader_parameter("along_x", along_x)
	m.set_shader_parameter("width", width)
	m.set_shader_parameter("center", center)
	m.set_shader_parameter("center_line", center_line)
	return m


static func tiles(a: Color, b: Color, grout: Color, size: float = 1.2) -> ShaderMaterial:
	var key := "s%s%s%s%f" % [a, b, grout, size]
	if not _mats.has(key):
		var m := ShaderMaterial.new()
		m.shader = load("res://shaders/tiles.gdshader")
		m.set_shader_parameter("color_a", a)
		m.set_shader_parameter("color_b", b)
		m.set_shader_parameter("grout", grout)
		m.set_shader_parameter("tile", size)
		_mats[key] = m
	return _mats[key]


static func water() -> ShaderMaterial:
	if not _mats.has("water"):
		var m := ShaderMaterial.new()
		m.shader = load("res://shaders/water.gdshader")
		_mats["water"] = m
	return _mats["water"]


## Plano horizontal (suelo) con un material.
static func ground(size: Vector2, material: Material, pos: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = size
	mi.mesh = pm
	mi.material_override = material
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi
