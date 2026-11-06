class_name Player
extends CharacterBody3D
## Voluntario de la protectora. Cada cliente mueve el suyo (tiene la autoridad
## sobre su posición) y pide al anfitrión coger o soltar animales.

const SPEED := 6.0
const DASH_SPEED := 14.0
const DASH_TIME := 0.18
const DASH_COOLDOWN := 0.9
const ACCEL := 45.0
const GRAVITY := 20.0

const COLORS: Array[Color] = [
	Color(0.95, 0.45, 0.3),
	Color(0.3, 0.6, 0.95),
	Color(0.45, 0.85, 0.4),
	Color(0.95, 0.8, 0.25),
]

var peer_id := 1
var slot := 0
var level: Level

var _dash_left := 0.0
var _dash_cd := 0.0
var _dash_dir := Vector3.ZERO


static func create(p_peer: int, p_slot: int) -> Player:
	var p := Player.new()
	p.peer_id = p_peer
	p.slot = p_slot
	p.name = str(p_peer)
	p.collision_layer = 2
	p.collision_mask = 1 | 2 | 4

	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.4
	cap.height = 1.6
	col.shape = cap
	col.position.y = 0.8
	p.add_child(col)

	var body := Node3D.new()
	body.name = "Visual"
	var color := COLORS[p_slot % COLORS.size()]
	body.add_child(Shapes.capsule(0.4, 1.6, color, Vector3(0, 0.8, 0)))
	body.add_child(Shapes.box(Vector3(0.5, 0.15, 0.25), Color(0.15, 0.15, 0.15), Vector3(0, 1.25, -0.35)))
	p.add_child(body)
	p.add_child(Shapes.label("J%d" % (p_slot + 1), Vector3(0, 2.2, 0), 40))

	var sync := MultiplayerSynchronizer.new()
	sync.name = "Sync"
	var cfg := SceneReplicationConfig.new()
	for prop in [".:position", ".:rotation"]:
		cfg.add_property(NodePath(prop))
		cfg.property_set_replication_mode(NodePath(prop), SceneReplicationConfig.REPLICATION_MODE_ALWAYS)
	sync.replication_config = cfg
	p.add_child(sync)

	p.set_multiplayer_authority(p_peer, true)
	return p


func _physics_process(delta: float) -> void:
	if not is_multiplayer_authority():
		return
	if level and not level.input_enabled():
		velocity = Vector3.ZERO
		return

	var input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var dir := Vector3(input.x, 0, input.y)

	_dash_cd = maxf(_dash_cd - delta, 0.0)
	if Input.is_action_just_pressed("dash") and _dash_cd <= 0.0:
		_dash_dir = dir.normalized() if dir.length() > 0.1 else -transform.basis.z
		_dash_left = DASH_TIME
		_dash_cd = DASH_COOLDOWN

	var target := dir * SPEED
	if _dash_left > 0.0:
		_dash_left -= delta
		target = _dash_dir * DASH_SPEED
		velocity.x = target.x
		velocity.z = target.z
	else:
		velocity.x = move_toward(velocity.x, target.x, ACCEL * delta)
		velocity.z = move_toward(velocity.z, target.z, ACCEL * delta)

	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		velocity.y = 0.0
	move_and_slide()

	var flat := Vector3(velocity.x, 0, velocity.z)
	if flat.length() > 0.5:
		rotation.y = lerp_angle(rotation.y, atan2(-flat.x, -flat.z), 15.0 * delta)

	if Input.is_action_just_pressed("interact") and level:
		level.send_interact()


func forward() -> Vector3:
	return -global_transform.basis.z
