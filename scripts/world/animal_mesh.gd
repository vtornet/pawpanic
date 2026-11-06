class_name AnimalMesh
extends RefCounted
## Modelos de los animales, hechos por código con formas redondeadas low-poly.
## Cada perro tiene una raza (o tipo de mestizo) y un pelaje que salen de su id,
## así un animal se ve siempre igual. El nodo "Vis" lleva las patas (para andar, sentarse, dormir).

# ---------------------------------------------------------------------
# Piezas
# ---------------------------------------------------------------------

static var _sphere: SphereMesh
static var _cyl: CylinderMesh
static var _cone: CylinderMesh


static func _meshes() -> void:
	if _sphere != null:
		return
	_sphere = SphereMesh.new()
	_sphere.radius = 0.5
	_sphere.height = 1.0
	_sphere.radial_segments = 10
	_sphere.rings = 6
	_cyl = CylinderMesh.new()
	_cyl.top_radius = 0.5
	_cyl.bottom_radius = 0.5
	_cyl.height = 1.0
	_cyl.radial_segments = 8
	_cyl.rings = 1
	_cone = CylinderMesh.new()
	_cone.top_radius = 0.0
	_cone.bottom_radius = 0.5
	_cone.height = 1.0
	_cone.radial_segments = 6
	_cone.rings = 1


static func _part(parent: Node3D, mesh: Mesh, size: Vector3, color: Color, pos: Vector3, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = Shapes.mat(color, 0.95)
	mi.scale = size
	mi.position = pos
	mi.rotation = rot
	parent.add_child(mi)
	return mi


## Elipsoide de tamaño total size.
static func _e(parent: Node3D, size: Vector3, color: Color, pos: Vector3, rot := Vector3.ZERO) -> MeshInstance3D:
	return _part(parent, _sphere, size, color, pos, rot)


static func _c(parent: Node3D, size: Vector3, color: Color, pos: Vector3, rot := Vector3.ZERO) -> MeshInstance3D:
	return _part(parent, _cyl, size, color, pos, rot)


static func _k(parent: Node3D, size: Vector3, color: Color, pos: Vector3, rot := Vector3.ZERO) -> MeshInstance3D:
	return _part(parent, _cone, size, color, pos, rot)


# ---------------------------------------------------------------------
# Razas y pelajes
# ---------------------------------------------------------------------

## [largo, ancho, alto del cuerpo, alto de patas, grosor de pata, cabeza, hocico, orejas, tamaño orejas, cola, largo cola, pecho, pelo largo]
const BREEDS := {
	"chihuahua": [0.30, 0.16, 0.16, 0.13, 0.035, 0.17, 0.05, "bat", 1.0, "curl", 0.14, 1.0, false],
	"bodeguero": [0.36, 0.17, 0.17, 0.16, 0.04, 0.16, 0.09, "pointy", 0.8, "straight", 0.12, 1.0, false],
	"teckel": [0.50, 0.17, 0.17, 0.08, 0.045, 0.17, 0.13, "floppy", 0.9, "straight", 0.2, 1.1, false],
	"caniche": [0.34, 0.2, 0.2, 0.16, 0.045, 0.18, 0.08, "floppy", 0.8, "pompon", 0.12, 1.0, true],
	"podenco": [0.52, 0.2, 0.24, 0.32, 0.045, 0.2, 0.17, "pointy", 1.5, "whip", 0.35, 1.1, false],
	"mestizo": [0.55, 0.25, 0.27, 0.27, 0.06, 0.23, 0.13, "semi", 1.0, "straight", 0.3, 1.0, false],
	"beagle": [0.5, 0.24, 0.26, 0.22, 0.06, 0.23, 0.13, "floppy", 1.2, "up", 0.25, 1.0, false],
	"border": [0.55, 0.24, 0.27, 0.28, 0.055, 0.22, 0.14, "semi", 0.9, "fluffy", 0.35, 1.0, true],
	"galgo": [0.7, 0.2, 0.3, 0.45, 0.05, 0.2, 0.24, "rose", 1.0, "whip", 0.5, 1.35, false],
	"pastor": [0.72, 0.3, 0.32, 0.36, 0.07, 0.26, 0.2, "pointy", 1.6, "fluffy", 0.45, 1.05, true],
	"labrador": [0.72, 0.33, 0.33, 0.33, 0.075, 0.28, 0.17, "floppy", 1.0, "straight", 0.4, 1.05, false],
	"mastin": [0.82, 0.4, 0.42, 0.38, 0.095, 0.34, 0.17, "floppy", 1.3, "straight", 0.42, 1.1, false],
}
const BREEDS_BY_SIZE := {
	"pequeño": ["chihuahua", "bodeguero", "teckel", "caniche", "mestizo"],
	"mediano": ["podenco", "mestizo", "beagle", "border", "mestizo", "podenco"],
	"grande": ["galgo", "pastor", "labrador", "mastin", "mestizo", "galgo"],
}
const BREED_NAMES := {"chihuahua": "chihuahua", "bodeguero": "ratonero bodeguero", "teckel": "teckel", "caniche": "caniche",
	"podenco": "podenco", "mestizo": "mestizo", "beagle": "beagle", "border": "border collie", "galgo": "galgo",
	"pastor": "pastor alemán", "labrador": "labrador", "mastin": "mastín"}

const WHITE := Color(0.96, 0.95, 0.92)
const BLACK := Color(0.12, 0.11, 0.1)
const TAN := Color(0.78, 0.52, 0.27)
const CREAM := Color(0.92, 0.84, 0.66)
const RED := Color(0.72, 0.38, 0.18)
const CHOCO := Color(0.36, 0.22, 0.13)
const GREY := Color(0.55, 0.55, 0.58)
const FAWN := Color(0.85, 0.68, 0.45)
const BRINDLE := Color(0.42, 0.3, 0.2)


static func _rng(a: Dictionary, salt: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = int(a.get("id", 0)) * 7919 + salt
	return r


## Raza del perro (sale de su id y su tamaño).
static func breed_of(a: Dictionary) -> String:
	if a.get("species", "") != "perro":
		return ""
	var list: Array = BREEDS_BY_SIZE.get(a.get("size", "mediano"), BREEDS_BY_SIZE["mediano"])
	return list[_rng(a, 3).randi() % list.size()]


## Nombre para mostrar en la interfaz ("podenco", "mestizo"...).
static func breed_name(a: Dictionary) -> String:
	return BREED_NAMES.get(breed_of(a), "")


## Pelaje: [color base, color secundario, patrón].
static func _coat_scheme(a: Dictionary, breed: String) -> Array:
	var r := _rng(a, 11)
	var options: Array
	match breed:
		"chihuahua": options = [[CREAM, CREAM, "solid"], [TAN, TAN, "solid"], [BLACK, TAN, "points"], [WHITE, TAN, "patches"]]
		"bodeguero": options = [[WHITE, BLACK, "bodeguero"]]
		"teckel": options = [[RED, RED, "solid"], [BLACK, TAN, "points"], [CHOCO, TAN, "points"]]
		"caniche": options = [[WHITE, WHITE, "solid"], [Color(0.88, 0.66, 0.42), Color(0.88, 0.66, 0.42), "solid"], [BLACK, BLACK, "solid"], [GREY, GREY, "solid"]]
		"podenco": options = [[TAN, WHITE, "white_chest"], [RED, WHITE, "white_chest"], [WHITE, TAN, "patches"]]
		"beagle": options = [[TAN, BLACK, "tricolor"]]
		"border": options = [[BLACK, WHITE, "white_chest"], [CHOCO, WHITE, "white_chest"]]
		"galgo": options = [[BRINDLE, BRINDLE, "brindle"], [FAWN, FAWN, "solid"], [BLACK, BLACK, "solid"], [WHITE, BRINDLE, "patches"], [GREY, WHITE, "white_chest"]]
		"pastor": options = [[TAN, BLACK, "saddle"], [BLACK, BLACK, "solid"]]
		"labrador": options = [[Color(0.93, 0.8, 0.55), Color(0.93, 0.8, 0.55), "solid"], [BLACK, BLACK, "solid"], [CHOCO, CHOCO, "solid"]]
		"mastin": options = [[FAWN, BLACK, "mask"], [BRINDLE, BLACK, "brindle"], [WHITE, GREY, "patches"]]
		_:  # mestizo: cualquier cosa
			var base: Color = [WHITE, BLACK, TAN, CREAM, RED, CHOCO, GREY, FAWN, BRINDLE][r.randi() % 9]
			var second: Color = [WHITE, BLACK, TAN, CREAM][r.randi() % 4]
			var pat: String = ["solid", "white_chest", "patches", "points", "white_chest", "mask"][r.randi() % 6]
			if second == base:
				second = WHITE if base != WHITE else BLACK
			options = [[base, second, pat]]
	var o: Array = options[r.randi() % options.size()]
	var shade := r.randf_range(-0.06, 0.06)
	return [(o[0] as Color).lightened(shade) if shade > 0 else (o[0] as Color).darkened(-shade), o[1], o[2]]


## Color principal (compatibilidad con código antiguo).
static func coat_for(id: int) -> Color:
	return _coat_scheme({"id": id, "species": "perro"}, "mestizo")[0]


# ---------------------------------------------------------------------
# Construcción
# ---------------------------------------------------------------------

static func build(a: Dictionary) -> Node3D:
	_meshes()
	var root := Node3D.new()
	var vis := Node3D.new()
	vis.name = "Vis"
	root.add_child(vis)
	var legs: Array = []
	match a["species"]:
		"perro":
			legs = _dog(vis, a)
		"gato":
			legs = _cat(vis, a)
		"conejo":
			legs = _rabbit(vis, a)
		"cabra", "burro", "caballo":
			legs = _hoofed(vis, a)
		"erizo":
			_hedgehog(vis)
		"ave":
			_bird(vis)
		"tortuga":
			_tortoise(vis)
	var sc := 1.0
	if a.get("age", 3) < 1 and a["species"] in ["perro", "gato"]:
		sc = 0.6
	vis.scale = Vector3.ONE * sc
	vis.set_meta("legs", legs)
	vis.set_meta("base_scale", sc)
	return root


## Cuadrúpedo genérico. p: diccionario de proporciones. Devuelve las patas (delante izq, detrás izq, delante dcha, detrás dcha).
static func _quadruped(vis: Node3D, p: Dictionary, base: Color, second: Color, pattern: String) -> Dictionary:
	var bl: float = p["len"]
	var bw: float = p["w"]
	var bh: float = p["h"]
	var lh: float = p["leg"]
	var lt: float = p["leg_t"]
	var hs: float = p["head"]
	var by := lh + bh * 0.42
	var leg_col := base
	var paw_col := base
	var chest_col := base
	var muzzle_col := base
	var head_col := base
	match pattern:
		"white_chest":
			chest_col = second
			paw_col = second
			muzzle_col = second
		"points":
			chest_col = second
			paw_col = second
			leg_col = base
			muzzle_col = second
		"tricolor":
			chest_col = WHITE
			paw_col = WHITE
			leg_col = WHITE
			muzzle_col = WHITE
			head_col = base
		"mask":
			muzzle_col = second
		"bodeguero":
			head_col = BLACK
			muzzle_col = TAN
	# Cuerpo: tronco, pecho y grupa.
	_e(vis, Vector3(bw, bh, bl), base, Vector3(0, by, 0))
	_e(vis, Vector3(bw * 1.04, bh * 1.08 * p.get("chest", 1.0), bl * 0.48), chest_col, Vector3(0, by - bh * 0.06 * p.get("chest", 1.0), -bl * 0.27))
	_e(vis, Vector3(bw * 1.02, bh * 0.98, bl * 0.42), base, Vector3(0, by + bh * 0.02, bl * 0.3))
	if p.get("belly", false):
		_e(vis, Vector3(bw * 0.9, bh * 0.5, bl * 0.7), WHITE.lerp(base, 0.3), Vector3(0, by - bh * 0.25, 0))
	# Manchas y dibujos del lomo.
	var r := RandomNumberGenerator.new()
	r.seed = int(p.get("seed", 1))
	match pattern:
		"saddle":
			_e(vis, Vector3(bw * 1.06, bh * 0.6, bl * 0.75), second, Vector3(0, by + bh * 0.24, bl * 0.05))
		"tricolor":
			_e(vis, Vector3(bw * 1.06, bh * 0.62, bl * 0.7), second, Vector3(0, by + bh * 0.22, bl * 0.08))
		"patches", "bodeguero":
			for i in 3:
				var side := 1.0 if r.randf() < 0.5 else -1.0
				_e(vis, Vector3(bw * 0.5, bh * 0.55, bl * 0.35), second if pattern == "patches" else (TAN if i == 0 else BLACK),
					Vector3(side * bw * 0.28, by + r.randf_range(-0.02, 0.1) * bh, r.randf_range(-0.3, 0.35) * bl))
		"brindle", "tabby":
			for i in 4:
				_e(vis, Vector3(bw * 1.04, bh * 0.25, bl * 0.06), base.darkened(0.35), Vector3(0, by + bh * 0.12, (-0.3 + i * 0.2) * bl), Vector3(0.3, 0, 0))
	# Cuello y cabeza.
	var nl: float = p.get("neck", 0.18)
	var na: float = p.get("neck_angle", 0.7)
	var neck_base := Vector3(0, by + bh * 0.2, -bl * 0.38)
	var neck_dir := Vector3(0, cos(na), -sin(na))
	_e(vis, Vector3(bw * 0.55, nl + bh * 0.3, bw * 0.55), chest_col if pattern in ["white_chest", "points", "tricolor"] else base,
		neck_base + neck_dir * nl * 0.5, Vector3(-na, 0, 0))
	var head := Node3D.new()
	head.position = neck_base + neck_dir * (nl + hs * 0.15)
	head.rotation.x = -p.get("head_tilt", 0.0)   # hocico hacia abajo (caballos, burros)
	vis.add_child(head)
	_e(head, Vector3(hs * 0.95, hs * 0.9, hs), head_col, Vector3.ZERO)
	var sl: float = p["snout"]
	var sw: float = p.get("snout_w", 0.5)
	if sl > 0.01:
		_e(head, Vector3(hs * sw, hs * 0.45, sl + hs * 0.3), muzzle_col, Vector3(0, -hs * 0.17, -hs * 0.32 - sl * 0.4), Vector3(0.12, 0, 0))
	var tip := Vector3(0, -hs * 0.12, -hs * 0.45 - sl * 0.9)
	_e(head, Vector3(hs * 0.2, hs * 0.15, hs * 0.14), p.get("nose", BLACK), tip)
	for x in [-1.0, 1.0]:
		_e(head, Vector3(hs * 0.13, hs * 0.15, hs * 0.08), BLACK, Vector3(x * hs * 0.24, hs * 0.1, -hs * 0.43))
		_e(head, Vector3(hs * 0.04, hs * 0.05, hs * 0.03), WHITE, Vector3(x * hs * 0.22, hs * 0.14, -hs * 0.47))
		if pattern == "points":
			_e(head, Vector3(hs * 0.1, hs * 0.07, hs * 0.06), second, Vector3(x * hs * 0.24, hs * 0.26, -hs * 0.4))
	_ears(head, p.get("ears", "pointy"), hs, p.get("ear_s", 1.0), base if pattern != "tricolor" else TAN.darkened(0.1),
		BLACK if pattern == "bodeguero" else (second if pattern == "mask" else base))
	if p.get("horns", false):
		for x in [-1.0, 1.0]:
			_k(head, Vector3(hs * 0.14, hs * 0.55, hs * 0.14), Color(0.72, 0.66, 0.55), Vector3(x * hs * 0.18, hs * 0.55, hs * 0.12), Vector3(0.7, 0, x * 0.25))
	if p.get("beard", false):
		_k(head, Vector3(hs * 0.16, hs * 0.35, hs * 0.16), base.darkened(0.1), Vector3(0, -hs * 0.5, -hs * 0.55), Vector3(PI, 0, 0))
	if p.get("mane", false):
		for i in 5:
			var t := i / 4.0
			_e(vis, Vector3(bw * 0.18, bh * 0.35, bh * 0.4), p.get("mane_col", base.darkened(0.45)),
				neck_base + neck_dir * nl * t + Vector3(0, bh * 0.22, bh * 0.15))
	if p.get("fluffy", false):
		_e(head, Vector3(hs * 0.8, hs * 0.4, hs * 0.6), head_col.lightened(0.04), Vector3(0, hs * 0.42, 0.02))
		_e(vis, Vector3(bw * 1.15, bh * 0.7, bl * 0.4), chest_col.lightened(0.04), Vector3(0, by + bh * 0.05, -bl * 0.42))
	# Patas con cadera (para andar).
	var legs: Array = []
	for x in [-1.0, 1.0]:
		for z in [-1.0, 1.0]:
			var hip := Node3D.new()
			hip.position = Vector3(x * bw * 0.3, lh + bh * 0.05, z * bl * 0.33)
			vis.add_child(hip)
			var top := lh * 0.55
			_e(hip, Vector3(lt * 1.6, top + bh * 0.25, lt * 1.9), base, Vector3(0, -top * 0.35, 0))
			_c(hip, Vector3(lt, lh, lt), leg_col if pattern != "points" else base, Vector3(0, -lh * 0.55, 0))
			if p.get("hoof", false):
				_c(hip, Vector3(lt * 1.15, lh * 0.12, lt * 1.15), Color(0.2, 0.17, 0.14), Vector3(0, -lh - bh * 0.05 + lh * 0.06, 0))
			else:
				_e(hip, Vector3(lt * 1.3, lt * 0.8, lt * 1.7), paw_col, Vector3(0, -lh - bh * 0.05 + lt * 0.3, -lt * 0.25))
			legs.append(hip)
	# Cola.
	_tail(vis, p.get("tail", "straight"), p.get("tail_len", 0.3), lt, Vector3(0, by + bh * 0.25, bl * 0.5),
		second if pattern in ["white_chest", "tricolor"] and p.get("tail", "") in ["up", "fluffy"] else base, p.get("tail_col", null))
	return {"legs": legs, "head": head, "by": by}


static func _ears(head: Node3D, kind: String, hs: float, s: float, col: Color, dark: Color) -> void:
	for x in [-1.0, 1.0]:
		match kind:
			"pointy":
				_k(head, Vector3(hs * 0.32, hs * 0.5 * s, hs * 0.18), dark, Vector3(x * hs * 0.26, hs * (0.45 + 0.18 * s), hs * 0.05), Vector3(0, 0, -x * 0.22))
			"bat":
				_k(head, Vector3(hs * 0.42, hs * 0.6 * s, hs * 0.16), dark, Vector3(x * hs * 0.36, hs * 0.55, hs * 0.03), Vector3(0, 0, -x * 0.65))
			"floppy":
				_e(head, Vector3(hs * 0.14, hs * 0.62 * s, hs * 0.38), dark.darkened(0.08), Vector3(x * hs * 0.5, -hs * 0.08 * s, hs * 0.04), Vector3(0, 0, x * 0.18))
			"semi":
				_k(head, Vector3(hs * 0.32, hs * 0.38 * s, hs * 0.16), dark, Vector3(x * hs * 0.3, hs * 0.5, hs * 0.02), Vector3(-0.6, 0, -x * 0.3))
			"rose":
				_e(head, Vector3(hs * 0.12, hs * 0.22, hs * 0.38), dark, Vector3(x * hs * 0.28, hs * 0.36, hs * 0.32), Vector3(0.7, 0, -x * 0.3))
			"cat":
				_k(head, Vector3(hs * 0.36, hs * 0.42, hs * 0.14), dark, Vector3(x * hs * 0.26, hs * 0.5, hs * 0.02), Vector3(0, 0, -x * 0.28))
			"rabbit":
				_e(head, Vector3(hs * 0.24, hs * 1.4 * s, hs * 0.1), dark, Vector3(x * hs * 0.18, hs * 1.05, hs * 0.1), Vector3(-0.25, 0, -x * 0.15))
			"donkey":
				_e(head, Vector3(hs * 0.22, hs * 0.85 * s, hs * 0.12), dark, Vector3(x * hs * 0.24, hs * 0.75, hs * 0.18), Vector3(-0.15, 0, -x * 0.3))
			"side":
				_e(head, Vector3(hs * 0.35, hs * 0.12, hs * 0.2), dark, Vector3(x * hs * 0.55, hs * 0.15, hs * 0.08), Vector3(0, 0, x * 0.3))


static func _tail(vis: Node3D, kind: String, length: float, lt: float, at: Vector3, col: Color, override = null) -> void:
	if override != null:
		col = override
	match kind:
		"curl":
			_e(vis, Vector3(lt * 1.3, length, lt * 1.3), col, at + Vector3(0, length * 0.4, length * 0.15), Vector3(-0.5, 0, 0))
			_e(vis, Vector3(lt * 1.2, lt * 1.2, length * 0.5), col, at + Vector3(0, length * 0.8, length * 0.05))
		"up":
			_e(vis, Vector3(lt * 1.1, length, lt * 1.1), col, at + Vector3(0, length * 0.45, length * 0.15), Vector3(0.35, 0, 0))
		"whip":
			_e(vis, Vector3(lt * 0.7, lt * 0.7, length), col, at + Vector3(0, -length * 0.3, length * 0.38), Vector3(0.8, 0, 0))
		"fluffy":
			_e(vis, Vector3(lt * 2.4, lt * 2.4, length), col, at + Vector3(0, -length * 0.22, length * 0.4), Vector3(0.55, 0, 0))
		"pompon":
			_e(vis, Vector3(lt * 0.8, length, lt * 0.8), col, at + Vector3(0, length * 0.35, length * 0.1), Vector3(0.4, 0, 0))
			_e(vis, Vector3(lt * 3.0, lt * 3.0, lt * 3.0), col.lightened(0.05), at + Vector3(0, length * 0.8, length * 0.25))
		"cat":
			# Sale hacia atrás y se curva hacia arriba.
			_e(vis, Vector3(lt * 0.95, lt * 0.95, length * 0.55), col, at + Vector3(0, length * 0.06, length * 0.24), Vector3(-0.25, 0, 0))
			_e(vis, Vector3(lt * 0.9, length * 0.55, lt * 0.9), col, at + Vector3(0, length * 0.3, length * 0.46), Vector3(0.2, 0, 0))
		"cotton":
			_e(vis, Vector3(lt * 3.0, lt * 3.0, lt * 2.5), WHITE, at + Vector3(0, 0, lt))
		"tuft":
			_e(vis, Vector3(lt * 0.5, length, lt * 0.5), col, at + Vector3(0, -length * 0.45, lt * 1.2), Vector3(-0.15, 0, 0))
			_e(vis, Vector3(lt * 1.0, length * 0.3, lt * 1.0), col.darkened(0.4), at + Vector3(0, -length * 0.95, lt * 1.3))
		"horse":
			_e(vis, Vector3(lt * 1.4, length, lt * 1.6), col, at + Vector3(0, -length * 0.4, lt * 1.8), Vector3(-0.2, 0, 0))
		"short_up":
			_e(vis, Vector3(lt * 1.0, length, lt * 0.8), col, at + Vector3(0, length * 0.3, 0.02), Vector3(0.4, 0, 0))
		_:  # straight
			_e(vis, Vector3(lt * 1.0, lt * 1.0, length), col, at + Vector3(0, length * 0.15, length * 0.42), Vector3(-0.4, 0, 0))


static func _extras(vis: Node3D, a: Dictionary, q: Dictionary, w: float, bl: float) -> void:
	if a.get("injured", false):
		var leg: Node3D = q["legs"][1]
		_c(leg, Vector3(w * 0.35, w * 0.6, w * 0.35), WHITE, Vector3(0, -w * 0.9, 0))  # venda
	if a.get("dirty_look", false) or a.get("hygiene", 100) < 30:
		for i in 4:
			_e(vis, Vector3(w * 0.5, w * 0.3, bl * 0.25), Color(0.38, 0.27, 0.16), Vector3((i % 2 - 0.5) * w * 0.6, q["by"] - w * 0.25, (-0.3 + i * 0.2) * bl))


static func _dog(vis: Node3D, a: Dictionary) -> Array:
	var breed := breed_of(a)
	var b: Array = BREEDS[breed]
	var r := _rng(a, 5)
	var k := r.randf_range(0.92, 1.08)   # cada uno un poco distinto
	if breed == "mestizo":
		k *= {"pequeño": 0.7, "mediano": 1.0, "grande": 1.3}.get(a.get("size", "mediano"), 1.0)
	var sch := _coat_scheme(a, breed)
	var ears: String = b[7]
	if breed == "mestizo":
		ears = ["semi", "floppy", "pointy", "floppy"][r.randi() % 4]
	var p := {"len": b[0] * k, "w": b[1] * k, "h": b[2] * k, "leg": b[3] * k, "leg_t": b[4] * k, "head": b[5] * k * 1.12,
		"snout": b[6] * k, "ears": ears, "ear_s": b[8], "tail": b[9], "tail_len": b[10] * k, "chest": b[11],
		"fluffy": b[12], "seed": int(a["id"]) * 13 + 1, "snout_w": 0.42 if breed == "galgo" else 0.55}
	var q := _quadruped(vis, p, sch[0], sch[1], sch[2])
	_extras(vis, a, q, b[1] * k, b[0] * k)
	return q["legs"]


static func _cat(vis: Node3D, a: Dictionary) -> Array:
	var r := _rng(a, 17)
	var options := [[BLACK, BLACK, "solid"], [GREY, GREY.darkened(0.2), "tabby"], [Color(0.9, 0.55, 0.25), Color(0.9, 0.55, 0.25), "tabby"],
		[WHITE, WHITE, "solid"], [BLACK, WHITE, "white_chest"], [Color(0.9, 0.55, 0.25), WHITE, "white_chest"],
		[WHITE, Color(0.9, 0.55, 0.25), "patches"], [CREAM, CHOCO, "siamese"], [GREY, WHITE, "white_chest"]]
	var o: Array = options[r.randi() % options.size()]
	var pat: String = o[2]
	var k := r.randf_range(0.92, 1.08)
	var p := {"len": 0.4 * k, "w": 0.18 * k, "h": 0.19 * k, "leg": 0.15 * k, "leg_t": 0.035 * k, "head": 0.17 * k, "snout": 0.015,
		"snout_w": 0.6, "ears": "cat", "ear_s": 1.0, "tail": "cat", "tail_len": 0.34 * k, "neck": 0.08, "neck_angle": 0.5,
		"seed": int(a["id"]) * 13 + 5, "nose": Color(0.85, 0.5, 0.5)}
	if pat == "siamese":
		p["tail_col"] = o[1]
		pat = "mask"
	var q := _quadruped(vis, p, o[0], o[1], pat)
	if o[2] == "patches":  # calicó: además manchas negras
		_e(vis, Vector3(0.1, 0.1, 0.12), BLACK, Vector3(0.06, q["by"] + 0.06, 0.08))
	_extras(vis, a, q, 0.18, 0.4)
	return q["legs"]


static func _rabbit(vis: Node3D, a: Dictionary) -> Array:
	var r := _rng(a, 23)
	var col: Color = [WHITE, Color(0.7, 0.55, 0.4), Color(0.45, 0.42, 0.4), CREAM, BLACK][r.randi() % 5]
	var p := {"len": 0.3, "w": 0.2, "h": 0.22, "leg": 0.05, "leg_t": 0.045, "head": 0.15, "snout": 0.02, "snout_w": 0.7,
		"ears": "rabbit", "ear_s": 1.0, "tail": "cotton", "tail_len": 0.06, "neck": 0.04, "neck_angle": 0.3,
		"seed": int(a["id"]), "nose": Color(0.9, 0.6, 0.6)}
	var q := _quadruped(vis, p, col, WHITE, "white_chest" if r.randf() < 0.4 else "solid")
	# Patas traseras grandes.
	for x in [-1.0, 1.0]:
		_e(vis, Vector3(0.08, 0.12, 0.2), col, Vector3(x * 0.09, 0.08, 0.08))
	_extras(vis, a, q, 0.2, 0.3)
	return q["legs"]


static func _hoofed(vis: Node3D, a: Dictionary) -> Array:
	var sp: String = a["species"]
	var r := _rng(a, 29)
	var p: Dictionary
	var col: Color
	var second: Color
	var pat := "solid"
	match sp:
		"cabra":
			col = [WHITE, Color(0.55, 0.38, 0.22), Color(0.25, 0.22, 0.2), Color(0.7, 0.55, 0.4)][r.randi() % 4]
			second = WHITE
			pat = "white_chest" if r.randf() < 0.3 else "solid"
			p = {"len": 0.75, "w": 0.3, "h": 0.34, "leg": 0.42, "leg_t": 0.06, "head": 0.22, "snout": 0.14, "snout_w": 0.6,
				"ears": "side", "ear_s": 1.0, "tail": "short_up", "tail_len": 0.12, "neck": 0.24, "neck_angle": 0.7, "head_tilt": 0.25,
				"horns": true, "beard": true, "hoof": true}
		"burro":
			col = [Color(0.52, 0.5, 0.48), Color(0.4, 0.35, 0.3), Color(0.6, 0.58, 0.55), Color(0.3, 0.25, 0.22)][r.randi() % 4]
			second = Color(0.92, 0.9, 0.86)
			pat = "mask"
			p = {"len": 1.0, "w": 0.42, "h": 0.46, "leg": 0.62, "leg_t": 0.09, "head": 0.3, "snout": 0.3, "snout_w": 0.62,
				"ears": "donkey", "ear_s": 1.0, "tail": "tuft", "tail_len": 0.45, "neck": 0.34, "neck_angle": 0.95, "head_tilt": 0.35,
				"mane": true, "hoof": true, "belly": true}
		_:  # caballo
			col = [Color(0.45, 0.28, 0.15), Color(0.2, 0.15, 0.12), Color(0.85, 0.82, 0.78), Color(0.65, 0.42, 0.22), Color(0.55, 0.5, 0.45)][r.randi() % 5]
			second = col.darkened(0.45)
			p = {"len": 1.25, "w": 0.46, "h": 0.52, "leg": 0.92, "leg_t": 0.1, "head": 0.3, "snout": 0.42, "snout_w": 0.6,
				"ears": "pointy", "ear_s": 0.9, "tail": "horse", "tail_len": 0.75, "neck": 0.5, "neck_angle": 0.8, "head_tilt": 0.35,
				"mane": true, "hoof": true, "tail_col": col.darkened(0.45), "mane_col": col.darkened(0.45)}
	p["seed"] = int(a["id"])
	var q := _quadruped(vis, p, col, second, pat)
	_extras(vis, a, q, p["w"], p["len"])
	return q["legs"]


static func _hedgehog(vis: Node3D) -> void:
	var brown := Color(0.4, 0.32, 0.22)
	_e(vis, Vector3(0.3, 0.2, 0.36), brown, Vector3(0, 0.12, 0))
	for i in 18:
		var ang := float(i) / 18.0 * TAU
		var y := 0.15 + 0.06 * sin(i * 1.7)
		_k(vis, Vector3(0.05, 0.12, 0.05), brown.darkened(0.35), Vector3(cos(ang) * 0.11, y + 0.05, sin(ang) * 0.14 + 0.02),
			Vector3(sin(ang) * 0.6, 0, -cos(ang) * 0.6))
	_e(vis, Vector3(0.14, 0.12, 0.16), Color(0.75, 0.65, 0.52), Vector3(0, 0.09, -0.18))
	_e(vis, Vector3(0.04, 0.04, 0.04), BLACK, Vector3(0, 0.08, -0.27))
	for x in [-0.04, 0.04]:
		_e(vis, Vector3(0.025, 0.025, 0.02), BLACK, Vector3(x, 0.12, -0.23))


static func _bird(vis: Node3D) -> void:
	var brown := Color(0.55, 0.38, 0.22)
	_e(vis, Vector3(0.18, 0.3, 0.2), brown, Vector3(0, 0.25, 0), Vector3(0.25, 0, 0))
	_e(vis, Vector3(0.14, 0.2, 0.12), Color(0.85, 0.75, 0.6), Vector3(0, 0.22, -0.07))
	_e(vis, Vector3(0.14, 0.14, 0.14), brown.lightened(0.15), Vector3(0, 0.44, -0.02))
	_k(vis, Vector3(0.05, 0.08, 0.05), Color(0.95, 0.75, 0.2), Vector3(0, 0.42, -0.11), Vector3(-PI / 2 - 0.4, 0, 0))
	for x in [-1.0, 1.0]:
		_e(vis, Vector3(0.03, 0.03, 0.02), BLACK, Vector3(x * 0.045, 0.46, -0.07))
		# Un ala caída: está herida.
		_e(vis, Vector3(0.06, 0.24, 0.2), brown.darkened(0.25), Vector3(x * 0.11, 0.24 - (0.06 if x > 0 else 0.0), 0.03), Vector3(0.2, 0, x * (0.7 if x > 0 else 0.1)))
		_c(vis, Vector3(0.02, 0.1, 0.02), Color(0.9, 0.75, 0.2), Vector3(x * 0.04, 0.05, 0))
	_e(vis, Vector3(0.1, 0.03, 0.16), brown.darkened(0.3), Vector3(0, 0.12, 0.14), Vector3(-0.3, 0, 0))


static func _tortoise(vis: Node3D) -> void:
	var shell := Color(0.42, 0.38, 0.2)
	_e(vis, Vector3(0.38, 0.22, 0.44), shell, Vector3(0, 0.12, 0))
	for i in 5:
		_e(vis, Vector3(0.1, 0.05, 0.1), shell.lightened(0.15), Vector3((i % 3 - 1) * 0.09, 0.22, (i / 3 - 0.5) * 0.14))
	var skin := Color(0.5, 0.48, 0.32)
	_e(vis, Vector3(0.1, 0.09, 0.14), skin, Vector3(0, 0.09, -0.25))
	for x in [-0.12, 0.12]:
		for z in [-0.13, 0.13]:
			_e(vis, Vector3(0.07, 0.06, 0.08), skin, Vector3(x, 0.03, z))


# ---------------------------------------------------------------------
# Movimiento
# ---------------------------------------------------------------------

## Postura: "stand", "walk", "sit" o "sleep". phase avanza con el tiempo para mover las patas.
static func pose(node: Node3D, state: String, phase: float, delta: float) -> void:
	var vis: Node3D = node.get_node_or_null("Vis")
	if vis == null:
		return
	var legs: Array = vis.get_meta("legs", [])
	var k := clampf(delta * 8.0, 0.0, 1.0)
	var target_y := 0.0
	var target_tilt := 0.0
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
	var sc: float = vis.get_meta("base_scale", 1.0)
	match state:
		"walk":
			target_y = absf(sin(phase)) * 0.03 * sc
		"sit":
			target_tilt = 0.3  # delante arriba
			target_y = -0.03 * sc
		"sleep":
			target_y = -0.18 * sc
	vis.position.y = lerpf(vis.position.y, target_y, k)
	vis.rotation.x = lerpf(vis.rotation.x, target_tilt, k)


## Pequeño movimiento para que parezcan vivos (animales en la calle).
static func animate(node: Node3D, t: float, seed: int) -> void:
	var vis: Node3D = node.get_node_or_null("Vis")
	if vis == null:
		return
	vis.rotation.y = sin(t * 0.6 + seed) * 0.7
	vis.position.y = absf(sin(t * 2.5 + seed)) * 0.03
