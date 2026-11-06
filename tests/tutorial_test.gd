extends Node
## Juega el tutorial completo como un jugador.
## Uso:  godot --headless -- --tutorial-test   → imprime "TUTORIAL PASS" o "TUTORIAL FAIL"

var _fails: PackedStringArray = []


func run(world: World, ui: GameUI) -> void:
	Game.rng.seed = 7
	await _frames(2)
	Game.register("Refugio Tutorial")
	Game.take_loan("mediano")
	Game.buy_start_land("parcela_camino")
	Game.build_starter()
	ui.close_panel()
	_check(Tutorial.active() and Tutorial.current()["id"] == "tablet", "el tutorial debería empezar al construir la caseta")
	await _frames(2)
	_check(world._goal_marker != null, "debería existir el marcador de objetivo")

	ui.open_panel("tablet")
	ui.close_panel()
	_expect("recoger")
	await _frames(2)
	_check(world._goal_marker.visible, "el marcador debería señalar el aviso")

	var dog := Game.animal(Game.s["calls"][0]["animal"])
	Game.pick_up(dog["id"])
	_expect("revision")
	Game.apply_service(dog["id"], "revision", false)
	_expect("preparar")
	for sv in ["vacunas", "chip", "desparasitar"]:
		Game.apply_service(dog["id"], sv, false)
	_expect("dejar")
	Game.deposit_all()
	_expect("pienso")
	Game.buy_product("pienso", 1)
	_expect("comer")
	Game.feed_all()
	_expect("adopcion")
	_check(Game.s["requests"].size() >= 1, "debería venir una familia para el primer animal")
	var rq: Dictionary = Game.s["requests"][-1]
	_check(rq["suspect"] == "" and Game.match_score(rq, dog) >= 1, "la familia del tutorial debería ser apta y encajar")
	Game.s["minute"] = 11 * 60
	Game.advance_minutes(40)
	_check(rq["state"] == "esperando", "la familia debería llegar al refugio")
	var d := Dialogues.talk("adoptante_%d" % rq["id"])
	var meet: Array = d["options"].filter(func(o: Array) -> bool: return o[1] is Callable and dog["name"] in o[0])
	if meet.size() == 1:
		var m: Dictionary = meet[0][1].call()
		m["options"][0][1].call()
	_expect("dormir")
	var money := Game.money()
	Game.sleep()
	_check(not Tutorial.active(), "el tutorial debería terminar al dormir")
	_check(Game.money() >= money + 300 - 1000, "debería cobrarse la ayuda de bienvenida")
	_check(Game.s["log"].any(func(l: String) -> bool: return "bienvenida" in l), "la ayuda de bienvenida debería quedar registrada")

	# Saltar el tutorial en otra partida.
	Game.new_game()
	_check(Tutorial.active(), "una partida nueva debería empezar con el tutorial")
	Tutorial.skip()
	_check(not Tutorial.active(), "debería poder saltarse")

	print("TUTORIAL PASS" if _fails.is_empty() else "TUTORIAL FAIL:\n  - " + "\n  - ".join(_fails))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Game.SAVE_PATH))
	get_tree().quit(0 if _fails.is_empty() else 1)


func _expect(id: String) -> void:
	Tutorial.check()
	var cur: String = Tutorial.current().get("id", "(fin)")
	_check(cur == id, "el tutorial debería estar en «%s» y está en «%s»" % [id, cur])


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _check(ok: bool, msg: String) -> void:
	if not ok:
		_fails.append(msg)
		push_warning("TUTORIAL: " + msg)
