extends Node
## Prueba automática: juega el arranque, un rescate completo hasta la adopción,
## un escape con chip, compras y obras, guarda y carga, y simula 200 días
## abriendo todos los paneles para detectar errores.
## Uso:  godot --headless -- --smoke     → imprime "SMOKE PASS" o "SMOKE FAIL"

var _fails: PackedStringArray = []


func run(world: World, ui: GameUI) -> void:
	Game.rng.seed = 12345
	await _frames(2)
	_check(world.ambience != null and get_tree().get_nodes_in_group("npc").size() >= 10, "el mundo debería haberse construido entero (ambiente y personajes)")

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

	# --- Personajes: todos tienen algo que decir y su panel se abre ---
	var npcs := get_tree().get_nodes_in_group("npc")
	_check(npcs.size() >= 7, "debería haber personajes en los edificios y el refugio (%d)" % npcs.size())
	for id in Dialogues.PEOPLE.keys() + ["staff_voluntario_0", "staff_cuidador_0", "vecino_0", "vecino_3"]:
		var d := Dialogues.talk(id)
		_check(d["text"] != "" and d["text"] != "...", "%s debería decir algo" % id)
		ui.open_dialog(id)
		await _frames(1)
		ui.close_panel()

	# --- Visita de una familia en persona ---
	Game.s["requests"].clear()
	var pet := Game._make_animal({"species": "perro", "size": "mediano"})
	for k in ["reviewed", "vaccinated", "dewormed"]:
		pet[k] = true
	pet["chip"] = "nuestro"
	pet["sick"] = false
	pet["injured"] = false
	pet["energy"] = "tranquilo"
	pet["location"] = "refugio"
	Game.s["animals"].append(pet)
	Game.s["requests"].append({"id": 7777, "who": "Familia con niños", "species": "perro", "size": "mediano",
		"energy": "tranquilo", "home": "casa con jardín", "state": "pendiente", "visit_at": Game.now_abs() + 20, "look": 3})
	Game.s["requests"].append({"id": 7778, "who": "Estudiante", "species": "gato", "size": "pequeño",
		"energy": "tranquilo", "home": "piso pequeño", "state": "pendiente", "visit_at": Game.now_abs() + 20, "look": 5})
	Game.advance_minutes(30)
	_check(Game.visitors().size() == 2, "deberían haber llegado dos familias (%d)" % Game.visitors().size())
	await _frames(2)
	var visitor_npcs := get_tree().get_nodes_in_group("npc").filter(func(n: Node) -> bool: return n.npc_id.begins_with("adoptante_"))
	_check(visitor_npcs.size() >= 2, "las familias deberían verse en el refugio")
	var talk_d := Dialogues.talk("adoptante_7777")
	var meet_opt: Array = talk_d["options"].filter(func(o: Array) -> bool: return o[1] is Callable and pet["name"] in o[0])
	_check(meet_opt.size() == 1, "debería poder presentarles a %s" % pet["name"])
	if meet_opt.size() == 1:
		var meet: Dictionary = meet_opt[0][1].call()
		_check("Es justo lo que buscábamos" in meet["text"] or "encanta" in meet["text"], "la familia debería reaccionar bien a un encaje perfecto")
		var adopted_before: int = Game.s["stats"]["adopted"]
		var sign_d: Dictionary = meet["options"][0][1].call()
		_check(Game.s["stats"]["adopted"] == adopted_before + 1, "la adopción en persona debería firmarse (%s)" % sign_d["text"])
		await _frames(2)
	ui.open_dialog("adoptante_7778")
	await _frames(1)
	ui.close_panel()
	Game.advance_minutes(200)
	_check(Game.visitors().is_empty(), "la familia que no fue atendida debería irse")

	# --- Adoptante no apto: un cazador ---
	var dog := Game._make_animal({"species": "perro", "size": "grande"})
	for k in ["reviewed", "vaccinated", "dewormed"]:
		dog[k] = true
	dog["chip"] = "nuestro"
	dog["sick"] = false
	dog["injured"] = false
	dog["location"] = "refugio"
	Game.s["animals"].append(dog)
	Game.s["requests"].append({"id": 8888, "who": "Señor Martín", "species": "perro", "size": "grande", "energy": "enérgico",
		"home": "casa de campo", "state": "esperando", "visit_at": 0, "wait_until": Game.now_abs() + 100, "look": 1, "suspect": "cazador"})
	var hunter := Dialogues.talk("adoptante_8888")
	_check("finca" in hunter["text"] or "temporada" in hunter["text"], "el cazador debería dejar caer alguna pista")
	var ask: Array = hunter["options"].filter(func(o: Array) -> bool: return "preguntas" in o[0])
	_check(ask.size() == 1 and "cercado" in ask[0][1].call()["text"], "las preguntas deberían destapar más pistas")
	var rep_before: int = Game.s["reputation"]
	Game.adopt(8888, dog["id"])
	_check(Game.s["consequences"].size() == 1, "adoptar a un no apto debería tener consecuencias")
	Game.s["consequences"][0]["day"] = Game.s["day"]
	Game.end_day()
	var back := Game.animal(dog["id"])
	_check(not back.is_empty() and back["location"] == "calle" and back["injured"], "el perro debería aparecer abandonado y herido")
	_check(Game.s["calls"].any(func(c: Dictionary) -> bool: return c["animal"] == dog["id"]), "debería llegar un aviso para rescatarlo")
	if not back.is_empty():
		back["skittish"] = false
		Game.pick_up(back["id"])
		Game.apply_service(back["id"], "revision", false)
		_check(back["owner_case"] == "decidir", "el chip debería identificar al adoptante y permitir denunciarle (%s)" % back["owner_case"])
		Game.deposit_all()
	# Rechazar a un no apto no penaliza; a una familia buena, sí.
	Game.s["requests"].append({"id": 8889, "who": "Estudiante", "species": "gato", "size": "pequeño", "energy": "tranquilo",
		"home": "piso pequeño", "state": "esperando", "visit_at": 0, "wait_until": Game.now_abs() + 100, "look": 1, "suspect": "regalo"})
	var r0: int = Game.s["reputation"]
	Game.refuse_adopter(8889)
	_check(Game.s["reputation"] == r0, "rechazar a un no apto no debería restar")

	# --- Dueño que viene a recoger a su animal ---
	var lost := Game._make_animal({"species": "perro"})
	lost["location"] = "refugio"
	lost["has_owner_chip"] = true
	lost["abuse"] = false
	lost["reviewed"] = false
	Game.s["animals"].append(lost)
	Game.rng.seed = 1
	Game.apply_service(lost["id"], "revision", false)
	_check(lost["owner_case"] == "contactando", "debería contactarse con el dueño")
	# Forzamos que el dueño lo quiera recuperar.
	lost["owner_day"] = Game.s["day"]
	var tries := 0
	while lost.get("owner_case", "") == "contactando" and tries < 40:
		Game.rng.seed = 100 + tries
		Game._progress_owner_case(lost)
		if lost["owner_case"] != "recogida":
			lost["owner_case"] = "contactando"
			lost["chip"] = "dueño"
		tries += 1
	_check(lost["owner_case"] == "recogida", "el dueño debería pedir cita para recogerlo")
	var ov: Dictionary = Game.s["visits"].filter(func(v: Dictionary) -> bool: return v["kind"] == "dueño" and v["animal_id"] == lost["id"])[0]
	ov["visit_at"] = Game.now_abs() + 5
	Game.s["minute"] = 11 * 60
	Game.advance_minutes(10)
	_check(ov["state"] == "esperando", "el dueño debería llegar al refugio")
	await _frames(2)
	_check(get_tree().get_nodes_in_group("npc").any(func(n: Node) -> bool: return n.npc_id == "visita_%d" % ov["id"]), "el dueño debería verse en la entrada")
	var od := Dialogues.talk("visita_%d" % ov["id"])
	var to_owner: int = Game.s["stats"]["to_owner"]
	od["options"][0][1].call()
	_check(Game.s["stats"]["to_owner"] == to_owner + 1 and Game.animal(lost["id"]).is_empty(), "el dueño debería llevarse a su animal")

	# --- Devoluciones en persona ---
	var ret := Game._make_animal({})
	ret["location"] = "adoptado"
	var rv := Game._schedule_return(ret, "Ladra demasiado", "Pareja joven")
	rv["visit_at"] = Game.now_abs() + 5
	Game.advance_minutes(10)
	_check(rv["state"] == "esperando", "la familia que devuelve debería llegar")
	var rd := Dialogues.talk("visita_%d" % rv["id"])
	_check("Ladra demasiado" in rd["text"], "deberían explicar por qué lo devuelven")
	rd["options"][0][1].call()
	_check(Game.animal(ret["id"]).get("location", "") == "refugio", "el animal devuelto debería volver al refugio")
	var ret2 := Game._make_animal({})
	var rv2 := Game._schedule_return(ret2, "Rompe cosas", "Familia López")
	rv2["visit_at"] = Game.now_abs() + 5
	Game.advance_minutes(10)
	var mood_before: int = ret2["mood"]
	Game.advance_minutes(200)
	_check(Game.animal(ret2["id"]).get("location", "") == "refugio" and ret2["mood"] < mood_before, "si nadie les atiende, deberían dejarlo atado a la puerta")

	# --- Ampliaciones con interior: animales y personal en su sitio ---
	Game.s["money"] = 200000
	Game.buy_land_upgrade("grande")
	Game.buy_land_upgrade("finca")  # el quirófano necesita la finca
	for bid in ["consulta", "limpieza", "gatera", "patio", "almacen", "quirofano"]:
		Game.build(bid)
	if Game.staff_count("veterinario") == 0:
		Game.hire("veterinario")
	if Game.staff_count("peluquero") == 0:
		Game.hire("peluquero")
	for other in Game.sheltered():  # que la cuarentena esté libre
		other["sick"] = false
		other["injured"] = false
	var sick_dog := Game._make_animal({"species": "perro"})
	sick_dog["location"] = "refugio"
	sick_dog["sick"] = true
	Game.s["animals"].append(sick_dog)
	var cat := Game._make_animal({"species": "gato"})
	cat["location"] = "refugio"
	cat["sick"] = false
	cat["injured"] = false
	Game.s["animals"].append(cat)
	Game.changed.emit()
	await _frames(2)
	var spot_of := func(id: String) -> Vector3:
		for bs in world._building_spots:
			if bs["id"] == id:
				return Game.s["land_pos"] + bs["pos"]
		return Vector3.INF
	var node_of := func(aid: int) -> Node3D:
		for n in world._shelter_animals.get_children():
			if n.get_meta("id", -1) == aid:
				return n
		return null
	var q: Vector3 = spot_of.call("cuarentena")
	var sd: Node3D = node_of.call(sick_dog["id"])
	_check(sd != null and q != Vector3.INF and sd.global_position.distance_to(q) < 3.5, "el animal enfermo debería estar en la cuarentena")
	var g: Vector3 = spot_of.call("gatera")
	var cn: Node3D = node_of.call(cat["id"])
	_check(cn != null and g != Vector3.INF and cn.global_position.distance_to(g) < 3.5, "el gato debería estar en la gatera")
	var vet_node: Array = get_tree().get_nodes_in_group("npc").filter(func(n: Node) -> bool: return n.npc_id.begins_with("staff_veterinario"))
	var cons: Vector3 = spot_of.call("consulta")
	_check(not vet_node.is_empty() and vet_node[0].global_position.distance_to(cons) < 3.5, "el veterinario debería trabajar en la consulta")
	_check(Game.can_do_own("vacunas") and Game.can_do_own("bano") and Game.can_do_own("esterilizar"), "los servicios propios deberían estar disponibles")
	# Se mueven: animales por su zona y personal por su recorrido (a media mañana, que de noche duermen).
	Game.s["minute"] = 11 * 60
	Game.paused = false
	var before_pos := {}
	for n in world._shelter_animals.get_children():
		before_pos[n] = n.global_position
	var staff_before := {}
	for n in world._staff_root.get_children():
		staff_before[n] = n.global_position
	for x in world._life._animals:  # que echen a andar hacia otro punto de su zona
		if x["half"] != Vector2.ZERO:
			x["state"] = "walk"
			x["target"] = x["center"] + Vector3(x["half"].x * 0.8, 0, x["half"].y * 0.8)
			x["timer"] = 6.0
	await get_tree().create_timer(3.0).timeout
	var moved := before_pos.keys().filter(func(n: Node3D) -> bool: return is_instance_valid(n) and n.global_position.distance_to(before_pos[n]) > 0.1)
	var staff_moved := staff_before.keys().filter(func(n: Node3D) -> bool: return is_instance_valid(n) and n.global_position.distance_to(staff_before[n]) > 0.1)
	_check(moved.size() >= 1, "los animales del refugio deberían moverse (%d de %d)" % [moved.size(), before_pos.size()])
	_check(staff_moved.size() >= 1, "el personal debería moverse por sus tareas")
	Game.paused = true
	for kind in ["consulta", "limpieza"]:
		ui.open_panel(kind)
		await _frames(1)
		ui.close_panel()
	var money_v := Game.money()
	Game.apply_service(sick_dog["id"], "tratamiento", true)
	_check(Game.money() == money_v - Catalog.SERVICES["tratamiento"]["own"], "el tratamiento propio debería costar el precio de material")

	# --- Nuevas especies: conejos y animales de granja ---
	Game.s["money"] = 200000
	Game.s["calls"].clear()
	var bunny := Game._make_animal({"species": "conejo"})
	bunny["location"] = "calle"
	bunny["skittish"] = false
	bunny["pos"] = Vector3(5, 0, 5)
	Game.s["animals"].append(bunny)
	if Game.has_building("conejera"):
		_check(false, "la conejera no debería existir todavía")
	_check(not Game.pick_up(bunny["id"]).begins_with("Has recogido"), "sin conejera no se debería poder acoger un conejo")
	Game.build("conejera")
	Game.use_vehicle("bici") if "bici" in Game.s["vehicles"] else null
	Game.deposit_all()
	_check(Game.pick_up(bunny["id"]).begins_with("Has recogido"), "con conejera debería poder recogerse el conejo")
	Game.deposit_all()
	_check(Game.food_of(bunny) == "heno" and Game.feed_need(bunny) > 0.0, "el conejo debería comer heno")
	Game.s["stock"]["heno"] = 10.0
	var hay_before: float = Game.s["stock"]["heno"]
	Game.feed_all()
	Game.end_day()
	_check(Game.s["stock"]["heno"] < hay_before, "debería gastarse heno")
	var horse := Game._make_animal({"species": "caballo"})
	horse["location"] = "calle"
	horse["skittish"] = false
	horse["pos"] = Vector3(8, 0, 8)
	Game.s["animals"].append(horse)
	Game.build("establo")
	_check(Game.has_building("establo"), "debería poder construirse el establo en la finca")
	_check(not Game.pick_up(horse["id"]).begins_with("Has recogido"), "un caballo no debería poder llevarse sin remolque")
	Game.buy_equipment("remolque")
	Game.buy_vehicle("coche")
	Game.use_vehicle("coche")
	Game.deposit_all()
	_check(Game.pick_up(horse["id"]).begins_with("Has recogido"), "con remolque y coche debería poder llevarse el caballo")
	Game.deposit_all()
	var m0 := Game.money()
	Game.apply_service(horse["id"], "revision", false)
	_check(m0 - Game.money() == Game.service_price("revision", false) + Catalog.LARGE_VET_TRAVEL, "el veterinario a domicilio debería cobrar desplazamiento")
	Game.changed.emit()
	await _frames(2)
	var horse_node: Node3D = null
	for n in world._shelter_animals.get_children():
		if n.get_meta("id", -1) == horse["id"]:
			horse_node = n
	var est: Vector3 = Vector3.INF
	for bs in world._building_spots:
		if bs["id"] == "establo":
			est = Game.s["land_pos"] + bs["pos"]
	_check(horse_node != null and est != Vector3.INF and horse_node.global_position.distance_to(est) < 3.5, "el caballo debería estar en el establo")

	# --- Seguimiento post-adopción ---
	var make_ready := func(sp: String) -> Dictionary:
		var x := Game._make_animal({"species": sp, "size": "mediano" if sp == "perro" else ""})
		for k in ["reviewed", "vaccinated", "dewormed"]:
			x[k] = true
		x["chip"] = "nuestro"
		x["sick"] = false
		x["injured"] = false
		x["energy"] = "tranquilo"
		x["location"] = "refugio"
		Game.s["animals"].append(x)
		return x
	Game.s["minute"] = 10 * 60
	# 1) Va bien: la llamada suma reputación una vez.
	var happy: Dictionary = make_ready.call("perro")
	Game.s["requests"].append({"id": 9101, "who": "Familia Ruiz", "species": "perro", "size": "mediano", "energy": "tranquilo",
		"home": "casa con jardín", "state": "esperando", "visit_at": 0, "wait_until": Game.now_abs() + 300, "look": 1, "suspect": ""})
	Game.adopt(9101, happy["id"])
	for r in Game.s["returns"].duplicate():
		if r["animal"]["id"] == happy["id"]:
			Game.s["returns"].erase(r)
	var fh: Dictionary = Game.s["followups"].filter(func(f: Dictionary) -> bool: return f["animal_id"] == happy["id"])[0]
	_check(Game.followup_status(fh) == "bien", "la adopción buena debería ir bien")
	var rep_b: int = Game.s["reputation"]
	Game.followup_call(fh["id"])
	_check(Game.s["reputation"] >= mini(100, rep_b + 1) or rep_b == 100, "llamar a una familia contenta debería mejorar la reputación")
	# 2) Va a fracasar: la llamada lo detecta y recuperar al animal funciona.
	var shaky: Dictionary = make_ready.call("perro")
	Game.s["requests"].append({"id": 9102, "who": "Pareja joven", "species": "perro", "size": "mediano", "energy": "tranquilo",
		"home": "piso pequeño", "state": "esperando", "visit_at": 0, "wait_until": Game.now_abs() + 300, "look": 2, "suspect": ""})
	Game.adopt(9102, shaky["id"])
	if Game._pending_return(shaky["id"]).is_empty():
		Game.s["returns"].append({"animal": shaky, "day": Game.s["day"] + 5, "reason": "Ladra demasiado", "who": "Pareja joven"})
	var fs: Dictionary = Game.s["followups"].filter(func(f: Dictionary) -> bool: return f["animal_id"] == shaky["id"])[0]
	_check(Game.followup_call(fs["id"])["status"] == "devolucion", "la llamada debería detectar que la adopción va mal")
	var fd := Dialogues.talk("seguimiento_llamar_%d" % fs["id"])
	_check(fd["options"].any(func(o: Array) -> bool: return "consejos" in o[0]), "debería poder darles consejos")
	# 3) Cazador: la llamada da largas; la visita destapa la verdad y se puede recuperar y denunciar.
	var hound: Dictionary = make_ready.call("perro")
	Game.s["requests"].append({"id": 9103, "who": "Señor Martín", "species": "perro", "size": "mediano", "energy": "tranquilo",
		"home": "casa de campo", "state": "esperando", "visit_at": 0, "wait_until": Game.now_abs() + 300, "look": 3, "suspect": "cazador"})
	Game.adopt(9103, hound["id"])
	var fc: Dictionary = Game.s["followups"].filter(func(f: Dictionary) -> bool: return f["animal_id"] == hound["id"])[0]
	_check("dejar" in Game.followup_call(fc["id"])["text"], "el cazador debería dar largas por teléfono")
	Game.s["minute"] = 10 * 60
	var vis := Game.followup_visit(fc["id"])
	_check(vis["status"] == "cazador" and "cercado" in vis["text"], "la visita debería destapar al cazador (%s)" % vis.get("text", ""))
	var den0: int = Game.s["stats"]["denuncias"]
	Game.followup_reclaim(fc["id"], true)
	_check(Game.animal(hound["id"]).get("location", "") == "refugio", "el perro debería volver al refugio")
	_check(Game._pending_consequence(hound["id"]).is_empty(), "la consecuencia debería evitarse")
	_check(Game.s["stats"]["denuncias"] == den0 + 1, "debería registrarse la denuncia")
	ui._tab = GameUI.TABS.find("Adopciones")
	ui.open_panel("tablet")
	await _frames(1)
	ui.close_panel()

	# --- Fauna silvestre: al centro de recuperación, nunca al refugio ---
	var hog := Game._make_animal({"species": "erizo"})
	hog["pos"] = Vector3(3, 0, 3)
	Game.s["animals"].append(hog)
	_check(Game.is_wild(hog) and hog["injured"], "el erizo debería ser fauna silvestre herida")
	while not Game.carried().is_empty():
		Game.deposit_all()
		break
	_check(Game.pick_up(hog["id"]).begins_with("Has recogido"), "debería poder recogerse el erizo")
	Game.deposit_all()
	_check(hog["location"] == "llevando", "la fauna silvestre no debería quedarse en el refugio")
	_check(not Game.apply_service(hog["id"], "vacunas", false).begins_with(hog["name"]), "no se deberían poder vacunar animales salvajes")
	_check(not Game.is_adoptable(hog), "la fauna silvestre no debería poder adoptarse")
	var crea_npc: Array = get_tree().get_nodes_in_group("npc").filter(func(n: Node) -> bool: return n.npc_id == "crea")
	_check(crea_npc.size() == 1, "debería existir la técnica del centro de recuperación")
	var cd := Dialogues.talk("crea")
	var rep_w: int = Game.s["reputation"]
	cd["options"][0][1].call()
	_check(Game.animal(hog["id"]).is_empty() and (Game.s["reputation"] > rep_w or rep_w == 100), "entregar el erizo al CREA debería sumar reputación")
	var owl := Game._make_animal({"species": "ave"})
	owl["pos"] = Vector3(3, 0, 3)
	Game.s["animals"].append(owl)
	Game.pick_up(owl["id"])
	Game.end_day()
	_check(Game.animal(owl["id"]).is_empty(), "si no se lleva al centro a tiempo, no sobrevive")

	# --- Coordinador de adopciones y logros ---
	_check(Game.hire("coordinador").begins_with("Se incorpora"), "debería poder contratarse un coordinador")
	var victim: Dictionary = make_ready.call("perro")
	Game.s["requests"].append({"id": 9301, "who": "Chico que vive solo", "species": "perro", "size": "mediano", "energy": "tranquilo",
		"home": "casa con jardín", "state": "esperando", "visit_at": 0, "wait_until": Game.now_abs() + 300, "look": 4, "suspect": "guarda"})
	Game.adopt(9301, victim["id"])
	var fv: Dictionary = Game.s["followups"].filter(func(f: Dictionary) -> bool: return f["animal_id"] == victim["id"])[0]
	fv["day"] -= 4  # adoptado hace unos días
	Game.s["consequences"].filter(func(c: Dictionary) -> bool: return c["animal"]["id"] == victim["id"])[0]["day"] = Game.s["day"] + 30
	var recovered := false
	for attempt in 6:
		Game.rng.seed = 500 + attempt
		Game._coordinator_day()
		if Game.animal(victim["id"]).get("location", "") == "refugio":
			recovered = true
			break
		fv["called"] = false
	_check(recovered, "el coordinador debería recuperar al animal de un adoptante no apto")
	Achievements.check()
	var got := Achievements.unlocked()
	for aid in ["PRIMER_RESCATE", "PRIMERA_ADOPCION", "FAUNA_5" if Game.s["stats"].get("wild", 0) >= 5 else "DENUNCIA", "SEGUNDA_OPORTUNIDAD", "GRAN_REFUGIO", "GRANJA"]:
		_check(got.has(aid), "debería haberse conseguido el logro %s" % aid)
	ui._tab = GameUI.TABS.find("Logros")
	ui.open_panel("tablet")
	await _frames(1)
	ui.close_panel()

	# --- Simulación larga: 200 días con decisiones sencillas ---
	Game.s["money"] = 50000
	for day in 200:
		if Game.s["step"] != "jugando":
			break
		for step in 3:
			Game.advance_minutes(120)
			_bot_visitors()
		for call in Game.s["calls"].duplicate():
			var an := Game.animal(call["animal"])
			if not an.is_empty() and Game.occupancy() + Game.carried().size() < Game.slots():
				an["skittish"] = false
				Game.pick_up(an["id"])
		Game.deliver_wildlife()
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
			if rq.get("suspect", "") != "":
				Game.refuse_adopter(rq["id"])
				continue
			var done := false
			for an in Game.sheltered():
				if Game.is_adoptable(an) and Game.match_score(rq, an) >= 1:
					Game.adopt(rq["id"], an["id"])
					done = true
					break
			if not done and rq.get("state", "") == "esperando":
				Game.send_visitor_home(rq["id"])
		if Game.s["stock"]["pienso"] < 20:
			Game.buy_product("pienso", 5)
		if Game.s["stock"]["heno"] < Game.daily_need("heno") * 4 + 5:
			Game.buy_product("heno", 3)
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


## Atiende a las familias que esperan: rechaza a las sospechosas y adopta si hay encaje.
func _bot_visitors() -> void:
	for v in Game.person_visits():
		if v["kind"] == "dueño":
			Game.hand_over(v["id"])
		else:
			Game.take_back(v["id"])
	for rq in Game.visitors():
		if rq.get("suspect", "") != "":
			Game.refuse_adopter(rq["id"])
			continue
		var done := false
		for an in Game.sheltered():
			if Game.is_adoptable(an) and Game.match_score(rq, an) >= 1:
				Game.adopt(rq["id"], an["id"])
				done = true
				break
		if not done:
			Game.send_visitor_home(rq["id"])


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _check(ok: bool, msg: String) -> void:
	if not ok:
		_fails.append(msg)
		push_warning("SMOKE: " + msg)
