class_name Dog
extends CharacterBody3D
## Perro de la protectora. Solo el anfitrión lo simula; los clientes reciben
## posición y estado a través del MultiplayerSynchronizer.
## La animación (patas, cola, estirarse, aplastarse) es procedural y se calcula
## en cada equipo a partir del estado sincronizado.

const GRAVITY := 20.0
const THROW_GRAVITY := 18.0
const NAMES := ["Toby", "Luna", "Coco", "Rocky", "Lola", "Max", "Nala", "Bruno",
	"Kira", "Thor", "Canela", "Chispa", "Lucas", "Mía", "Duna", "Rufo", "Pipa", "Simba"]
const MUD_COLOR := Color(0.36, 0.25, 0.15)

# Rasgos fijos (llegan en los datos de aparición, no hace falta sincronizarlos).
var dog_id := 0
var dog_name := ""
var size := "pequeño"      # "pequeño" | "grande"
var energy := "tranquilo"  # "tranquilo" | "enérgico"
var coat := Color.WHITE

# Estado sincronizado.
var dirty := true
var hungry := true
var returned := false
var carried_by := 0
var escaping := false
var airborne := false
var activity := ""

# Estado solo del anfitrión.
var level: Level
var hunger_timer := 0.0
var poop_timer := -1.0
var station_progress := 0.0
var delivery_checked := false
var escape_timer := 0.0
var wiggle_timer := 0.0
var thrown_by := 0
var fly_time := 0.0
var fly_velocity := Vector3.ZERO
var _target := Vector3.ZERO
var _think := 0.0
var _running_away := false

# Visual (local en cada equipo).
var _label: Label3D
var _mats: Array[StandardMaterial3D] = []
var _visual: Node3D
var _body: Node3D
var _head: Node3D
var _tail: Node3D
var _legs: Array[Node3D] = []
var _ears: Array[Node3D] = []
var _base_scale := 1.0
var _phase := 0.0
var _last_pos := Vector3.ZERO
var _was_airborne := false
var _squash := 0.0


static func random_traits(id: int, rng: RandomNumberGenerator) -> Dictionary:
	return {
		"id": id,
		"name": NAMES[rng.randi() % NAMES.size()],
		"size": "grande" if rng.randf() < 0.45 else "pequeño",
		"energy": "enérgico" if rng.randf() < 0.5 else "tranquilo",
		"coat": Color.from_hsv(rng.randf_range(0.05, 0.12), rng.randf_range(0.2, 0.7), rng.randf_range(0.45, 0.95)).to_html(),
		"returned": false,
	}


static func create(data: Dictionary) -> Dog:
	var d := Dog.new()
	d.dog_id = data["id"]
	d.dog_name = data["name"]
	d.size = data["size"]
	d.energy = data["energy"]
	d.coat = Color.html(data["coat"])
	d.returned = data.get("returned", false)
	d.name = "Dog_%d" % d.dog_id
	d.position = data.get("pos", Vector3.ZERO)
	d.collision_layer = 4
	d.collision_mask = 1 | 2 | 4

	var s := 1.35 if d.size == "grande" else 0.85
	d._base_scale = s
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.6, 0.6, 1.0) * s
	col.shape = shape
	col.position.y = 0.3 * s
	d.add_child(col)

	d._build_visual()
	d._label = Shapes.label("", Vector3(0, 1.7 * s, 0), 36)
	d.add_child(d._label)

	var sync := MultiplayerSynchronizer.new()
	sync.name = "Sync"
	var cfg := SceneReplicationConfig.new()
	for prop in [".:position", ".:rotation"]:
		cfg.add_property(NodePath(prop))
		cfg.property_set_replication_mode(NodePath(prop), SceneReplicationConfig.REPLICATION_MODE_ALWAYS)
	for prop in [".:dirty", ".:hungry", ".:returned", ".:carried_by", ".:escaping", ".:airborne", ".:activity"]:
		cfg.add_property(NodePath(prop))
		cfg.property_set_replication_mode(NodePath(prop), SceneReplicationConfig.REPLICATION_MODE_ON_CHANGE)
	sync.replication_config = cfg
	d.add_child(sync)
	return d


## Esqueleto sencillo con pivotes, para poder animar patas, cabeza y cola.
func _build_visual() -> void:
	_visual = Node3D.new()
	_visual.scale = Vector3.ONE * _base_scale
	add_child(_visual)

	_body = Node3D.new()
	_body.position = Vector3(0, 0.45, 0)
	_visual.add_child(_body)
	_add_part(_body, Vector3(0.55, 0.45, 0.9), coat, Vector3.ZERO)

	_head = Node3D.new()
	_head.position = Vector3(0, 0.15, -0.42)
	_body.add_child(_head)
	_add_part(_head, Vector3(0.42, 0.4, 0.4), coat, Vector3(0, 0.15, -0.1))
	_head.add_child(Shapes.box(Vector3(0.12, 0.12, 0.12), Color(0.1, 0.1, 0.1), Vector3(0, 0.15, -0.32)))
	for x in [-0.12, 0.12]:
		_head.add_child(Shapes.box(Vector3(0.07, 0.07, 0.02), Color(0.05, 0.05, 0.05), Vector3(x, 0.24, -0.31)))
		var ear := Node3D.new()
		ear.position = Vector3(x * 1.25, 0.33, -0.02)
		_head.add_child(ear)
		_add_part(ear, Vector3(0.1, 0.2, 0.08), coat.darkened(0.3), Vector3(0, 0.08, 0))
		_ears.append(ear)

	_tail = Node3D.new()
	_tail.position = Vector3(0, 0.15, 0.45)
	_body.add_child(_tail)
	_add_part(_tail, Vector3(0.08, 0.08, 0.38), coat.darkened(0.2), Vector3(0, 0.08, 0.17))
	_tail.rotation.x = 0.5

	for x in [-0.18, 0.18]:
		for z in [-0.3, 0.3]:
			var hip := Node3D.new()
			hip.position = Vector3(x, -0.18, z)
			_body.add_child(hip)
			_add_part(hip, Vector3(0.12, 0.3, 0.12), coat.darkened(0.15), Vector3(0, -0.12, 0))
			_legs.append(hip)


func _add_part(parent: Node3D, part_size: Vector3, color: Color, pos: Vector3) -> void:
	var mi := Shapes.box(part_size, color, pos)
	parent.add_child(mi)
	var m := mi.material_override as StandardMaterial3D
	m.set_meta("base", color)
	_mats.append(m)


func traits() -> Dictionary:
	return {"id": dog_id, "name": dog_name, "size": size, "energy": energy,
		"coat": coat.to_html(), "returned": returned}


func _ready() -> void:
	hunger_timer = randf_range(40.0, 70.0)
	_target = position
	_last_pos = position
	_phase = randf() * TAU


# =====================================================================
# Visual (todos los equipos)
# =====================================================================

func _process(delta: float) -> void:
	for m in _mats:
		var base: Color = m.get_meta("base")
		m.albedo_color = base.lerp(MUD_COLOR, 0.65) if dirty else base

	var speed := Vector2(position.x - _last_pos.x, position.z - _last_pos.z).length() / maxf(delta, 0.0001)
	_last_pos = position

	if _was_airborne and not airborne:
		_squash = 1.0  # aterrizaje: se aplasta y rebota
	_was_airborne = airborne
	_squash = move_toward(_squash, 0.0, delta * 3.0)

	if carried_by != 0:
		_animate_carried(delta)
	elif airborne:
		_animate_flying(delta)
	elif activity != "":
		_animate_station(delta)
	else:
		_animate_walk(delta, speed)

	# Aplastarse al caer (squash & stretch).
	var sq := sin(_squash * PI) * _squash
	_visual.scale = Vector3(1.0 + sq * 0.35, 1.0 - sq * 0.4, 1.0 + sq * 0.2) * _base_scale

	_update_label()


func _animate_walk(delta: float, speed: float) -> void:
	var moving := speed > 0.3
	_phase += delta * (4.0 + speed * 3.5) if moving else delta * 2.0
	var amp := clampf(speed / 3.0, 0.0, 1.0) * 0.7
	for i in _legs.size():
		var side := 1.0 if i % 3 == 0 else -1.0  # diagonales en fase
		_legs[i].rotation.x = sin(_phase) * amp * side
	_body.position.y = 0.45 + absf(sin(_phase)) * 0.05 * amp
	_body.rotation = Vector3(0, 0, sin(_phase * 0.5) * 0.05 * amp)
	_head.rotation.x = sin(_phase * 2.0) * 0.06
	var wag := 10.0 if energy == "enérgico" else 6.0
	_tail.rotation.y = sin(Time.get_ticks_msec() * 0.001 * wag) * 0.6
	for e in _ears:
		e.rotation.x = lerpf(e.rotation.x, -0.3 * amp, delta * 8.0)


func _animate_carried(delta: float) -> void:
	# Patalea, se estira y se retuerce. Los enérgicos mucho más.
	var t := Time.get_ticks_msec() * 0.001
	var k := 1.0 if energy == "enérgico" else 0.45
	_phase += delta * 22.0 * k
	for i in _legs.size():
		_legs[i].rotation.x = sin(_phase + i * 1.3) * 1.1 * k
		_legs[i].rotation.z = cos(_phase + i) * 0.4 * k
	_body.position.y = 0.45
	_body.rotation = Vector3(sin(t * 9.0) * 0.25 * k, sin(t * 7.0) * 0.3 * k, sin(t * 13.0) * 0.45 * k)
	_head.rotation.x = -0.4 + sin(t * 11.0) * 0.3 * k
	_tail.rotation.y = sin(t * 25.0) * 0.9
	for e in _ears:
		e.rotation.x = sin(t * 15.0) * 0.6


func _animate_flying(delta: float) -> void:
	# Patas abiertas como una estrella y voltereta.
	for i in _legs.size():
		_legs[i].rotation.x = (0.9 if i < 2 else -0.9)
		_legs[i].rotation.z = (0.6 if i % 2 == 0 else -0.6)
	_body.rotation.x += delta * 9.0
	_tail.rotation.y = sin(Time.get_ticks_msec() * 0.03)
	for e in _ears:
		e.rotation.x = 1.2


func _animate_station(delta: float) -> void:
	var t := Time.get_ticks_msec() * 0.001
	for leg in _legs:
		leg.rotation = leg.rotation.lerp(Vector3.ZERO, delta * 10.0)
	_body.position.y = 0.45
	if activity.begins_with("bañ"):
		# Se sacude como si estuviera empapado.
		_body.rotation = Vector3(0, 0, sin(t * 30.0) * 0.25)
		_head.rotation.x = 0.0
	else:
		# Cabeza al plato.
		_body.rotation = Vector3.ZERO
		_head.rotation.x = 0.6 + sin(t * 12.0) * 0.15
	_tail.rotation.y = sin(t * 12.0) * 0.7


func _update_label() -> void:
	var tags: PackedStringArray = []
	if returned:
		tags.append("DEVUELTO")
	if escaping:
		tags.append("¡SE ESCAPA!")
	if activity != "":
		tags.append(activity)
	else:
		if dirty:
			tags.append("sucio")
		if hungry:
			tags.append("hambre")
	var line2 := " · ".join(tags)
	_label.text = "%s (%s, %s)%s" % [dog_name, size, energy, ("\n" + line2) if line2 != "" else ""]
	_label.modulate = Color(1, 0.4, 0.3) if escaping else Color.WHITE


# =====================================================================
# Simulación (solo anfitrión)
# =====================================================================

func _physics_process(delta: float) -> void:
	if not multiplayer.is_server():
		return
	if carried_by != 0:
		_process_carried(delta)
		return
	if airborne:
		_process_flying(delta)
		return

	collision_layer = 4
	collision_mask = 1 | 2 | 4

	if not hungry:
		hunger_timer -= delta
		if hunger_timer <= 0.0:
			hungry = true

	var speed := 0.0
	if activity == "":
		_think -= delta
		var just_left := not _running_away and not Level.is_inside_fence(position)
		if just_left or _think <= 0.0 or position.distance_to(_target) < 0.6:
			_pick_target()
		speed = 3.4 if energy == "enérgico" else 1.6
		if _running_away:
			speed = 4.2

	var to := _target - position
	to.y = 0
	var move := to.normalized() * speed if to.length() > 0.3 and speed > 0.0 else Vector3.ZERO
	velocity.x = move.x
	velocity.z = move.z
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		velocity.y = 0.0
	move_and_slide()
	if move.length() > 0.1:
		rotation.y = lerp_angle(rotation.y, atan2(-move.x, -move.z), 8.0 * delta)


func _process_carried(delta: float) -> void:
	collision_layer = 0
	collision_mask = 0
	velocity = Vector3.ZERO
	var p := level.get_player(carried_by) if level else null
	if p == null:
		carried_by = 0
		return
	global_position = p.global_position + Vector3(0, 1.5, 0) + p.forward() * 0.35
	rotation.y = p.rotation.y
	# Los enérgicos se retuercen y a veces se escurren de los brazos.
	if energy == "enérgico":
		wiggle_timer -= delta
		if wiggle_timer <= 0.0:
			level.dog_slipped(self)


func _process_flying(delta: float) -> void:
	collision_layer = 0
	collision_mask = 0
	fly_time += delta
	fly_velocity.y -= THROW_GRAVITY * delta
	global_position += fly_velocity * delta
	if fly_velocity.length() > 0.1:
		rotation.y = atan2(-fly_velocity.x, -fly_velocity.z)
	if level:
		level.try_catch(self)
	if airborne and global_position.y <= 0.05 and fly_velocity.y < 0.0:
		global_position.y = 0.05
		airborne = false
		thrown_by = 0
		_target = global_position
		_think = randf_range(0.8, 1.6)  # aturdido un momento


func throw(direction: Vector3, thrower: int) -> void:
	carried_by = 0
	airborne = true
	thrown_by = thrower
	fly_time = 0.0
	var power := 8.5 if size == "pequeño" else 6.5  # los grandes pesan más
	fly_velocity = direction.normalized() * power + Vector3.UP * 5.5
	_running_away = false


func on_grabbed(peer: int) -> void:
	carried_by = peer
	airborne = false
	activity = ""
	station_progress = 0.0
	delivery_checked = false
	_running_away = false
	wiggle_timer = randf_range(4.0, 8.0)


func on_dropped(at: Vector3) -> void:
	carried_by = 0
	position = at
	_target = at
	_think = randf_range(1.5, 3.0)


func _pick_target() -> void:
	_think = randf_range(2.0, 5.0)
	# Si está fuera de la valla, no vuelve solo: sigue alejándose.
	if not Level.is_inside_fence(position):
		_running_away = true
		var away := Vector3(position.x, 0, position.z).normalized()
		if away.length() < 0.1:
			away = Vector3.FORWARD
		_target = position + away * 15.0
		_think = 12.0
		return
	# Los enérgicos a veces se lanzan hacia la puerta.
	if energy == "enérgico" and not _running_away and randf() < 0.18:
		_running_away = true
		_target = Vector3(randf_range(-2.0, 2.0), position.y, -26.0)
		_think = 12.0
		return
	if _running_away:
		_think = 12.0
		return
	var r := 11.0
	_target = Vector3(randf_range(-r, r), position.y, randf_range(-r, r))
