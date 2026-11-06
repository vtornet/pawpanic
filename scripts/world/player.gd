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


func _ready() -> void:
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


func _sync_vehicle() -> void:
	var v: String = Game.s.get("vehicle", "a_pie")
	if v == _current_vehicle:
		return
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
