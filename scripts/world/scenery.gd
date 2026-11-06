class_name Scenery
extends Node3D
## Escenario del pueblo y del campo: suelo, carreteras, aceras, plaza, río, árboles y casas.
## Usa los modelos CC0 de Kenney (assets/kenney). Los edificios con interior (clínica, tienda...)
## y el refugio los construye World; aquí solo va la decoración y lo que no se usa.

const TOWN := 75.0          # medio lado del casco urbano
const ROAD_W := 8.0
const RING_W := 6.0

var _rng := RandomNumberGenerator.new()
var _keep_clear: Array = []   # [Vector2 a, Vector2 b, radio]: tramos donde no se puede poner nada
var _keep_rects: Array = []   # Rect2: zonas rectangulares libres (terrenos del refugio)


func build(walker_loops: Array) -> void:
	_rng.seed = 7
	_reserve(walker_loops)
	_ground()
	_roads()
	_sidewalks(walker_loops)
	_plaza()
	_river()
	_houses()
	_town_trees()
	_pine_forest()
	_countryside()
	_spot_props()


# ---------------------------------------------------------------------
# Zonas que deben quedar libres
# ---------------------------------------------------------------------

func _reserve(walker_loops: Array) -> void:
	for loop in walker_loops:
		for i in loop.size():
			var a: Vector3 = loop[i]
			var b: Vector3 = loop[(i + 1) % loop.size()]
			_keep_clear.append([Vector2(a.x, a.z), Vector2(b.x, b.z), 2.0])
	# Carreteras.
	_keep_clear.append([Vector2(0, -160), Vector2(0, 35), ROAD_W / 2 + 3.0])
	_keep_clear.append([Vector2(-160, 0), Vector2(160, 0), ROAD_W / 2 + 3.0])
	for r in [-110.0, 110.0]:
		_keep_clear.append([Vector2(-120, r), Vector2(120, r), RING_W / 2 + 3.0])
		_keep_clear.append([Vector2(r, -120), Vector2(r, 120), RING_W / 2 + 3.0])
	# Edificios con interior, lugares de los avisos y parcelas del refugio.
	for k in World.PLACES:
		var p: Vector3 = World.PLACES[k]["pos"]
		_keep_clear.append([Vector2(p.x, p.z), Vector2(p.x, p.z), 10.0])
	for spot in Game.SPOTS:
		var p: Vector3 = spot["pos"]
		_keep_clear.append([Vector2(p.x, p.z), Vector2(p.x, p.z), 11.0])
	# Terrenos del refugio: el mayor (la finca) mide 70 × 70 alrededor de la parcela elegida.
	var biggest := 0.0
	for l in Catalog.LANDS:
		biggest = maxf(biggest, float(l["size"]))
	for l in Catalog.LANDS:
		if l.has("pos"):
			var p: Vector3 = l["pos"]
			_keep_rects.append(Rect2(p.x - biggest / 2 - 2, p.z - biggest / 2 - 2, biggest + 4, biggest + 4))
	_keep_clear.append([Vector2(0, 30), Vector2(0, 50), 4.0])   # camino del refugio
	_keep_clear.append([Vector2(-80, -70), Vector2(-80, 190), 12.0])   # río
	_keep_clear.append([Vector2(0, 0), Vector2(0, 0), 14.0])   # plaza


func _free_at(p: Vector3, r: float) -> bool:
	var q := Vector2(p.x, p.z)
	if absf(p.x) > 165 or absf(p.z) > 165:
		return false
	for k in _keep_clear:
		var d := _seg_dist(q, k[0], k[1])
		if d < k[2] + r:
			return false
	for rect in _keep_rects:
		if rect.grow(r).has_point(q):
			return false
	return true


static func _seg_dist(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var t := 0.0
	if ab.length_squared() > 0.0001:
		t = clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
	return p.distance_to(a + ab * t)


func _occupy(p: Vector3, r: float) -> void:
	_keep_clear.append([Vector2(p.x, p.z), Vector2(p.x, p.z), r])


# ---------------------------------------------------------------------
# Suelo, carreteras y aceras
# ---------------------------------------------------------------------

func _ground() -> void:
	var body := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(340, 1, 340)
	col.shape = bs
	col.position.y = -0.5
	body.add_child(col)
	add_child(body)
	add_child(Models.ground(Vector2(340, 340), Models.grass(), Vector3(0, 0, 0)))


func _road(size: Vector2, pos: Vector3, along_x: bool, width: float, line: bool = true) -> void:
	var m := Models.ground(size, Models.road(along_x, width, pos, line), pos + Vector3(0, 0.02, 0))
	add_child(m)


func _roads() -> void:
	# La carretera norte-sur termina en el camino del refugio (las parcelas están al sur).
	_road(Vector2(ROAD_W, 195), Vector3(0, 0, -62.5), false, ROAD_W)
	_road(Vector2(320, ROAD_W), Vector3(0, 0.004, 0), true, ROAD_W)
	for z in [-110.0, 110.0]:
		_road(Vector2(240, RING_W), Vector3(0, 0, z), true, RING_W)
	for x in [-110.0, 110.0]:
		_road(Vector2(RING_W, 240), Vector3(x, 0.004, 0), false, RING_W)
	# Camino de tierra hasta las parcelas del refugio.
	add_child(Models.ground(Vector2(5, 40), Models.dirt(), Vector3(0, 0.015, 52)))


func _paved(size: Vector2, pos: Vector3) -> void:
	var m := Models.ground(size, Models.tiles(Color(0.78, 0.77, 0.74), Color(0.72, 0.71, 0.68), Color(0.58, 0.57, 0.55), 1.0), pos)
	add_child(m)
	# Bordillo.
	var curb := Shapes.box(Vector3(size.x, 0.12, size.y), Color(0.7, 0.7, 0.68), pos - Vector3(0, 0.05, 0))
	curb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(curb)


func _sidewalks(walker_loops: Array) -> void:
	var w := 2.4
	var off := ROAD_W / 2 + w / 2
	# A lo largo de la carretera norte-sur y de la este-oeste, dentro del pueblo (sin pisar la plaza).
	for side in [-1.0, 1.0]:
		_paved(Vector2(w, 60), Vector3(side * off, 0.06, -42))
		_paved(Vector2(w, 22), Vector3(side * off, 0.06, 23))
		_paved(Vector2(62, w), Vector3(-43, 0.06, side * off))
		_paved(Vector2(62, w), Vector3(43, 0.06, side * off))
	# Paseos por donde caminan los vecinos (fuera de las carreteras).
	for loop in walker_loops.slice(3):
		for i in loop.size():
			var a: Vector3 = loop[i]
			var b: Vector3 = loop[(i + 1) % loop.size()]
			var mid := (a + b) / 2.0
			var len := a.distance_to(b) + 2.0
			var along_x := absf(b.x - a.x) > absf(b.z - a.z)
			_paved(Vector2(len, 2.0) if along_x else Vector2(2.0, len), mid + Vector3(0, 0.05, 0))


func _plaza() -> void:
	add_child(Models.ground(Vector2(22, 22), Models.tiles(Color(0.88, 0.8, 0.66), Color(0.82, 0.73, 0.58), Color(0.62, 0.55, 0.45), 1.4),
		Vector3(0, 0.07, 0)))
	# Fuente.
	var basin := StaticBody3D.new()
	var bcol := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 2.4
	cyl.height = 0.8
	bcol.shape = cyl
	bcol.position.y = 0.4
	basin.add_child(bcol)
	add_child(basin)
	add_child(Shapes.cylinder(2.4, 0.7, Color(0.85, 0.82, 0.76), Vector3(0, 0.35, 0)))
	var water := MeshInstance3D.new()
	var wm := CylinderMesh.new()
	wm.top_radius = 2.1
	wm.bottom_radius = 2.1
	wm.height = 0.05
	water.mesh = wm
	water.material_override = Models.water()
	water.position = Vector3(0, 0.62, 0)
	add_child(water)
	add_child(Shapes.cylinder(0.35, 1.6, Color(0.88, 0.85, 0.8), Vector3(0, 1.0, 0)))
	add_child(Shapes.cylinder(0.9, 0.2, Color(0.85, 0.82, 0.76), Vector3(0, 1.75, 0)))
	# Bancos, macetas y árboles en las esquinas.
	for c in [Vector3(-8, 0, -8), Vector3(8, 0, -8), Vector3(8, 0, 8), Vector3(-8, 0, 8)]:
		add_child(Models.spawn("nature/tree_oak", 4.2, c + Vector3(0, 0.07, 0), _rng.randf() * 360))
		add_child(Models.spawn("city-suburban/planter", 4.0, c * 0.62 + Vector3(0, 0.07, 0), rad_to_deg(atan2(c.x, c.z))))
	for b in [[Vector3(0, 0.07, -7.5), 0.0], [Vector3(0, 0.07, 7.5), 180.0], [Vector3(-7.5, 0.07, 0), 90.0], [Vector3(7.5, 0.07, 0), -90.0]]:
		add_child(Models.spawn("furniture/bench", 2.4, b[0], b[1]))
	for i in 10:
		var a := TAU * i / 10.0
		add_child(Models.spawn(["nature/flower_redA", "nature/flower_yellowA", "nature/flower_purpleA"][i % 3], 3.0,
			Vector3(cos(a) * 3.0, 0.07, sin(a) * 3.0), _rng.randf() * 360))


func _river() -> void:
	add_child(Models.ground(Vector2(14, 260), Models.water(), Vector3(-80, 0.03, 60)))
	for side in [-1.0, 1.0]:
		add_child(Models.ground(Vector2(3, 260), Models.terrain(Color(0.72, 0.66, 0.5), Color(0.62, 0.58, 0.42), Color(0.5, 0.6, 0.35), 0.2, 0.4),
			Vector3(-80 + side * 8.5, 0.025, 60)))
	for i in 70:
		var z := _rng.randf_range(-65, 185)
		var x := -80 + (1.0 if _rng.randf() < 0.5 else -1.0) * _rng.randf_range(7.0, 10.5)
		var m: String = ["nature/grass_large", "nature/grass_leafsLarge", "nature/plant_bushSmall", "nature/rock_smallA", "nature/lily_large"][_rng.randi() % 5]
		if m == "nature/lily_large":
			x = -80 + _rng.randf_range(-6, 6)
		add_child(Models.spawn(m, _rng.randf_range(2.5, 4.0), Vector3(x, 0.03, z), _rng.randf() * 360))


# ---------------------------------------------------------------------
# Casas y árboles del pueblo
# ---------------------------------------------------------------------

const HOUSES := ["a", "b", "c", "d", "e", "f", "g", "h", "i", "j", "k", "l", "m", "n", "o", "p", "q", "r", "s", "t", "u"]
const SHOPS := ["a", "b", "c", "d", "e", "h"]


func _houses() -> void:
	# Fachadas a lo largo de las calles principales, mirando a la calle.
	var lots := []
	for z in range(-68, 40, 13):
		if absf(z) < 14:
			continue
		lots.append([Vector3(14, 0, z), 90.0])
		lots.append([Vector3(-14, 0, z), -90.0])
	for x in range(-68, 70, 13):
		if absf(x) < 14:
			continue
		lots.append([Vector3(x, 0, 15), 0.0])
		lots.append([Vector3(x, 0, -15), 180.0])
	# Resto del casco urbano: casas mirando a la calle más cercana.
	for i in 260:
		var p := Vector3(_rng.randf_range(-70, 70), 0, _rng.randf_range(-70, 40))
		var rot := (90.0 if p.x > 0 else -90.0) if absf(p.x) < absf(p.z) else (0.0 if p.z > 0 else 180.0)
		lots.append([p, rot])
	var placed := 0
	for lot in lots:
		if placed >= 60:
			break
		var p: Vector3 = lot[0]
		if not _free_at(p, 4.5):
			continue
		placed += 1
		_occupy(p, 5.5)
		# Cerca de la plaza, edificios de dos o tres plantas con tienda; fuera, casas.
		var near_center: bool = absf(p.x) < 30 and absf(p.z) < 30
		var path: String
		var sc: float
		if near_center:
			path = "city-commercial/building-" + SHOPS[_rng.randi() % SHOPS.size()]
			sc = 6.5
		else:
			path = "city-suburban/building-type-" + HOUSES[_rng.randi() % HOUSES.size()]
			sc = 6.2
		var size: Vector3 = _size_of(path) * sc
		var h := Models.spawn_solid(path, sc, p, lot[1], Vector3(size.x * 0.92, size.y, size.z * 0.92))
		add_child(h)



## Tamaños medidos de los modelos (sin escalar), para las colisiones.
static func _size_of(path: String) -> Vector3:
	const S := {
		"city-commercial/building-a": Vector3(0.88, 1.29, 0.94), "city-commercial/building-b": Vector3(0.97, 1.29, 0.94),
		"city-commercial/building-c": Vector3(0.88, 0.89, 1.09), "city-commercial/building-d": Vector3(0.84, 1.29, 0.9),
		"city-commercial/building-e": Vector3(1.64, 0.89, 1.01), "city-commercial/building-h": Vector3(0.88, 1.29, 1.01),
	}
	if S.has(path):
		return S[path]
	return Vector3(1.3, 1.1, 1.05)


func _town_trees() -> void:
	# Árboles de alineación en las aceras.
	for z in range(-70, 32, 12):
		if absf(z) < 14:
			continue
		for x in [-7.0, 7.0]:
			_tree_at(Vector3(x, 0.06, z + 6), "nature/tree_default", 3.4)
	for x in range(-70, 72, 12):
		if absf(x) < 14:
			continue
		for z in [-7.0, 7.0]:
			_tree_at(Vector3(x + 6, 0.06, z), "nature/tree_default", 3.4)


func _tree_at(p: Vector3, path: String, sc: float) -> void:
	var t := Models.spawn_solid(path, sc * _rng.randf_range(0.85, 1.15), p, _rng.randf() * 360, Vector3(0.5, 3.0, 0.5))
	add_child(t)


func _pine_forest() -> void:
	var pines := ["nature/tree_pineRoundA", "nature/tree_pineRoundB", "nature/tree_pineRoundC", "nature/tree_pineDefaultA",
		"nature/tree_pineTallA", "nature/tree_pineRoundD"]
	for i in 90:
		var p := Vector3(_rng.randf_range(58, 145), 0, _rng.randf_range(65, 145))
		if p.distance_to(Vector3(85, 0, 95)) < 9 or not _free_at(p, 1.5):
			continue
		_tree_at(p, pines[_rng.randi() % pines.size()], _rng.randf_range(4.5, 6.5))
	for i in 50:
		var p := Vector3(_rng.randf_range(58, 145), 0, _rng.randf_range(65, 145))
		if _free_at(p, 1.0):
			add_child(Models.spawn(["nature/grass_large", "nature/plant_bushSmall", "nature/mushroom_redGroup", "nature/rock_smallB"][_rng.randi() % 4],
				_rng.randf_range(2.5, 3.5), p, _rng.randf() * 360))


func _countryside() -> void:
	var trees := ["nature/tree_oak", "nature/tree_default", "nature/tree_fat", "nature/tree_detailed", "nature/tree_simple"]
	var placed := 0
	var tries := 0
	while placed < 130 and tries < 3000:
		tries += 1
		var p := Vector3(_rng.randf_range(-160, 160), 0, _rng.randf_range(-160, 160))
		if absf(p.x) < TOWN and absf(p.z) < TOWN and p.z < 45:
			continue
		if not _free_at(p, 2.0):
			continue
		placed += 1
		var r := _rng.randf()
		if r < 0.45:
			_tree_at(p, trees[_rng.randi() % trees.size()], _rng.randf_range(3.5, 5.0))
		elif r < 0.75:
			add_child(Models.spawn(["nature/plant_bush", "nature/plant_bushLarge", "nature/plant_bushDetailed"][_rng.randi() % 3],
				_rng.randf_range(3.0, 4.5), p, _rng.randf() * 360))
		elif r < 0.88:
			add_child(Models.spawn(["nature/rock_largeA", "nature/rock_largeB", "nature/rock_largeC"][_rng.randi() % 3],
				_rng.randf_range(2.0, 3.5), p, _rng.randf() * 360))
		else:
			for k in 6:
				add_child(Models.spawn(["nature/flower_redA", "nature/flower_yellowB", "nature/flower_purpleC", "nature/grass"][_rng.randi() % 4],
					3.0, p + Vector3(_rng.randf_range(-2, 2), 0, _rng.randf_range(-2, 2)), _rng.randf() * 360))


# ---------------------------------------------------------------------
# Los sitios de los avisos tienen algo que los distinga
# ---------------------------------------------------------------------

func _spot_props() -> void:
	for spot in Game.SPOTS:
		var p: Vector3 = spot["pos"]
		match spot["name"]:
			"Polígono industrial":
				for k in 3:
					add_child(Models.spawn_solid("city-commercial/low-detail-building-wide-a", 7.0, p + Vector3(-18 + k * 14, 0, -16), 180.0, Vector3(6.5, 14, 3.5)))
				for k in 5:
					add_child(Models.spawn("survival/box-large", 2.2, p + Vector3(_rng.randf_range(-8, 8), 0, _rng.randf_range(-9, -7)), _rng.randf() * 90))
			"Huertas":
				for row in 6:
					for k in 8:
						var crop: String = ["nature/crops_cornStageD", "nature/crop_pumpkin", "nature/crops_leafsStageB", "nature/crop_melon"][row % 4]
						add_child(Models.spawn(crop, 3.0, p + Vector3(12 + row * 2.2, 0, -10 + k * 2.4)))
				for k in 12:
					add_child(Models.spawn("nature/fence_simple", 3.0, p + Vector3(9.5, 0, -12 + k * 3.0), 90.0))
			"Vertedero":
				for k in 14:
					var m: String = ["survival/barrel", "survival/box", "survival/box-large-open", "survival/metal-panel", "survival/bucket"][_rng.randi() % 5]
					add_child(Models.spawn(m, _rng.randf_range(1.8, 2.6), p + Vector3(_rng.randf_range(-10, 10), 0, _rng.randf_range(-10, -4)), _rng.randf() * 360))
			"Cortijo abandonado":
				add_child(Models.spawn_solid("city-suburban/building-type-g", 6.0, p + Vector3(0, 0, -14), 0.0, Vector3(8.5, 4.8, 7)))
				for k in 6:
					add_child(Models.spawn("nature/fence_planks", 3.0, p + Vector3(-9 + k * 3.0, 0, -7)))
			"Colegio":
				add_child(Models.spawn_solid("city-commercial/building-n", 5.0, p + Vector3(0, 0, -18), 0.0, Vector3(11, 12, 8.5)))
			"Gasolinera":
				add_child(Models.spawn_solid("city-commercial/building-c", 6.0, p + Vector3(-10, 0, -10), 45.0, Vector3(5, 5.3, 6)))
			"Urbanización":
				for k in 4:
					add_child(Models.spawn_solid("city-suburban/building-type-" + HOUSES[k * 3], 6.0, p + Vector3(-21 + k * 14, 0, -16), 0.0, Vector3(7.8, 6.5, 6.2)))
		# Poste con el nombre del sitio.
		if spot["name"] != "Plaza del pueblo":
			add_child(Models.spawn("survival/signpost-single", 3.0, p + Vector3(6, 0, 6), 45.0))
			var l := Shapes.label(spot["name"], p + Vector3(6, 3.4, 6), 40)
			l.pixel_size = 0.012
			add_child(l)
