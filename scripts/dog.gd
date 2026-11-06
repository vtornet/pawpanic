class_name Dog
extends CharacterBody3D
## Perro de la protectora. Solo el anfitrión lo simula; los clientes reciben
## posición y estado a través del MultiplayerSynchronizer.

const GRAVITY := 20.0
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
var activity := ""

# Estado solo del anfitrión.
var level: Level
var hunger_timer := 0.0
var station_progress := 0.0
var delivery_checked := false
var escape_timer := 0.0
var wiggle_timer := 0.0
var _target := Vector3.ZERO
var _think := 0.0
var _running_away := false

var _label: Label3D
var _body_mat: StandardMaterial3D
var _head_mat: StandardMaterial3D
var _visual: Node3D


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
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.6, 0.6, 1.0) * s
	col.shape = shape
	col.position.y = 0.3 * s
	d.add_child(col)

	d._visual = Node3D.new()
	d._visual.scale = Vector3.ONE * s
	var body := Shapes.box(Vector3(0.55, 0.45, 0.9), d.coat, Vector3(0, 0.45, 0))
	var head := Shapes.box(Vector3(0.42, 0.4, 0.4), d.coat, Vector3(0, 0.75, -0.5))
	d._body_mat = body.material_override
	d._head_mat = head.material_override
	d._visual.add_child(body)
	d._visual.add_child(head)
	d._visual.add_child(Shapes.box(Vector3(0.12, 0.12, 0.12), Color(0.1, 0.1, 0.1), Vector3(0, 0.75, -0.72)))
	d._visual.add_child(Shapes.box(Vector3(0.1, 0.18, 0.08), d.coat.darkened(0.3), Vector3(-0.15, 1.0, -0.45)))
	d._visual.add_child(Shapes.box(Vector3(0.1, 0.18, 0.08), d.coat.darkened(0.3), Vector3(0.15, 1.0, -0.45)))
	d._visual.add_child(Shapes.box(Vector3(0.08, 0.08, 0.35), d.coat.darkened(0.2), Vector3(0, 0.65, 0.55)))
	for x in [-0.18, 0.18]:
		for z in [-0.3, 0.3]:
			d._visual.add_child(Shapes.box(Vector3(0.12, 0.25, 0.12), d.coat.darkened(0.15), Vector3(x, 0.12, z)))
	d.add_child(d._visual)

	d._label = Shapes.label("", Vector3(0, 1.7 * s, 0), 36)
	d.add_child(d._label)

	var sync := MultiplayerSynchronizer.new()
	sync.name = "Sync"
	var cfg := SceneReplicationConfig.new()
	for prop in [".:position", ".:rotation"]:
		cfg.add_property(NodePath(prop))
		cfg.property_set_replication_mode(NodePath(prop), SceneReplicationConfig.REPLICATION_MODE_ALWAYS)
	for prop in [".:dirty", ".:hungry", ".:returned", ".:carried_by", ".:escaping", ".:activity"]:
		cfg.add_property(NodePath(prop))
		cfg.property_set_replication_mode(NodePath(prop), SceneReplicationConfig.REPLICATION_MODE_ON_CHANGE)
	sync.replication_config = cfg
	d.add_child(sync)
	return d


func traits() -> Dictionary:
	return {"id": dog_id, "name": dog_name, "size": size, "energy": energy,
		"coat": coat.to_html(), "returned": returned}


func _ready() -> void:
	hunger_timer = randf_range(40.0, 70.0)
	_target = position


func _process(_delta: float) -> void:
	# Visual: se ejecuta en todos los equipos con el estado sincronizado.
	var c := coat.lerp(MUD_COLOR, 0.65) if dirty else coat
	_body_mat.albedo_color = c
	_head_mat.albedo_color = c
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


func _physics_process(delta: float) -> void:
	if not multiplayer.is_server():
		return

	if carried_by != 0:
		_process_carried(delta)
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
		if _think <= 0.0 or position.distance_to(_target) < 0.6:
			_pick_target()
		speed = 3.4 if energy == "enérgico" else 1.6
		if _running_away:
			speed = 4.2
		# Pequeño bamboleo para que parezcan vivos.
		_visual.rotation.z = sin(Time.get_ticks_msec() * 0.012 * (speed * 0.5)) * 0.08
	else:
		_visual.rotation.z = sin(Time.get_ticks_msec() * 0.03) * 0.15

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
	_visual.rotation.z = sin(Time.get_ticks_msec() * 0.04) * (0.35 if energy == "enérgico" else 0.1)
	# Los enérgicos se retuercen y a veces se escurren de los brazos.
	if energy == "enérgico":
		wiggle_timer -= delta
		if wiggle_timer <= 0.0:
			level.dog_slipped(self)


func on_grabbed(peer: int) -> void:
	carried_by = peer
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
	_visual.rotation.z = 0.0


func _pick_target() -> void:
	_think = randf_range(2.0, 5.0)
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
