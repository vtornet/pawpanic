extends Node
## Simulador de equilibrio: juega un año desde el principio real con distintos estilos.
## Uso:  godot --headless -- --balance
## Estilos:
##   bueno    → atiende avisos y visitas, prepara bien a los animales, rechaza a los no aptos,
##              compra a tiempo, hace campañas y amplía cuando lo necesita
##   pasivo   → lo mismo, pero sin campañas ni ampliaciones
##   descuidado → no da de comer a mano, adopta a cualquiera y no hace campañas

const DAYS := 360
const SEEDS := [11, 22, 33, 44, 55]


func run(_world, _ui) -> void:
	for style in ["bueno", "pasivo", "descuidado"]:
		var rows: Array = []
		for seed in SEEDS:
			rows.append(_play(style, seed))
			await get_tree().process_frame
		_report(style, rows)
	get_tree().quit()


func _play(style: String, seed: int) -> Dictionary:
	Game.new_game()
	Game.rng.seed = seed
	seed(seed)
	Game.s["tutorial"]["active"] = false
	Game.register("Simulación")
	Game.take_loan("mediano")
	Game.buy_start_land("parcela_camino")
	Game.build_starter()
	Game.paused = true
	var months: Array = []
	var min_money := Game.money()
	var end_day := DAYS
	for day in DAYS:
		if Game.s["step"] != "jugando":
			end_day = day
			break
		for step in 6:
			Game.advance_minutes(115)
			if Game.s["step"] != "jugando":
				break
			_act(style)
		if Game.s["step"] != "jugando":
			end_day = day
			break
		if style != "descuidado":
			Game.feed_all()
			Game.clean_all()
		Game.end_day()
		min_money = mini(min_money, Game.money())
		if (day + 1) % 30 == 0:
			months.append([Game.money(), Game.s["reputation"]])
	var st: Dictionary = Game.s["stats"]
	return {"end": end_day, "money": Game.money(), "rep": Game.s["reputation"], "min": min_money, "months": months,
		"rescued": st["rescued"], "adopted": st["adopted"], "returned": st["returned"], "lost": st["lost"],
		"donors": Game.s["donors"].size(), "slots": Game.slots(), "occ": Game.occupancy(), "over": Game.s["step"]}


func _act(style: String) -> void:
	var careful := style != "descuidado"
	# Avisos: recoger si cabe.
	# Si está lleno: acogidas y derivar avisos.
	if careful:
		for a in Game.sheltered():
			if Game.occupancy() <= Game.slots() - 1:
				break
			Game.send_to_foster(a["id"])
	for c in Game.s["calls"].duplicate():
		if Game.occupancy() + Game.carried().size() >= Game.slots() or (careful and Game.money() < 400):
			if careful:
				Game.forward_call(c["id"])
			continue
		var a := Game.animal(c["animal"])
		if a.is_empty():
			continue
		for i in 3:
			if Game.pick_up(a["id"]).begins_with("Has recogido"):
				break
	for a in Game.animals_at("escapado"):
		for i in 3:
			Game.pick_up(a["id"])
	# Clínica.
	for a in Game.carried():
		Game.apply_service(a["id"], "revision", false)
		if a["sick"] or a["injured"]:
			Game.apply_service(a["id"], "tratamiento", false)
		if a.get("owner_case", "") == "decidir":
			Game.owner_decision(a["id"], true)
		if a["chip"] != "dueño":
			for sv in ["vacunas", "chip", "desparasitar"]:
				if Game.money() > 300 or not careful:
					Game.apply_service(a["id"], sv, false)
	Game.deposit_all()
	# Enfermos del refugio: tratar si se puede.
	if careful:
		for a in Game.sheltered():
			if (a["sick"] or a["injured"]) and Game.money() > 200:
				var own := Game.can_do_own("tratamiento")
				if own:
					Game.apply_service(a["id"], "tratamiento", true)
				else:
					Game.take_out(a["id"])
					Game.apply_service(a["id"], "tratamiento", false)
					Game.deposit_all()
			elif not Game.is_adoptable(a) and a.get("owner_case", "") == "" and Game.money() > 400:
				for sv in ["vacunas", "chip", "desparasitar"]:
					var own2 := Game.can_do_own(sv)
					if not own2:
						Game.take_out(a["id"])
					Game.apply_service(a["id"], sv, own2)
					Game.deposit_all()
	# Visitas.
	for v in Game.person_visits():
		if v["kind"] == "dueño":
			Game.hand_over(v["id"])
		else:
			Game.take_back(v["id"])
	for rq in Game.visitors():
		if careful and rq.get("suspect", "") != "" and randf() < 0.85:
			Game.refuse_adopter(rq["id"])
			continue
		var done := false
		for a in Game.sheltered():
			if Game.is_adoptable(a) and Game.match_score(rq, a) >= (1 if careful else 0):
				Game.adopt(rq["id"], a["id"])
				done = true
				break
		if not done:
			Game.send_visitor_home(rq["id"])
	for rq in Game.s["requests"]:
		if rq.get("state", "") == "pendiente" and careful:
			Game.call_visit_now(rq["id"])
	if careful and Game.can_sign_agreement():
		Game.sign_agreement()
	# Compras.
	var need := Game.daily_need("pienso")
	var st: Dictionary = Game.s["stock"]
	if st["pienso"] < need * 4 + 2:
		Game.buy_product("pienso", 2 if need > 3 else 1)
	if st["limpieza"] < Game.occupancy() * Catalog.CLEANING_PER_ANIMAL * 4 + 1:
		Game.buy_product("limpieza", 1)
	if style == "bueno":
		var day: int = Game.s["day"]
		if day % 7 == 0 and Game.money() > 600 and int(Game.s["minute"]) < 10 * 60:
			Game.run_campaign("redes")
		if day % 30 == 15 and Game.money() > 2000 and int(Game.s["minute"]) < 10 * 60:
			Game.run_campaign("mercadillo")
		if Game.occupancy() >= Game.slots() - 1 and Game.money() > 2500 + 3000:
			Game.build("caniles")
		if not Game.has_building("vallado") and Game.money() > 1800 + 3000:
			Game.build("vallado")


func _report(style: String, rows: Array) -> void:
	print("\n=== %s ===" % style.to_upper())
	print("semilla | días | dinero final | dinero mínimo | reputación | rescatados | adoptados | devueltos | perdidos | socios | plazas | estado")
	for i in rows.size():
		var r: Dictionary = rows[i]
		print("%7d | %4d | %12d | %13d | %10d | %10d | %9d | %9d | %8d | %6d | %3d/%-3d | %s" % [SEEDS[i], r["end"], r["money"], r["min"],
			r["rep"], r["rescued"], r["adopted"], r["returned"], r["lost"], r["donors"], r["occ"], r["slots"], r["over"]])
	var m: Array = rows[0]["months"]
	print("evolución (semilla %d): %s" % [SEEDS[0], ", ".join(PackedStringArray(m.map(func(x: Array) -> String: return "%d€/%d" % [x[0], x[1]])))])
