class_name Level
extends Node3D
## El patio de la protectora y las reglas de una jornada.
## Todo lo que decide la partida (dinero, adopciones, fugas...) lo calcula
## el anfitrión y se reparte a los demás por RPC.

const DAY_LENGTH := 180.0
const FENCE := 14.0           # medio lado del patio vallado
const GATE_HALF := 2.5        # media anchura de la puerta (lado norte)
const ESCAPE_GRACE := 8.0     # segundos fuera antes de darlo por perdido
const GRAB_RANGE := 2.0
const STATION_RANGE := 1.9
const STATION_TIME := 2.5

const BATH_POS := Vector3(-9, 0, 7)
const FOOD_POS := Vector3(9, 0, 7)
const DESK_POS := Vector3(0, 0, -10)
const ARRIVAL_POS := Vector3(0, 0.5, -12)
const MUD_SPOTS: Array[Vector3] = [Vector3(-5, 0, -3), Vector3(6, 0, -6), Vector3(2, 0, 9)]
const MUD_RADIUS := 1.6

var players_root: Node3D
var dogs_root: Node3D
var hud: Hud
var camera: Camera3D

var _player_spawner: MultiplayerSpawner
var _dog_spawner: MultiplayerSpawner
var _desk_label: Label3D

# --- Estado del anfitrión ---
var _rng := RandomNumberGenerator.new()
var _session_started := false
var _running := false
var _day := 1
var _time_left := DAY_LENGTH
var _money := 0
var _reputation := 50
var _adopters: Array[Dictionary] = []
var _next_dog_id := 1
var _next_adopter_id := 1
var _returns_tomorrow: Array[Dictionary] = []
var _day_stats := {}
var _arrival_timer := 0.0
var _adopter_timer := 0.0
var _sync_timer := 0.0
var _slots := {}  # peer_id -> índice de color

# --- Estado replicado para la interfaz de cada cliente ---
var _day_running_local := false


static func is_inside_fence(p: Vector3) -> bool:
	return absf(p.x) < FENCE and absf(p.z) < FENCE


func _ready() -> void:
	_rng.randomize()
	_build_world()

	players_root = Node3D.new()
	players_root.name = "Players"
	add_child(players_root)
	dogs_root = Node3D.new()
	dogs_root.name = "Dogs"
	add_child(dogs_root)

	_player_spawner = MultiplayerSpawner.new()
	_player_spawner.name = "PlayerSpawner"
	_player_spawner.spawn_path = NodePath("../Players")
	_player_spawner.spawn_function = _spawn_player
	add_child(_player_spawner)

	_dog_spawner = MultiplayerSpawner.new()
	_dog_spawner.name = "DogSpawner"
	_dog_spawner.spawn_path = NodePath("../Dogs")
	_dog_spawner.spawn_function = _spawn_dog
	add_child(_dog_spawner)

	hud = Hud.new()
	add_child(hud)
	hud.next_day_pressed.connect(_on_next_day_pressed)
	hud.visible = false

	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)


# =====================================================================
# Mundo
# =====================================================================

func _build_world() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.55, 0.75, 0.9)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.75, 0.78, 0.85)
	e.ambient_light_energy = 0.6
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = e
	add_child(env)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -35, 0)
	sun.shadow_enabled = true
	sun.light_energy = 1.1
	add_child(sun)

	# Suelo exterior (césped) e interior (tierra batida).
	var ground := Shapes.wall(Vector3(80, 1, 80), Vector3(0, -0.5, 0), Color(0.42, 0.66, 0.32))
	add_child(ground)
	add_child(Shapes.box(Vector3(FENCE * 2, 0.02, FENCE * 2), Color(0.78, 0.7, 0.55), Vector3(0, 0.01, 0)))

	# Valla con una puerta en el lado norte.
	var fence_col := Color(0.55, 0.38, 0.22)
	var h := 1.1
	add_child(Shapes.wall(Vector3(FENCE * 2 + 0.4, h, 0.3), Vector3(0, h / 2, FENCE), fence_col))
	add_child(Shapes.wall(Vector3(0.3, h, FENCE * 2), Vector3(-FENCE, h / 2, 0), fence_col))
	add_child(Shapes.wall(Vector3(0.3, h, FENCE * 2), Vector3(FENCE, h / 2, 0), fence_col))
	var seg := FENCE - GATE_HALF
	add_child(Shapes.wall(Vector3(seg, h, 0.3), Vector3(-(GATE_HALF + seg / 2), h / 2, -FENCE), fence_col))
	add_child(Shapes.wall(Vector3(seg, h, 0.3), Vector3(GATE_HALF + seg / 2, h / 2, -FENCE), fence_col))
	add_child(Shapes.label("ENTRADA", Vector3(0, 2.2, -FENCE), 60))

	# Charcos de barro: ensucian a quien los pisa.
	for m in MUD_SPOTS:
		add_child(Shapes.cylinder(MUD_RADIUS, 0.04, Dog.MUD_COLOR, m + Vector3(0, 0.03, 0)))

	# Estaciones.
	add_child(Shapes.cylinder(1.3, 0.5, Color(0.85, 0.9, 0.95), BATH_POS + Vector3(0, 0.25, 0)))
	add_child(Shapes.cylinder(1.1, 0.06, Color(0.4, 0.7, 1.0), BATH_POS + Vector3(0, 0.52, 0)))
	add_child(Shapes.label("BAÑO", BATH_POS + Vector3(0, 2.0, 0), 60))

	add_child(Shapes.cylinder(0.7, 0.25, Color(0.85, 0.2, 0.2), FOOD_POS + Vector3(0, 0.12, 0)))
	add_child(Shapes.cylinder(0.55, 0.05, Color(0.6, 0.4, 0.2), FOOD_POS + Vector3(0, 0.26, 0)))
	add_child(Shapes.label("COMEDERO", FOOD_POS + Vector3(0, 2.0, 0), 60))

	add_child(Shapes.wall(Vector3(4, 1.0, 0.8), DESK_POS + Vector3(0, 0.5, -1.4), Color(0.3, 0.45, 0.7)))
	_desk_label = Shapes.label("ADOPCIONES", DESK_POS + Vector3(0, 2.4, -1.4), 60)
	add_child(_desk_label)

	camera = Camera3D.new()
	camera.fov = 50
	camera.position = Vector3(0, 22, 16)
	add_child(camera)
	camera.look_at(Vector3.ZERO)


func _process(delta: float) -> void:
	_update_camera(delta)
	if multiplayer.is_server() and _running:
		_host_tick(delta)


func _update_camera(delta: float) -> void:
	var center := Vector3.ZERO
	var n := 0
	for p in players_root.get_children():
		center += (p as Node3D).global_position
		n += 1
	if n > 0:
		center /= n
	center = center.lerp(Vector3.ZERO, 0.35)
	var desired := center + Vector3(0, 22, 16)
	camera.position = camera.position.lerp(desired, clampf(delta * 3.0, 0.0, 1.0))


func input_enabled() -> bool:
	return _day_running_local


func get_player(peer: int) -> Player:
	return players_root.get_node_or_null(str(peer)) as Player


func dogs() -> Array[Dog]:
	var out: Array[Dog] = []
	for d in dogs_root.get_children():
		if d is Dog and not d.is_queued_for_deletion():
			out.append(d)
	return out


# =====================================================================
# Aparición de jugadores y perros (MultiplayerSpawner)
# =====================================================================

func _spawn_player(data: Dictionary) -> Node:
	var p := Player.create(data["peer"], data["slot"])
	p.position = Vector3(-3 + data["slot"] * 2.0, 0.1, 4)
	p.level = self
	return p


func _spawn_dog(data: Dictionary) -> Node:
	var d := Dog.create(data)
	d.level = self
	return d


# =====================================================================
# Sesión (solo anfitrión)
# =====================================================================

## Llamado por Main en el anfitrión cuando arranca la partida.
func start_session() -> void:
	hud.visible = true
	if not multiplayer.is_server():
		return
	_session_started = true
	_add_player(1)
	for peer in multiplayer.get_peers():
		_add_player(peer)
	_start_day()


## Llamado por Main en los clientes cuando se conectan.
func join_session() -> void:
	hud.visible = true


func _add_player(peer: int) -> void:
	if get_player(peer):
		return
	var slot := 0
	while slot in _slots.values():
		slot += 1
	_slots[peer] = slot
	_player_spawner.spawn({"peer": peer, "slot": slot})


func _on_peer_connected(peer: int) -> void:
	if multiplayer.is_server() and _session_started:
		_add_player(peer)
		_broadcast_state()
		_client_set_running.rpc_id(peer, _running)
		_toast.rpc("¡Se ha unido un voluntario!")


func _on_peer_disconnected(peer: int) -> void:
	if not multiplayer.is_server():
		return
	for d in dogs():
		if d.carried_by == peer:
			var p := get_player(peer)
			d.on_dropped(p.global_position if p else ARRIVAL_POS)
	var player := get_player(peer)
	if player:
		player.queue_free()
	_slots.erase(peer)


func _start_day() -> void:
	_time_left = DAY_LENGTH
	_adopters.clear()
	_day_stats = {"adopted": 0, "perfect": 0, "escaped": 0, "returned": 0, "rejected": 0}
	_arrival_timer = 4.0
	_adopter_timer = 6.0

	# Los devueltos del día anterior llegan por la mañana.
	for t in _returns_tomorrow:
		t["returned"] = true
		_spawn_new_dog(t)
		_reputation -= 3
		_day_stats["returned"] += 1
	if _returns_tomorrow.size() > 0:
		_toast.rpc("Hoy han devuelto %d perro(s)... :(" % _returns_tomorrow.size())
	_returns_tomorrow.clear()

	var initial := 2 + _day
	for i in initial:
		_spawn_new_dog()

	_running = true
	_client_set_running.rpc(true)
	_hide_summary.rpc()
	_broadcast_state()


func _spawn_new_dog(traits: Dictionary = {}) -> void:
	var t := traits.duplicate() if not traits.is_empty() else Dog.random_traits(_next_dog_id, _rng)
	t["id"] = _next_dog_id
	_next_dog_id += 1
	t["pos"] = ARRIVAL_POS + Vector3(_rng.randf_range(-2, 2), 0, _rng.randf_range(0, 2))
	_dog_spawner.spawn(t)


func _host_tick(delta: float) -> void:
	_time_left -= delta

	# Llegan perros rescatados.
	_arrival_timer -= delta
	if _arrival_timer <= 0.0:
		_arrival_timer = maxf(30.0 - _day * 2.0, 14.0)
		if dogs().size() < 10:
			_spawn_new_dog()
			_toast.rpc("¡Ha llegado un perro rescatado!")

	# Llegan adoptantes.
	_adopter_timer -= delta
	if _adopter_timer <= 0.0:
		_adopter_timer = _rng.randf_range(18.0, 30.0)
		if _adopters.size() < 3:
			_adopters.append({
				"id": _next_adopter_id,
				"size": "grande" if _rng.randf() < 0.5 else "pequeño",
				"energy": "enérgico" if _rng.randf() < 0.5 else "tranquilo",
				"patience": 75.0,
			})
			_next_adopter_id += 1

	for a in _adopters:
		a["patience"] -= delta
	var before := _adopters.size()
	_adopters = _adopters.filter(func(a: Dictionary) -> bool: return a["patience"] > 0.0)
	if _adopters.size() < before:
		_reputation -= 5 * (before - _adopters.size())
		_toast.rpc("Un adoptante se ha cansado de esperar (-5 reputación)")

	for d in dogs():
		_tick_dog(d, delta)

	_sync_timer -= delta
	if _sync_timer <= 0.0:
		_sync_timer = 0.2
		_broadcast_state()

	if _time_left <= 0.0:
		_end_day()


func _tick_dog(d: Dog, delta: float) -> void:
	if d.carried_by != 0:
		return
	var p := d.global_position

	# Barro.
	for m in MUD_SPOTS:
		if Vector2(p.x - m.x, p.z - m.z).length() < MUD_RADIUS:
			d.dirty = true

	# Fugas.
	if is_inside_fence(p):
		d.escaping = false
		d.escape_timer = 0.0
	else:
		if not d.escaping:
			_toast.rpc("¡%s se está escapando!" % d.dog_name)
		d.escaping = true
		d.escape_timer += delta
		if d.escape_timer > ESCAPE_GRACE:
			_reputation -= 8
			_day_stats["escaped"] += 1
			_toast.rpc("%s se ha escapado (-8 reputación)" % d.dog_name)
			d.queue_free()
			return

	# Estaciones.
	if _near(p, BATH_POS) and d.dirty:
		_work_station(d, delta, "bañándose...", func() -> void: d.dirty = false)
	elif _near(p, FOOD_POS) and d.hungry:
		_work_station(d, delta, "comiendo...", func() -> void:
			d.hungry = false
			d.hunger_timer = _rng.randf_range(45.0, 80.0))
	else:
		d.activity = ""
		d.station_progress = 0.0

	if _near(p, DESK_POS, 2.4) and not d.delivery_checked:
		d.delivery_checked = true
		_try_adoption(d)


func _near(a: Vector3, b: Vector3, r: float = STATION_RANGE) -> bool:
	return Vector2(a.x - b.x, a.z - b.z).length() < r


func _work_station(d: Dog, delta: float, label: String, done: Callable) -> void:
	d.activity = label
	d.station_progress += delta
	if d.station_progress >= STATION_TIME:
		done.call()
		d.activity = ""
		d.station_progress = 0.0


func _try_adoption(d: Dog) -> void:
	if _adopters.is_empty():
		_toast.rpc("No hay nadie esperando para adoptar")
		return
	if d.dirty or d.hungry:
		_reputation -= 2
		_day_stats["rejected"] += 1
		_toast.rpc("«¡Así no me lo llevo!» Báñalo y dale de comer antes (-2)")
		return

	var best: Dictionary = {}
	var best_score := -1
	for a in _adopters:
		var score := int(a["size"] == d.size) + int(a["energy"] == d.energy)
		if score > best_score:
			best_score = score
			best = a
	_adopters.erase(best)
	_day_stats["adopted"] += 1

	if best_score == 2:
		_money += 100
		_reputation += 5
		_day_stats["perfect"] += 1
		_toast.rpc("¡%s ha encontrado hogar! (+100 €, +5)" % d.dog_name)
	else:
		_money += 60
		_reputation += 1
		var return_chance := 0.5 if best_score == 1 else 0.9
		if _rng.randf() < return_chance:
			_returns_tomorrow.append(d.traits())
		_toast.rpc("%s adoptado... pero no encaja del todo. Quizá lo devuelvan." % d.dog_name)
	d.queue_free()


func _end_day() -> void:
	_running = false
	_client_set_running.rpc(false)
	var count := dogs().size()
	var costs := count * 8
	_money -= costs
	var s := _day_stats
	var text := "Fin del día %d\n\nAdopciones: %d (perfectas: %d)\nRechazos en el mostrador: %d\nFugas: %d\nDevoluciones recibidas hoy: %d\n\nGastos de comida y cuidados: -%d € (%d perros)\nDinero: %d €   ·   Reputación: %d" % [
		_day, s["adopted"], s["perfect"], s["rejected"], s["escaped"], s["returned"],
		costs, count, _money, _reputation]
	var over := _reputation <= 0
	if over:
		text += "\n\nLa protectora ha perdido la confianza del pueblo y cierra sus puertas."
	_show_summary.rpc(text, over)
	_broadcast_state()


func _on_next_day_pressed() -> void:
	if not multiplayer.is_server():
		return
	if _reputation <= 0:
		_reset_game()
	else:
		_day += 1  # los perros que no se adoptaron siguen en el refugio
	_start_day()


func _reset_game() -> void:
	_day = 1
	_money = 0
	_reputation = 50
	_returns_tomorrow.clear()
	for d in dogs():
		d.queue_free()


# =====================================================================
# Interacción: coger y soltar
# =====================================================================

func send_interact() -> void:
	if multiplayer.is_server():
		_handle_interact(1)
	else:
		_rpc_interact.rpc_id(1)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_interact() -> void:
	if multiplayer.is_server():
		_handle_interact(multiplayer.get_remote_sender_id())


func _handle_interact(peer: int) -> void:
	if not _running:
		return
	var p := get_player(peer)
	if p == null:
		return
	for d in dogs():
		if d.carried_by == peer:
			var drop := p.global_position + p.forward() * 1.1
			drop.y = 0.3
			d.on_dropped(drop)
			return
	var nearest: Dog = null
	var best := GRAB_RANGE
	for d in dogs():
		if d.carried_by != 0:
			continue
		var dist := Vector2(d.global_position.x - p.global_position.x, d.global_position.z - p.global_position.z).length()
		if dist < best:
			best = dist
			nearest = d
	if nearest:
		nearest.on_grabbed(peer)


func dog_slipped(d: Dog) -> void:
	var p := get_player(d.carried_by)
	var at := (p.global_position if p else d.global_position) + Vector3(_rng.randf_range(-1.5, 1.5), 0.3, _rng.randf_range(-1.5, 1.5))
	d.on_dropped(at)
	_toast.rpc("¡%s se ha escurrido de los brazos!" % d.dog_name)


# =====================================================================
# Sincronización hacia los clientes
# =====================================================================

func _broadcast_state() -> void:
	var state := {
		"day": _day,
		"time_left": maxf(_time_left, 0.0),
		"money": _money,
		"reputation": _reputation,
		"adopters": _adopters.duplicate(true),
		"players": players_root.get_child_count(),
	}
	_receive_state.rpc(state)


@rpc("authority", "call_local", "unreliable_ordered")
func _receive_state(state: Dictionary) -> void:
	hud.show_state(state)
	var parts: PackedStringArray = ["ADOPCIONES"]
	for a: Dictionary in state["adopters"]:
		parts.append("%s · %s" % [a["size"], a["energy"]])
	_desk_label.text = "\n".join(parts)


@rpc("authority", "call_local", "reliable")
func _toast(text: String) -> void:
	hud.toast(text)


@rpc("authority", "call_local", "reliable")
func _client_set_running(value: bool) -> void:
	_day_running_local = value


@rpc("authority", "call_local", "reliable")
func _show_summary(text: String, game_over: bool) -> void:
	var is_host := multiplayer.is_server()
	var label := ("Volver a empezar" if game_over else "Siguiente día") if is_host else "Esperando al anfitrión..."
	hud.show_summary(text, label, is_host)


@rpc("authority", "call_local", "reliable")
func _hide_summary() -> void:
	hud.hide_summary()
