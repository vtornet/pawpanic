extends Node
## Prueba automática: juega el arranque, un rescate completo hasta la adopción,
## un escape con chip, compras y obras, guarda y carga, y simula 200 días
## abriendo todos los paneles para detectar errores.
## Uso:  godot --headless -- --smoke     → imprime "SMOKE PASS" o "SMOKE FAIL"

var _fails: PackedStringArray = []


func run(world: World, ui: GameUI) -> void:
	Game.rng.seed = 12345
	await _frames(2)

	# --- Arranque ---
	_check(not Game.register("ab"), "un nombre de 2 letras no debería valer")
	_check(Game.register("Huellas de Prueba"), "el registro debería funcionar")
	_check(Game.take_loan("mediano"), "el préstamo debería concederse")
	_check(Game.buy_start_land("parcela_camino"), "debería poder comprar el terreno")
	_check(Game.build_starter(), "debería poder construir la caseta")
	_check(Game.s["step"] == "jugando", "la partida debería haber empezado")
	_check(Game.slots() == 4, "la caseta debería tener 4 plazas")
	_check(Game.s["calls"].size() == 1, "debería haber un primer aviso")
	await _frames(2)
	_check(get_tree().get_nodes_in_group("interactable").size() >= 6, "debería haber lugares con los que interactuar")

	# --- Rescate → clínica → adopción ---
	var a := Game.animal(Game.s["calls"][0]["animal"])
	a["has_owner_chip"] = false
	a["skittish"] = false
	_check(Game.pick_up(a["id"]).begins_with("Has recogido"), "debería poder recoger al animal")
	_check(a["location"] == "llevando", "el animal debería ir conmigo")
	_check(Game.s["calls"].is_empty(), "el aviso debería cerrarse")
	Game.s["money"] = 20000
	for sv in ["revision", "vacunas", "chip", "desparasitar"]:
		Game.apply_service(a["id"], sv, false)
	if a["sick"] or a["injured"]:
		Game.apply_service(a["id"], "tratamiento", false)
	_check(a["reviewed"] and a["vaccinated"] and a["chip"] == "nuestro" and a["dewormed"], "los servicios deberían aplicarse")
	Game.deposit_all()
	_check(Game.is_adoptable(a), "el animal debería estar listo (falta: %s)" % ", ".join(Game.missing_for_adoption(a)))
	Game.s["requests"].append({"id": 9999, "who": "Test", "species": a["species"], "size": a["size"],
		"energy": "tranquilo", "home": "piso", "days": 3})
	var money_before := Game.money()
	var msg := Game.adopt(9999, a["id"])
	_check(Game.money() >= money_before + Catalog.ADOPTION_FEE, "la adopción debería ingresar la tasa (%s)" % msg)

	# --- Dueño con chip y maltrato → denuncia ---
	Game._new_call({})
	var b := Game.animal(Game.s["calls"][-1]["animal"])
	b["has_owner_chip"] = true
	b["abuse"] = true
	b["skittish"] = false
	Game.pick_up(b["id"])
	Game.apply_service(b["id"], "revision", false)
	_check(b["owner_case"] == "decidir", "con maltrato y chip debería pedirse decisión (%s)" % b["owner_case"])
	Game.owner_decision(b["id"], true)
	Game.deposit_all()
	for i in 4:
		Game.end_day()
	_check(b["owner_case"] == "" and b["chip"] == "nuestro", "la denuncia debería resolverse y quedarse el animal")

	# --- Escape con chip y recuperación ---
	b["location"] = "refugio"
	Game._escape(b)
	_check(b["location"] == "escapado", "un animal con chip debería quedar localizable")
	await _frames(2)
	Game.pick_up(b["id"])
	if b["location"] != "llevando":
		b["skittish"] = false
		Game.pick_up(b["id"])
	_check(b["location"] == "llevando", "debería poder recuperar al escapado")
	Game.deposit_all()

	# --- Escape sin chip: perdido ---
	var c := Game._make_animal({})
	c["location"] = "refugio"
	c["chip"] = "no"
	Game.s["animals"].append(c)
	Game._escape(c)
	_check(Game.animal(c["id"]).is_empty(), "un animal sin chip debería perderse al escapar")

	# --- Compras, obras, personal, campañas ---
	_check(Game.buy_vehicle("bici").begins_with("¡Has"), "debería comprar la bici")
	_check(Game.capacity() == 2, "la bici debería llevar 2")
	Game.buy_product("pienso", 5)
	_check(Game.build("caniles").begins_with("Construido"), "debería construir caniles")
	_check(Game.slots() == 8, "debería haber 8 plazas")
	_check(Game.build("consulta") != "", "la consulta requiere terreno mayor")
	Game.s["money"] = 60000
	Game.buy_land_upgrade("mediana")
	_check(Game.s["tier"] == 2, "el terreno debería ampliarse")
	_check(Game.build("cuarentena").begins_with("Construido"), "debería construir la cuarentena")
	Game.hire("cuidador")
	_check(Game.staff_count("cuidador") == 1, "debería contratar un cuidador")
	Game.run_campaign("redes")
	Game.buy_equipment("lector")
	_check(Game.has_equipment("lector"), "debería tener lector de chips")

	# --- Guardar y cargar ---
	var before := [Game.money(), Game.s["day"], Game.s["animals"].size(), Game.s["reputation"], Game.slots()]
	Game.save_game()
	Game.s["money"] = -1
	_check(Game.load_game(), "debería cargar la partida")
	var after := [Game.money(), Game.s["day"], Game.s["animals"].size(), Game.s["reputation"], Game.slots()]
	_check(str(before) == str(after), "la partida cargada debería coincidir (%s vs %s)" % [before, after])
	_check(typeof(Game.s["land_pos"]) == TYPE_VECTOR3, "las posiciones deberían recuperarse como Vector3")

	# --- Todos los paneles ---
	for kind in ["tablet", "refugio", "clinica", "peluqueria", "tienda", "ayuntamiento", "pausa"]:
		ui.open_panel(kind)
		await _frames(1)
		if kind == "tablet":
			for t in GameUI.TABS.size():
				ui._tab = t
				ui._rebuild()
				await _frames(1)
		ui.close_panel()

	# --- Simulación larga: 200 días con decisiones sencillas ---
	Game.s["money"] = 50000
	for day in 200:
		if Game.s["step"] != "jugando":
			break
		Game.advance_minutes(6 * 60)
		for call in Game.s["calls"].duplicate():
			var an := Game.animal(call["animal"])
			if not an.is_empty() and Game.occupancy() + Game.carried().size() < Game.slots():
				an["skittish"] = false
				Game.pick_up(an["id"])
		for an in Game.carried():
			for sv in ["revision", "vacunas", "chip", "desparasitar", "tratamiento"]:
				Game.apply_service(an["id"], sv, false)
		for an in Game.animals_at("escapado"):
			an["skittish"] = false
			Game.pick_up(an["id"])
		Game.deposit_all()
		if day == 10:
			Game.build("vallado")
		if Game.occupancy() >= Game.slots() - 1:
			Game.build("caniles")
		for rq in Game.s["requests"].duplicate():
			for an in Game.sheltered():
				if Game.is_adoptable(an) and Game.match_score(rq, an) >= 1:
					Game.adopt(rq["id"], an["id"])
					break
		if Game.s["stock"]["pienso"] < 20:
			Game.buy_product("pienso", 5)
		if Game.s["stock"]["limpieza"] < 5:
			Game.buy_product("limpieza", 3)
		Game.feed_all()
		Game.clean_all()
		if day % 37 == 0:
			ui.open_panel("tablet")
			ui._tab = day % GameUI.TABS.size()
			ui._rebuild()
			await _frames(1)
			ui.close_panel()
		Game.end_day()
		if day % 20 == 0:
			await _frames(1)
	_check(Game.s["day"] > 150, "la simulación debería avanzar muchos días (día %d)" % Game.s["day"])
	print("Simulación: día %d, dinero %d, reputación %d, rescatados %d, adoptados %d, devueltos %d, perdidos %d, en refugio %d" % [
		Game.s["day"], Game.money(), Game.s["reputation"], Game.s["stats"]["rescued"], Game.s["stats"]["adopted"],
		Game.s["stats"]["returned"], Game.s["stats"]["lost"], Game.occupancy()])

	if _fails.is_empty():
		print("SMOKE PASS")
	else:
		print("SMOKE FAIL:\n  - " + "\n  - ".join(_fails))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Game.SAVE_PATH))
	get_tree().quit(0 if _fails.is_empty() else 1)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _check(ok: bool, msg: String) -> void:
	if not ok:
		_fails.append(msg)
		push_warning("SMOKE: " + msg)
