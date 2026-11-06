class_name PlayerController
extends CharacterBody3D
## Jugador en primera persona, con tercera persona opcional (V).
## La velocidad depende del vehículo que se use.

const MOUSE_SENS := 0.0025
const GRAVITY := 20.0
const JUMP := 6.5

var ui_open := false
var third_person := false

var _yaw := 0.0
var _pitch := 0.0
var _head: Node3D
var _cam: Camera3D
var _arm: SpringArm3D
var _body_visual: Node3D
var _vehicle_visual: Node3D
var _current_vehicle := ""
var _carried_visual: Node3D

## Bajo techo (lo comprueba un rayo hacia arriba) y tipo de suelo que pisa: lo usan los pasos y el ambiente.
var indoor := false
var surface := "hierba"
var _step_dist := 0.0
var _was_on_floor := true
var _air_time := 0.0
var _probe_t := 0.0
var _engine: AudioStreamPlayer        # motor del vehículo (marcha)
var _engine_idle: AudioStreamPlayer   # ralentí (solo el coche)


func _ready() -> void:
	add_to_group("player")
	collision_layer = 2
	collision_mask = 1
	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.35
	cap.height = 1.75
	col.shape = cap
	col.position.y = 0.875
	add_child(col)

	_body_visual = Node3D.new()
	add_child(_body_visual)
	_body_visual.add_child(Shapes.capsule(0.35, 1.75, Color(0.2, 0.55, 0.45), Vector3(0, 0.875, 0)))
	_body_visual.add_child(Shapes.box(Vector3(0.45, 0.5, 0.3), Color(0.9, 0.55, 0.2), Vector3(0, 1.15, 0.25)))  # mochila

	_carried_visual = Node3D.new()
	_carried_visual.position = Vector3(0, 0, 0)
	add_child(_carried_visual)

	_head = Node3D.new()
	_head.position.y = 1.62
	add_child(_head)
	_arm = SpringArm3D.new()
	_arm.spring_length = 0.0
	_arm.collision_mask = 1
	_arm.margin = 0.2
	_head.add_child(_arm)
	_cam = Camera3D.new()
	_cam.fov = 75
	_cam.near = 0.05
	_arm.add_child(_cam)
	_cam.current = true
	_apply_camera_mode()


func _unhandled_input(event: InputEvent) -> void:
	if ui_open:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_yaw -= event.relative.x * MOUSE_SENS
		_pitch = clampf(_pitch - event.relative.y * MOUSE_SENS, -1.4, 1.3)
	elif event.is_action_pressed("camera"):
		third_person = not third_person
		_apply_camera_mode()


func _apply_camera_mode() -> void:
	_arm.spring_length = 4.5 if third_person else 0.0
	_arm.position = Vector3(0.7, 0.6, 0) if third_person else Vector3.ZERO
	_body_visual.visible = third_person
	_carried_visual.visible = third_person
	if _vehicle_visual:
		_vehicle_visual.visible = third_person


func _physics_process(delta: float) -> void:
	rotation.y = _yaw
	_head.rotation.x = _pitch
	_sync_vehicle()

	var speed: float = Game.vehicle()["speed"]
	var on_foot: bool = Game.s["vehicle"] == "a_pie"
	if on_foot and Input.is_action_pressed("sprint"):
		speed *= 1.6
	var input := Vector2.ZERO
	if not ui_open:
		input = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var dir := (transform.basis * Vector3(input.x, 0, input.y)).normalized()
	var accel := 30.0 if on_foot else 12.0
	velocity.x = move_toward(velocity.x, dir.x * speed, accel * delta)
	velocity.z = move_toward(velocity.z, dir.z * speed, accel * delta)
	if is_on_floor():
		velocity.y = 0.0
		if on_foot and not ui_open and Input.is_action_just_pressed("jump"):
			velocity.y = JUMP
	else:
		velocity.y -= GRAVITY * delta
	move_and_slide()
	Game.player_pos = global_position
	_sounds(delta, on_foot)


# ---------------------------------------------------------------------
# Sonido: pasos, saltos y motor
# ---------------------------------------------------------------------

func _sounds(delta: float, on_foot: bool) -> void:
	_probe_t -= delta
	if _probe_t <= 0.0:
		_probe_t = 0.25
		indoor = _roof_above()
		surface = surface_at(global_position, indoor)
	var hspeed := Vector2(velocity.x, velocity.z).length()
	var floor := is_on_floor()
	if not floor:
		_air_time += delta
	if on_foot:
		if floor and not _was_on_floor and _air_time > 0.35:
			Sound.play("aterrizaje", -6.0)
			_step_dist = 0.0
		if floor and hspeed > 0.8:
			_step_dist += hspeed * delta
			var stride := 1.9 if hspeed > 6.0 else 1.5
			if _step_dist >= stride:
				_step_dist = 0.0
				Sound.play("pasos_" + surface, -10.0 if surface != "hierba" else -6.0, 0.08, "Efectos", 0.32, 0)
		if Input.is_action_just_pressed("jump") and floor and not ui_open:
			Sound.play("salto", -10.0, 0.05, "Efectos", 0.4)
	if floor:
		_air_time = 0.0
	_was_on_floor = floor
	_update_engine(hspeed)


func _roof_above() -> bool:
	var space := get_world_3d().direct_space_state
	if space == null:
		return false
	var from := global_position + Vector3(0, 1.0, 0)
	var q := PhysicsRayQueryParameters3D.create(from, from + Vector3(0, 7.0, 0), 1, [get_rid()])
	return not space.intersect_ray(q).is_empty()


## Suelo en una posición del mapa: baldosa bajo techo, tierra en el refugio y en el campo,
## asfalto en carreteras y plaza, hierba en el resto.
static func surface_at(p: Vector3, under_roof: bool) -> String:
	if under_roof:
		return "baldosa"
	if Game.s.get("land", "") != "":
		var base: Vector3 = Game.s["land_pos"]
		var half := Game.land_size() / 2.0
		if absf(p.x - base.x) <= half and absf(p.z - base.z) <= half:
			return "tierra"
	if absf(p.x) < 10 and absf(p.z) < 10:
		return "asfalto"
	if absf(p.x) < 4 and p.z > -160 and p.z < 35:
		return "asfalto"
	if absf(p.z) < 4 and absf(p.x) < 160:
		return "asfalto"
	for r in [-110.0, 110.0]:
		if absf(p.z - r) < 3 and absf(p.x) < 120:
			return "asfalto"
		if absf(p.x - r) < 3 and absf(p.z) < 120:
			return "asfalto"
	if absf(p.x) > 75 or absf(p.z) > 75:
		return "tierra"
	return "hierba"


func _update_engine(hspeed: float) -> void:
	var v: String = _current_vehicle
	if _engine == null:
		return
	var max_speed: float = maxf(1.0, Game.vehicle()["speed"])
	var t := clampf(hspeed / max_speed, 0.0, 1.0)
	match v:
		"bici":
			_engine.volume_db = lerpf(-60.0, -8.0, clampf(t * 2.0, 0.0, 1.0))
			_engine.pitch_scale = lerpf(0.8, 1.2, t)
		"coche":
			_engine.volume_db = lerpf(-30.0, -6.0, t)
			_engine.pitch_scale = lerpf(0.75, 1.35, t)
			if _engine_idle:
				_engine_idle.volume_db = lerpf(-6.0, -40.0, clampf(t * 3.0, 0.0, 1.0))
		_:
			_engine.volume_db = lerpf(-10.0, -4.0, t)
			_engine.pitch_scale = lerpf(0.7, 1.3, t)


func _set_engine(v: String) -> void:
	for e in [_engine, _engine_idle]:
		if e:
			e.queue_free()
	_engine = null
	_engine_idle = null
	match v:
		"bici":
			_engine = Sound.loop("bici_rodando")
		"coche":
			Sound.play("puerta_coche", -6.0)
			Sound.play("coche_arranque", -4.0)
			_engine = Sound.loop("coche_marcha")
			_engine_idle = Sound.loop("coche_ralenti")
		"furgo", "furgon":
			Sound.play("puerta_coche", -6.0)
			Sound.play("coche_arranque", -4.0, 0.0)
			_engine = Sound.loop("furgoneta_diesel")


func _sync_vehicle() -> void:
	var v: String = Game.s.get("vehicle", "a_pie")
	if v == _current_vehicle:
		return
	if _current_vehicle != "" or v != "a_pie":
		_set_engine(v)
	_current_vehicle = v
	if _vehicle_visual:
		_vehicle_visual.queue_free()
		_vehicle_visual = null
	if v == "a_pie":
		return
	_vehicle_visual = Node3D.new()
	add_child(_vehicle_visual)
	match v:
		"bici":
			_vehicle_visual.add_child(Shapes.box(Vector3(0.1, 0.7, 1.4), Color(0.8, 0.15, 0.15), Vector3(0, 0.45, 0)))
			_vehicle_visual.add_child(Shapes.box(Vector3(0.8, 0.5, 0.9), Color(0.3, 0.3, 0.3), Vector3(0, 0.4, 1.3)))
		"coche":
			_vehicle_visual.add_child(Shapes.box(Vector3(1.8, 0.9, 3.8), Color(0.75, 0.75, 0.8), Vector3(0, 0.6, 0.6)))
			_vehicle_visual.add_child(Shapes.box(Vector3(1.6, 0.7, 2.0), Color(0.5, 0.65, 0.8), Vector3(0, 1.3, 0.8)))
		"furgo":
			_vehicle_visual.add_child(Shapes.box(Vector3(2.0, 2.0, 4.6), Color(0.95, 0.95, 0.95), Vector3(0, 1.1, 1.0)))
		"furgon":
			_vehicle_visual.add_child(Shapes.box(Vector3(2.2, 2.5, 6.0), Color(0.95, 0.95, 0.95), Vector3(0, 1.35, 1.6)))
			_vehicle_visual.add_child(Shapes.box(Vector3(2.25, 0.4, 3.0), Color(0.2, 0.6, 0.45), Vector3(0, 1.4, 2.4)))
	_apply_camera_mode()


func look_dir() -> Vector3:
	return -_cam.global_transform.basis.z


func camera() -> Camera3D:
	return _cam
