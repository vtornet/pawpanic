extends Node
## Prueba de humo: juega una jornada en solitario de forma automática.
## Uso:  godot --headless -- --solo --smoke
## Imprime "SMOKE PASS" o "SMOKE FAIL: ..." y cierra.

var level: Level
var _fails: PackedStringArray = []


func run(p_level: Level) -> void:
	level = p_level
	await _wait(0.5)

	_check(level.dogs().size() >= 3, "al empezar deberían aparecer al menos 3 perros")
	_check(level.get_player(1) != null, "debería existir el jugador anfitrión")
	var player := level.get_player(1)
	var dog := level.dogs()[0]
	dog.energy = "tranquilo"  # que no se escurra durante la prueba
	dog.dirty = true
	dog.hungry = true

	# Coger.
	player.global_position = dog.global_position + Vector3(0.5, 0, 0)
	level._handle_interact(1)
	await _wait(0.1)
	_check(dog.carried_by == 1, "el perro debería estar en brazos")

	# Bañar.
	await _carry_and_drop(player, Level.BATH_POS)
	await _wait(Level.STATION_TIME + 0.6)
	_check(not dog.dirty, "el perro debería estar limpio tras el baño")

	# Dar de comer.
	await _grab(player, dog)
	await _carry_and_drop(player, Level.FOOD_POS)
	await _wait(Level.STATION_TIME + 0.6)
	_check(not dog.hungry, "el perro debería haber comido")

	# Entregar a un adoptante que encaja.
	level._adopters.clear()
	level._adopters.append({"id": 99, "size": dog.size, "energy": dog.energy, "patience": 60.0})
	var money_before := level._money
	await _grab(player, dog)
	await _carry_and_drop(player, Level.DESK_POS)
	await _wait(0.5)
	_check(level._money == money_before + 100, "la adopción perfecta debería dar 100 € (%d -> %d)" % [money_before, level._money])
	_check(not is_instance_valid(dog) or dog.is_queued_for_deletion(), "el perro adoptado debería salir del refugio")

	# Fuga: un perro fuera de la valla se pierde tras el margen.
	var runner := level.dogs()[0]
	var rep_before := level._reputation
	runner.position = Vector3(0, 0.3, -25)
	await _wait(Level.ESCAPE_GRACE + 0.6)
	_check(level._reputation < rep_before, "una fuga debería restar reputación")

	# Fin de jornada y siguiente día.
	level._time_left = 0.01
	await _wait(0.3)
	_check(not level._running, "la jornada debería haber terminado")
	level._on_next_day_pressed()
	await _wait(0.3)
	_check(level._running and level._day == 2, "debería empezar el día 2")

	if _fails.is_empty():
		print("SMOKE PASS")
	else:
		print("SMOKE FAIL:\n  - " + "\n  - ".join(_fails))
	get_tree().quit(0 if _fails.is_empty() else 1)


func _grab(player: Player, dog: Dog) -> void:
	player.global_position = dog.global_position + Vector3(0.5, 0, 0)
	await _wait(0.05)
	level._handle_interact(1)
	await _wait(0.05)
	_check(dog.carried_by == 1, "no se pudo coger a %s" % dog.dog_name)


func _carry_and_drop(player: Player, target: Vector3) -> void:
	# Coloca al jugador de forma que al soltar el perro caiga en el objetivo.
	player.rotation.y = 0.0
	player.global_position = target + Vector3(0, 0.1, 1.1)
	await _wait(0.2)
	level._handle_interact(1)
	await _wait(0.1)


func _wait(t: float) -> void:
	await get_tree().create_timer(t).timeout


func _check(ok: bool, msg: String) -> void:
	if not ok:
		_fails.append(msg)
		push_warning("SMOKE: " + msg)
