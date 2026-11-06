extends Node
## Estado y reglas de la partida (autoload "Game").
## No sabe nada del mundo 3D ni de la interfaz: solo datos y decisiones.
## El mundo y la interfaz escuchan sus señales y llaman a sus acciones.

signal changed                       # cualquier dato ha cambiado (refrescar interfaz)
signal world_changed                 # animales en la calle / escapados han cambiado
signal notify(text: String, kind: String)
signal day_ended(summary: String)
signal game_over(reason: String)

const SAVE_PATH := "user://partida.json"
const MONTHS := ["septiembre", "octubre", "noviembre", "diciembre", "enero", "febrero",
	"marzo", "abril", "mayo", "junio", "julio", "agosto"]

const DOG_NAMES := ["Toby", "Luna", "Coco", "Rocky", "Lola", "Max", "Nala", "Bruno", "Kira", "Thor",
	"Canela", "Chispa", "Lucas", "Mía", "Duna", "Rufo", "Pipa", "Simba", "Trufa", "Lur", "Bimba", "Zeus",
	"Nieve", "Odín", "Sasha", "Tango", "Boira", "Golfo", "Perla", "Moro"]
const CAT_NAMES := ["Misi", "Garfi", "Sombra", "Pelusa", "Michi", "Salem", "Nube", "Tigre", "Kiwi",
	"Oreo", "Lince", "Mandarina", "Bigotes", "Gris", "Pantera", "Nala"]

## Lugares de los avisos (afueras y pueblo).
const SPOTS := [
	{"name": "Polígono industrial", "pos": Vector3(95, 0, -45)},
	{"name": "Carretera comarcal", "pos": Vector3(-115, 0, 10)},
	{"name": "Ribera del río", "pos": Vector3(-65, 0, 100)},
	{"name": "Pinar", "pos": Vector3(85, 0, 95)},
	{"name": "Huertas", "pos": Vector3(115, 0, 30)},
	{"name": "Gasolinera", "pos": Vector3(-85, 0, -65)},
	{"name": "Colegio", "pos": Vector3(0, 0, -75)},
	{"name": "Plaza del pueblo", "pos": Vector3(6, 0, 4)},
	{"name": "Camino rural", "pos": Vector3(40, 0, 135)},
	{"name": "Vertedero", "pos": Vector3(-125, 0, -105)},
	{"name": "Urbanización", "pos": Vector3(60, 0, -95)},
	{"name": "Cortijo abandonado", "pos": Vector3(-130, 0, 120)},
]

# ---------------------------------------------------------------------
# Estado (todo se guarda)
# ---------------------------------------------------------------------
var s: Dictionary = {}

var paused := true          # la interfaz pausa el tiempo mientras hay paneles abiertos
var rng := RandomNumberGenerator.new()
var player_pos := Vector3.ZERO   # lo actualiza el mundo, para distancias en la tablet


func _ready() -> void:
	rng.randomize()
	_setup_input()
	new_game()


func new_game() -> void:
	s = {
		"step": "registro",   # registro → prestamo → terreno → caseta → jugando → fin
		"name": "",
		"money": Catalog.START_SAVINGS,
		"reputation": 40,
		"day": 1,
		"minute": Catalog.DAY_START,
		"loan": {},
		"land": "",
		"land_pos": Vector3(0, 0, 70),
		"tier": 0,
		"buildings": {},
		"vehicles": ["a_pie"],
		"vehicle": "a_pie",
		"equipment": [],
		"stock": {"pienso": 15.0, "pienso_premium": 0.0, "limpieza": 5.0, "arena": 0.0},
		"staff": {"voluntario": 2},
		"donors": [12, 15],
		"animals": [],
		"calls": [],
		"requests": [],
		"returns": [],          # {animal, day}
		"next_id": 1,
		"fed_today": false,
		"cleaned_today": false,
		"events": {},           # evento -> días restantes
		"grant_day": -999,
		"log": [],
		"stats": {"rescued": 0, "adopted": 0, "returned": 0, "to_owner": 0, "lost": 0,
			"denuncias": 0, "day_adopted": 0, "day_rescued": 0, "day_income": 0, "day_spent": 0},
	}
	changed.emit()
	world_changed.emit()


# =====================================================================
# Consultas
# =====================================================================

func money() -> int:
	return int(s["money"])


func can_afford(amount: int) -> bool:
	return s["money"] >= amount


func date_text() -> String:
	var d: int = s["day"] - 1
	var month: String = MONTHS[(d / 30) % 12]
	return "Día %d · %d de %s" % [s["day"], d % 30 + 1, month]


func month_index() -> int:
	return ((s["day"] - 1) / 30) % 12


func time_text() -> String:
	var m := int(s["minute"])
	return "%02d:%02d" % [m / 60, m % 60]


func vehicle() -> Dictionary:
	return _find(Catalog.VEHICLES, s["vehicle"])


func capacity() -> int:
	return vehicle()["capacity"]


func has_building(id: String) -> bool:
	return s["buildings"].get(id, 0) > 0


func has_equipment(id: String) -> bool:
	return id in s["equipment"]


func staff_count(id: String) -> int:
	return s["staff"].get(id, 0)


func slots() -> int:
	var n: int = Catalog.STARTER_BUILDING["slots"] if s["tier"] > 0 else 0
	for b in Catalog.BUILDINGS:
		if b.has("slots"):
			n += b["slots"] * s["buildings"].get(b["id"], 0)
	return n


func animals_at(location: String) -> Array:
	return s["animals"].filter(func(a: Dictionary) -> bool: return a["location"] == location)


func animal(id: int) -> Dictionary:
	for a in s["animals"]:
		if a["id"] == id:
			return a
	return {}


func carried() -> Array:
	return animals_at("llevando")


func sheltered() -> Array:
	return animals_at("refugio")


func occupancy() -> int:
	return sheltered().size()


func is_adoptable(a: Dictionary) -> bool:
	return a["location"] == "refugio" and a["reviewed"] and a["vaccinated"] and a["dewormed"] \
		and a["chip"] == "nuestro" and not a["sick"] and not a["injured"] and a.get("owner_case", "") == ""


func missing_for_adoption(a: Dictionary) -> PackedStringArray:
	var m: PackedStringArray = []
	if not a["reviewed"]: m.append("revisión")
	if not a["vaccinated"]: m.append("vacunas")
	if not a["dewormed"]: m.append("desparasitar")
	if a["chip"] != "nuestro":
		m.append("chip" if a["chip"] in ["no", "desconocido"] else "resolver dueño")
	if a["sick"] or a["injured"]: m.append("tratamiento")
	if a.get("owner_case", "") != "": m.append("caso con dueño")
	return m


## Precio de un servicio aquí: "own" si se hace en el refugio, si no externo.
func service_price(service: String, own: bool) -> int:
	var sv: Dictionary = Catalog.SERVICES[service]
	return sv["own"] if own else sv["ext"]


## ¿Se puede hacer este servicio en el propio refugio?
func can_do_own(service: String) -> bool:
	if service == "bano":
		return has_building("limpieza") and (staff_count("peluquero") > 0 or staff_count("voluntario") > 0)
	if service == "desparasitar":
		return s["tier"] > 0
	if service == "esterilizar":
		return has_building("quirofano") and staff_count("veterinario") > 0
	return has_building("consulta") and staff_count("veterinario") > 0


func average(field: String) -> float:
	var list := sheltered()
	if list.is_empty():
		return 100.0
	var t := 0.0
	for a in list:
		t += a[field]
	return t / list.size()


func land_info() -> Dictionary:
	return _find(Catalog.LANDS, s["land"])


func land_size() -> int:
	var best: int = land_info().get("size", 20)
	for l in Catalog.LANDS:
		if l["tier"] > 1 and l["tier"] <= s["tier"]:
			best = maxi(best, l["size"])
	return best


func monthly_wages() -> int:
	var t := 0
	for st in Catalog.STAFF:
		t += st["wage"] * staff_count(st["id"])
	return t


func monthly_donors() -> int:
	var t := 0
	for d in s["donors"]:
		t += d
	return t


# =====================================================================
# Arranque: registro, préstamo, terreno, caseta
# =====================================================================

func register(shelter_name: String) -> bool:
	shelter_name = shelter_name.strip_edges()
	if shelter_name.length() < 3 or s["step"] != "registro":
		return false
	s["name"] = shelter_name
	_spend(Catalog.REGISTRATION_FEE, "Tasas de registro")
	s["step"] = "prestamo"
	_log("Protectora «%s» registrada oficialmente." % shelter_name)
	changed.emit()
	return true


func take_loan(id: String) -> bool:
	var l := _find(Catalog.LOANS, id)
	if l.is_empty() or s["step"] != "prestamo":
		return false
	var total := int(round(l["amount"] * (1.0 + l["interest"] * l["months"] / 12.0)))
	s["loan"] = {"name": l["name"], "amount": l["amount"], "left": total,
		"monthly": int(ceil(float(total) / l["months"])), "months_left": l["months"], "missed": 0}
	_earn(l["amount"], "Préstamo concedido")
	s["step"] = "terreno"
	changed.emit()
	return true


func buy_start_land(id: String) -> bool:
	var l := _find(Catalog.LANDS, id)
	if l.is_empty() or l["tier"] != 1 or s["step"] != "terreno" or not can_afford(l["price"]):
		return false
	_spend(l["price"], "Compra de terreno")
	s["land"] = id
	s["land_pos"] = l["pos"]
	s["step"] = "caseta"
	changed.emit()
	return true


func build_starter() -> bool:
	if s["step"] != "caseta" or not can_afford(Catalog.STARTER_BUILDING["price"]):
		return false
	_spend(Catalog.STARTER_BUILDING["price"], "Construcción de la caseta")
	s["tier"] = 1
	s["step"] = "jugando"
	_reset_day_stats()
	# Primer aviso: cerca y sencillo, como tutorial.
	_new_call({"species": "perro", "near": true, "easy": true})
	_log("¡Caseta terminada! Ya puedes acoger animales. Abre la tablet (Tab) para ver los avisos.")
	notify.emit("Primer aviso de recogida: mira la tablet (Tab)", "info")
	changed.emit()
	world_changed.emit()
	return true


# =====================================================================
# Tiempo
# =====================================================================

func _process(delta: float) -> void:
	if paused or s.get("step", "") != "jugando":
		return
	advance_minutes(delta * Catalog.MINUTES_PER_SECOND)


func advance_minutes(m: float) -> void:
	var before := int(s["minute"])
	s["minute"] += m
	var now := int(s["minute"])
	# Cada hora de juego: avisos nuevos, solicitudes y movimiento de escapados.
	if now / 60 != before / 60:
		_hourly()
	if s["minute"] >= Catalog.DAY_END:
		end_day()
	elif now != before:
		changed.emit()


func _hourly() -> void:
	var hour := int(s["minute"]) / 60
	var call_chance: float = 0.08 + 0.04 * s["tier"]
	if s["events"].has("caza"):
		call_chance += 0.2
	if s["events"].has("incendio"):
		call_chance += 0.35
	if rng.randf() < call_chance:
		var opts := {}
		if s["events"].has("incendio") and rng.randf() < 0.7:
			opts = {"injured": true, "spot": "Pinar"}
		elif s["events"].has("caza") and rng.randf() < 0.7:
			opts = {"species": "perro", "size": "mediano"}
		_new_call(opts)
	# Animales escapados con chip: se mueven, y la señal llega a ratos.
	for a in animals_at("escapado"):
		var step := Vector3(rng.randf_range(-1, 1), 0, rng.randf_range(-1, 1)).normalized() * rng.randf_range(8, 22)
		a["pos"] = _clamp_world(a["pos"] + step)
		if has_equipment("rastreador") or rng.randf() < 0.45:
			a["seen_pos"] = a["pos"]
			a["seen_at"] = "%02d:00" % hour
	# Plazos de los avisos.
	for c in s["calls"].duplicate():
		if s["day"] > c["deadline"] or (s["day"] == c["deadline"] and hour >= 20):
			_expire_call(c)
	world_changed.emit()


func sleep() -> void:
	if s["step"] == "jugando":
		end_day()


func end_day() -> void:
	var lines: PackedStringArray = []
	var list := sheltered()
	var st: Dictionary = s["stats"]

	# --- Cuidados: quién da de comer y limpia ---
	var care_capacity := staff_count("cuidador") * 25
	var volunteers_today := 0
	for i in staff_count("voluntario"):
		if rng.randf() < 0.75:
			volunteers_today += 1
	care_capacity += volunteers_today * 6
	if s["fed_today"]:
		care_capacity = 999
	var clean_capacity := care_capacity + staff_count("limpiador") * 30
	if s["cleaned_today"]:
		clean_capacity = 999
	if staff_count("voluntario") > 0:
		lines.append("Voluntarios que vinieron: %d de %d" % [volunteers_today, staff_count("voluntario")])

	var fed := 0
	var cleaned := 0
	var hungry_no_food := 0
	for a in list:
		# Comida
		var need: float = Catalog.FEED_PER_DAY[a["size"]] * (0.6 if a["species"] == "gato" else 1.0)
		var got_food := false
		if fed < care_capacity:
			if s["stock"]["pienso_premium"] >= need:
				s["stock"]["pienso_premium"] -= need
				got_food = true
				a["health"] = mini(100, a["health"] + 2)
			elif s["stock"]["pienso"] >= need:
				s["stock"]["pienso"] -= need
				got_food = true
		if got_food:
			fed += 1
			a["nutrition"] = mini(100, a["nutrition"] + 25)
		else:
			hungry_no_food += 1
			a["nutrition"] = maxi(0, a["nutrition"] - 20)
		# Limpieza
		var got_clean := false
		if cleaned < clean_capacity:
			var product := "arena" if a["species"] == "gato" and s["stock"]["arena"] >= 1.0 else "limpieza"
			var use: float = 1.0 if product == "arena" else Catalog.CLEANING_PER_ANIMAL
			if s["stock"][product] >= use:
				s["stock"][product] -= use
				got_clean = true
		if got_clean:
			cleaned += 1
			a["hygiene"] = mini(100, a["hygiene"] + 15)
		else:
			a["hygiene"] = maxi(0, a["hygiene"] - 12)
	if hungry_no_food > 0:
		lines.append("⚠ %d animales sin comer (falta pienso o manos)" % hungry_no_food)
	if list.size() > 0 and cleaned < list.size():
		lines.append("⚠ %d animales sin limpiar" % (list.size() - cleaned))

	# --- Salud, ánimo, sobreocupación ---
	var over := maxi(0, list.size() - slots())
	if over > 0:
		lines.append("⚠ Sobreocupación: %d animales más que plazas" % over)
		_rep(-1)
	for a in list:
		a["days_in"] += 1
		var dmg := 0
		if a["nutrition"] < 30: dmg += 8
		if a["hygiene"] < 30: dmg += 5
		if a["sick"]: dmg += 6
		if a["injured"]: dmg += 4
		if s["events"].has("calor") and not has_building("patio"): dmg += 3
		if dmg == 0:
			a["health"] = mini(100, a["health"] + 4)
		a["health"] -= dmg
		var mood_delta := 2
		if over > 0: mood_delta -= 6
		if has_building("patio"): mood_delta += 3
		if staff_count("paseador") > 0: mood_delta += 4
		a["mood"] = clampi(a["mood"] + mood_delta, 0, 100)
		if a["sick"] and rng.randf() < 0.1:
			a["sick"] = false
		var sick_chance := 0.015 * (2.0 if a["hygiene"] < 40 else 1.0) * (0.5 if a["vaccinated"] else 1.0)
		if not a["sick"] and rng.randf() < sick_chance:
			a["sick"] = true
			lines.append("%s ha enfermado" % a["name"])
		if a["health"] <= 0:
			a["health"] = 40
			a["sick"] = false
			a["injured"] = false
			_spend(300, "Urgencia veterinaria")
			_rep(-4)
			lines.append("‼ %s tuvo que ir a urgencias (300 €)" % a["name"])

	# --- Fugas ---
	var escape_base := 0.003 if has_building("vallado") else 0.012
	for a in list.duplicate():
		var ch := escape_base
		if a["energy"] == "enérgico": ch *= 2.0
		if a["energy"] == "miedoso": ch *= 1.5
		if a["mood"] < 40: ch *= 1.5
		if over > 0: ch *= 2.0
		if s["events"].has("temporal"): ch *= 3.0
		if rng.randf() < ch:
			lines.append(_escape(a))

	# --- Escapados que siguen fuera ---
	for a in animals_at("escapado"):
		a["days_out"] = a.get("days_out", 0) + 1
		if rng.randf() < 0.08 * a["days_out"]:
			_remove_animal(a)
			st["lost"] += 1
			_rep(-3)
			lines.append("Hemos perdido la señal de %s. No hemos podido recuperarlo." % a["name"])

	# --- Animales que siguen en la calle: los avisos caducan en _hourly ---

	# --- Casos con dueño ---
	for a in s["animals"].duplicate():
		var line := _progress_owner_case(a)
		if line != "":
			lines.append(line)

	# --- Devoluciones de adopciones ---
	for r in s["returns"].duplicate():
		if r["day"] <= s["day"]:
			s["returns"].erase(r)
			var a: Dictionary = r["animal"]
			a["location"] = "refugio"
			a["mood"] = maxi(0, a["mood"] - 30)
			a["returned_count"] += 1
			s["animals"].append(a)
			st["returned"] += 1
			_rep(-1)
			lines.append("↩ Han devuelto a %s: «%s»" % [a["name"], r["reason"]])

	# --- Solicitudes de adopción ---
	for rq in s["requests"].duplicate():
		rq["days"] -= 1
		if rq["days"] <= 0:
			s["requests"].erase(rq)
	_generate_requests()

	# --- Eventos ---
	for e in s["events"].keys():
		s["events"][e] -= 1
		if s["events"][e] <= 0:
			s["events"].erase(e)
	var ev_line := _random_event()
	if ev_line != "":
		lines.append(ev_line)

	# --- Fin de mes ---
	var month_end: bool = s["day"] % 30 == 0
	if month_end:
		lines.append("")
		lines.append_array(_end_month())

	var summary := "%s — cierre del día\n\nRescatados: %d   ·   Adoptados: %d\nIngresos: %d €   ·   Gastos: %d €\nAnimales en el refugio: %d / %d plazas\nPienso: %.1f kg   ·   Limpieza: %.1f usos\nDinero: %d €   ·   Reputación: %d" % [
		date_text(), st["day_rescued"], st["day_adopted"], st["day_income"], st["day_spent"],
		occupancy(), slots(), s["stock"]["pienso"] + s["stock"]["pienso_premium"], s["stock"]["limpieza"],
		money(), s["reputation"]]
	if not lines.is_empty():
		summary += "\n\n" + "\n".join(lines)

	s["day"] += 1
	s["minute"] = Catalog.DAY_START
	s["fed_today"] = false
	s["cleaned_today"] = false
	_reset_day_stats()

	if s["loan"].get("missed", 0) >= 3:
		s["step"] = "fin"
		game_over.emit("Tres cuotas del préstamo sin pagar. El banco ha embargado el terreno.")
	elif s["reputation"] <= 0:
		s["step"] = "fin"
		game_over.emit("La protectora ha perdido toda la confianza. La administración retira la licencia.")
	else:
		# Avisos de primera hora.
		for i in rng.randi_range(0, 1 + s["tier"] / 2):
			_new_call({})
		save_game()

	changed.emit()
	world_changed.emit()
	day_ended.emit(summary)


func _end_month() -> PackedStringArray:
	var out: PackedStringArray = ["— Cierre de mes —"]
	var loan: Dictionary = s["loan"]
	if loan.get("months_left", 0) > 0:
		if can_afford(loan["monthly"]):
			_spend(loan["monthly"], "Cuota del préstamo")
			loan["left"] -= loan["monthly"]
			loan["months_left"] -= 1
			loan["missed"] = 0
			out.append("Cuota del préstamo: -%d € (quedan %d meses)" % [loan["monthly"], loan["months_left"]])
			if loan["months_left"] == 0:
				out.append("🎉 ¡Préstamo pagado por completo!")
				_rep(5)
		else:
			loan["missed"] += 1
			out.append("‼ No hay saldo para la cuota del préstamo (impago %d de 3)" % loan["missed"])
	var wages := monthly_wages()
	if wages > 0:
		_spend(wages, "Sueldos")
		out.append("Sueldos: -%d €" % wages)
	var fixed: int = Catalog.FIXED_MONTHLY - (Catalog.SOLAR_SAVING if has_building("placas") else 0)
	_spend(fixed, "Luz, agua y seguro")
	out.append("Luz, agua y seguro: -%d €" % fixed)
	var donors := monthly_donors()
	if donors > 0:
		_earn(donors, "Cuotas de socios")
		out.append("Cuotas de %d socios: +%d €" % [s["donors"].size(), donors])
	# Algunos socios se dan de baja si la reputación cae.
	if s["reputation"] < 35 and s["donors"].size() > 0 and rng.randf() < 0.5:
		s["donors"].pop_back()
		out.append("Un socio se ha dado de baja por las noticias sobre el refugio.")
	return out


# =====================================================================
# Avisos y animales
# =====================================================================

func _make_animal(opts: Dictionary) -> Dictionary:
	var species: String = opts.get("species", "gato" if rng.randf() < 0.3 else "perro")
	var names: Array = CAT_NAMES if species == "gato" else DOG_NAMES
	var size: String = opts.get("size", "")
	if size == "":
		size = "pequeño" if species == "gato" else ["pequeño", "mediano", "grande"][rng.randi() % 3]
	var energies := ["tranquilo", "enérgico", "miedoso", "sociable"]
	var bad: bool = rng.randf() < 0.3 or opts.get("injured", false)
	var a := {
		"id": s["next_id"],
		"name": names[rng.randi() % names.size()],
		"species": species,
		"size": size,
		"energy": energies[rng.randi() % energies.size()],
		"age": rng.randi_range(1, 12),
		"sex": "macho" if rng.randf() < 0.5 else "hembra",
		"health": rng.randi_range(25, 55) if bad else rng.randi_range(55, 85),
		"nutrition": rng.randi_range(20, 60),
		"hygiene": rng.randi_range(10, 50),
		"mood": rng.randi_range(30, 70),
		"reviewed": false,
		"chip": "desconocido",
		"has_owner_chip": rng.randf() < 0.32,
		"vaccinated": false,
		"sterilized": false,
		"dewormed": false,
		"injured": opts.get("injured", rng.randf() < 0.12),
		"sick": rng.randf() < 0.15,
		"abuse": bad and rng.randf() < 0.45,
		"abuse_known": false,
		"skittish": not opts.get("easy", false) and rng.randf() < 0.3,
		"location": "calle",
		"pos": Vector3.ZERO,
		"days_in": 0,
		"returned_count": 0,
		"owner_case": "",
		"owner_day": 0,
		"origin": "",
	}
	s["next_id"] += 1
	return a


func _new_call(opts: Dictionary) -> void:
	if s["calls"].size() >= 6:
		return
	var a := _make_animal(opts)
	var spot: Dictionary
	if opts.get("near", false):
		spot = SPOTS[7]  # plaza
	elif opts.has("spot"):
		spot = _find_by_name(SPOTS, opts["spot"])
	else:
		spot = SPOTS[rng.randi() % SPOTS.size()]
	a["pos"] = spot["pos"] + Vector3(rng.randf_range(-6, 6), 0, rng.randf_range(-6, 6))
	a["origin"] = spot["name"]
	s["animals"].append(a)
	var urgent: bool = a["injured"] or a["health"] < 40
	var who: String = ["Una vecina", "Un vecino", "La Policía Local", "Un conductor", "El ayuntamiento", "Una familia"][rng.randi() % 6]
	var desc := "%s avisa: %s %s %s en %s" % [who, "perro" if a["species"] == "perro" else "gato",
		a["size"], "herido" if a["injured"] else ("en mal estado" if a["health"] < 40 else "abandonado"), spot["name"]]
	s["calls"].append({"id": a["id"], "animal": a["id"], "place": spot["name"], "desc": desc,
		"urgent": urgent, "deadline": s["day"] + (0 if urgent else 1)})
	notify.emit("Nuevo aviso: " + desc, "aviso")
	_log(desc)
	world_changed.emit()
	changed.emit()


func _expire_call(c: Dictionary) -> void:
	s["calls"].erase(c)
	var a := animal(c["animal"])
	if not a.is_empty() and a["location"] == "calle":
		_remove_animal(a)
		if c["urgent"]:
			_rep(-2)
		notify.emit("Nadie acudió al aviso de %s. El animal ya no está." % c["place"], "mal")


func _escape(a: Dictionary) -> String:
	if a["chip"] in ["nuestro", "dueño"]:
		a["location"] = "escapado"
		a["pos"] = _clamp_world(s["land_pos"] + Vector3(rng.randf_range(-40, 40), 0, rng.randf_range(-40, 40)))
		a["seen_pos"] = a["pos"]
		a["seen_at"] = time_text()
		a["days_out"] = 0
		_rep(-2)
		notify.emit("¡%s se ha escapado! Tiene chip: sigue su señal." % a["name"], "mal")
		world_changed.emit()
		return "‼ %s se ha escapado. Tiene chip: su señal aparece en el mapa." % a["name"]
	_remove_animal(a)
	s["stats"]["lost"] += 1
	_rep(-3)
	return "‼ %s se ha escapado y no tenía chip. No podremos encontrarlo." % a["name"]


## Recoger un animal en la calle o un escapado.
func pick_up(id: int) -> String:
	var a := animal(id)
	if a.is_empty() or not a["location"] in ["calle", "escapado"]:
		return ""
	if carried().size() >= capacity():
		return "No te caben más animales (%s: %d). Consigue un vehículo mayor." % [vehicle()["name"], capacity()]
	if a["size"] == "grande" and s["vehicle"] == "a_pie" and a["injured"]:
		return "Está herido y es muy grande para llevarlo a pie. Necesitas un vehículo."
	if a["skittish"] and not has_equipment("trampa") and rng.randf() < 0.5:
		a["pos"] = _clamp_world(a["pos"] + Vector3(rng.randf_range(-6, 6), 0, rng.randf_range(-6, 6)))
		world_changed.emit()
		return "%s se asusta y se aleja unos metros. Acércate con calma (o usa una jaula trampa)." % a["name"]
	var was_escaped: bool = a["location"] == "escapado"
	a["location"] = "llevando"
	for c in s["calls"].duplicate():
		if c["animal"] == id:
			s["calls"].erase(c)
	if was_escaped:
		a.erase("days_out")
		_log("Has recuperado a %s." % a["name"])
	else:
		s["stats"]["rescued"] += 1
		s["stats"]["day_rescued"] += 1
		_rep(1)
		if has_equipment("lector") and not a["reviewed"]:
			_read_chip(a)
	advance_minutes(10)
	world_changed.emit()
	changed.emit()
	return "Has recogido a %s." % a["name"]


func deposit_all() -> String:
	var n := 0
	for a in carried():
		a["location"] = "refugio"
		n += 1
	if n == 0:
		return "No llevas ningún animal."
	var msg := "Has dejado %d animal(es) en el refugio." % n
	if occupancy() > slots():
		msg += " ⚠ Hay más animales que plazas."
	changed.emit()
	return msg


func take_out(id: int) -> String:
	var a := animal(id)
	if a.is_empty() or a["location"] != "refugio":
		return ""
	if carried().size() >= capacity():
		return "No puedes llevar más animales con %s." % vehicle()["name"]
	a["location"] = "llevando"
	changed.emit()
	return "Llevas a %s contigo." % a["name"]


func feed_all() -> String:
	if s["fed_today"]:
		return "Ya les has dado de comer hoy."
	s["fed_today"] = true
	advance_minutes(20 + 3 * occupancy())
	changed.emit()
	return "Les has puesto comida y agua a todos (se descuenta el pienso al final del día)."


func clean_all() -> String:
	if s["cleaned_today"]:
		return "Ya has limpiado hoy."
	s["cleaned_today"] = true
	advance_minutes(30 + 4 * occupancy())
	changed.emit()
	return "Has limpiado las instalaciones."


# =====================================================================
# Servicios veterinarios y de limpieza
# =====================================================================

func apply_service(id: int, service: String, own: bool) -> String:
	var a := animal(id)
	if a.is_empty():
		return ""
	if own and not can_do_own(service):
		return "Aún no puedes hacer esto en el refugio."
	var price := service_price(service, own)
	if not can_afford(price):
		return "No tienes dinero suficiente (%d €)." % price
	match service:
		"revision":
			if a["reviewed"]:
				return "%s ya está revisado." % a["name"]
		"vacunas":
			if not a["reviewed"]:
				return "Primero necesita una revisión."
			if a["vaccinated"]:
				return "Ya está vacunado."
		"chip":
			if not a["reviewed"] and a["chip"] == "desconocido":
				return "Primero hay que comprobar si ya tiene chip (revisión o lector)."
			if a["chip"] != "no":
				return "Ya tiene chip."
		"desparasitar":
			if a["dewormed"]:
				return "Ya está desparasitado."
		"esterilizar":
			if not a["reviewed"]:
				return "Primero necesita una revisión."
			if a["sterilized"]:
				return "Ya está esterilizado."
			if a.get("owner_case", "") != "" or a["chip"] == "dueño":
				return "No se puede esterilizar mientras no se resuelva lo del dueño."
		"tratamiento":
			if not a["sick"] and not a["injured"]:
				return "No necesita tratamiento."
		"bano":
			pass
	_spend(price, Catalog.SERVICES[service]["name"])
	var msg := "%s: %s." % [a["name"], Catalog.SERVICES[service]["name"].to_lower()]
	match service:
		"revision":
			a["reviewed"] = true
			a["health"] = mini(100, a["health"] + 5)
			var found: PackedStringArray = []
			if a["sick"]: found.append("enfermo")
			if a["injured"]: found.append("herido")
			if a["abuse"]:
				a["abuse_known"] = true
				found.append("INDICIOS DE MALTRATO")
			if a["chip"] == "desconocido":
				found.append(_read_chip(a))
			msg = "Revisión de %s: %s." % [a["name"], ", ".join(found) if not found.is_empty() else "todo correcto"]
		"vacunas":
			a["vaccinated"] = true
		"chip":
			a["chip"] = "nuestro"
		"desparasitar":
			a["dewormed"] = true
		"esterilizar":
			a["sterilized"] = true
			a["health"] = maxi(10, a["health"] - 10)
		"tratamiento":
			a["sick"] = false
			a["injured"] = false
			a["health"] = mini(100, a["health"] + 30)
		"bano":
			a["hygiene"] = 100
			a["mood"] = mini(100, a["mood"] + 10)
	advance_minutes(15 if own else 25)
	changed.emit()
	return msg


func _read_chip(a: Dictionary) -> String:
	if a["has_owner_chip"]:
		a["chip"] = "dueño"
		if a["abuse_known"]:
			a["owner_case"] = "decidir"
			return "tiene chip de un propietario. Hay indicios de maltrato: decide si denunciar"
		a["owner_case"] = "contactando"
		a["owner_day"] = s["day"] + rng.randi_range(1, 2)
		return "tiene chip: estamos contactando con su dueño"
	a["chip"] = "no"
	return "no tiene chip"


## Decisión cuando un animal con chip tiene indicios de maltrato.
func owner_decision(id: int, denounce: bool) -> String:
	var a := animal(id)
	if a.is_empty() or a["owner_case"] != "decidir":
		return ""
	if denounce:
		a["owner_case"] = "denuncia"
		a["owner_day"] = s["day"] + 3
		s["stats"]["denuncias"] += 1
		_rep(2)
		changed.emit()
		return "Denuncia presentada en el SEPRONA con el informe veterinario. %s se queda en el refugio durante el proceso." % a["name"]
	a["owner_case"] = "contactando"
	a["owner_day"] = s["day"] + 1
	changed.emit()
	return "Contactaremos con el dueño de %s." % a["name"]


func _progress_owner_case(a: Dictionary) -> String:
	var case: String = a.get("owner_case", "")
	if case == "" or case == "decidir" or s["day"] < a["owner_day"]:
		return ""
	if case == "denuncia":
		a["owner_case"] = ""
		a["chip"] = "nuestro"
		if rng.randf() < 0.65:
			_rep(6)
			return "⚖ La denuncia por %s ha prosperado: multa al propietario y el animal queda bajo nuestra custodia." % a["name"]
		_rep(1)
		return "⚖ La denuncia por %s se ha archivado por falta de pruebas, pero el dueño renuncia al animal." % a["name"]
	if case == "contactando":
		if a["location"] != "refugio":
			a["owner_day"] = s["day"] + 1
			return ""
		var r := rng.randf()
		if r < 0.5:
			var reward := 0
			if rng.randf() < 0.55:
				reward = rng.randi_range(2, 20) * 10
				_earn(reward, "Recompensa de un dueño")
			_remove_animal(a)
			s["stats"]["to_owner"] += 1
			_rep(2)
			return "🏠 El dueño de %s ha venido a recogerlo.%s" % [a["name"], " Nos ha dado %d € de recompensa." % reward if reward > 0 else ""]
		if r < 0.8:
			a["owner_case"] = ""
			a["chip"] = "nuestro"
			return "El dueño de %s renuncia a él y firma la cesión. Queda con nosotros." % a["name"]
		a["owner_case"] = "sin_respuesta"
		a["owner_day"] = s["day"] + 3
		return "El dueño de %s no responde. Esperaremos unos días antes de tramitarlo como abandono." % a["name"]
	if case == "sin_respuesta":
		a["owner_case"] = ""
		a["chip"] = "nuestro"
		return "Tramitado como abandono: %s queda bajo nuestra custodia." % a["name"]
	return ""


# =====================================================================
# Adopciones
# =====================================================================

func _generate_requests() -> void:
	var chance: float = 0.25 + s["reputation"] / 160.0
	chance += land_info().get("adopt_bonus", 0.0)
	if has_building("patio"):
		chance += 0.15
	for i in 2:
		if s["requests"].size() < 4 and rng.randf() < chance:
			var species := "gato" if rng.randf() < 0.3 else "perro"
			var homes := ["piso pequeño", "piso con terraza", "casa con jardín", "casa de campo"]
			var home: String = homes[rng.randi() % homes.size()]
			var sizes := ["pequeño"] if species == "gato" else (["pequeño", "mediano"] if home.begins_with("piso") else ["mediano", "grande"])
			var families := ["Familia García", "Pareja joven", "Señora jubilada", "Familia con niños", "Estudiante", "Pareja de jubilados", "Familia López", "Chico que vive solo"]
			s["requests"].append({
				"id": s["next_id"],
				"who": families[rng.randi() % families.size()],
				"species": species,
				"size": sizes[rng.randi() % sizes.size()],
				"energy": "tranquilo" if rng.randf() < 0.5 else "enérgico",
				"home": home,
				"days": 3,
			})
			s["next_id"] += 1


func match_score(rq: Dictionary, a: Dictionary) -> int:
	if rq["species"] != a["species"]:
		return -1
	var score := int(rq["size"] == a["size"])
	var e: String = a["energy"]
	if e == rq["energy"] or e == "sociable" or (e == "miedoso" and rq["energy"] == "tranquilo"):
		score += 1
	return score


func adopt(request_id: int, animal_id: int) -> String:
	var rq := _find_id(s["requests"], request_id)
	var a := animal(animal_id)
	if rq.is_empty() or a.is_empty():
		return ""
	if not is_adoptable(a):
		return "%s aún no está listo: falta %s." % [a["name"], ", ".join(missing_for_adoption(a))]
	var score := match_score(rq, a)
	if score < 0:
		return "Buscan otra especie."
	s["requests"].erase(rq)
	var donation := rng.randi_range(0, 4) * 10 * (score + 1)
	_earn(Catalog.ADOPTION_FEE + donation, "Adopción")
	s["stats"]["adopted"] += 1
	s["stats"]["day_adopted"] += 1
	_rep(3 if score == 2 else 1)
	if a["sterilized"]:
		_rep(1)
	var return_chance: float = [0.6, 0.28, 0.05][score]
	if a["energy"] == "miedoso": return_chance += 0.1
	_remove_animal(a)
	if rng.randf() < return_chance:
		var reasons := ["No se adapta al piso", "Ladra demasiado", "Rompe cosas", "Se lleva mal con los niños",
			"No tenemos tiempo para pasearlo", "Es más grande de lo que esperábamos"]
		s["returns"].append({"animal": a, "day": s["day"] + rng.randi_range(2, 8), "reason": reasons[rng.randi() % reasons.size()]})
	if rng.randf() < 0.3:
		s["donors"].append(rng.randi_range(Catalog.DONOR_MONTHLY[0], Catalog.DONOR_MONTHLY[1]))
	changed.emit()
	var fit: String = ["no encaja nada con lo que buscaban", "encaja en parte", "¡encaje perfecto!"][score]
	return "¡%s ha sido adoptado por %s! (%s) +%d €" % [a["name"], rq["who"], fit, Catalog.ADOPTION_FEE + donation]


func reject_request(request_id: int) -> void:
	var rq := _find_id(s["requests"], request_id)
	if not rq.is_empty():
		s["requests"].erase(rq)
		changed.emit()


# =====================================================================
# Compras, construcción, personal, donantes, subvenciones
# =====================================================================

func buy_product(id: String, qty: int = 1) -> String:
	var p := _find(Catalog.PRODUCTS, id)
	var price := int(p["price"] * qty * (0.9 if has_building("almacen") else 1.0))
	if not can_afford(price):
		return "No tienes dinero suficiente."
	_spend(price, p["name"])
	s["stock"][id] += p["amount"] * qty
	changed.emit()
	return "Comprado: %d × %s (%d €)" % [qty, p["name"], price]


func buy_vehicle(id: String) -> String:
	var v := _find(Catalog.VEHICLES, id)
	if id in s["vehicles"]:
		return "Ya lo tienes."
	if not can_afford(v["price"]):
		return "No tienes dinero suficiente."
	_spend(v["price"], v["name"])
	s["vehicles"].append(id)
	s["vehicle"] = id
	changed.emit()
	return "¡Has comprado: %s! Ya lo estás usando." % v["name"]


func use_vehicle(id: String) -> String:
	if not id in s["vehicles"]:
		return ""
	var cap: int = _find(Catalog.VEHICLES, id)["capacity"]
	if carried().size() > cap:
		return "Llevas demasiados animales para cambiar a ese vehículo."
	s["vehicle"] = id
	changed.emit()
	return "Ahora vas en: %s." % _find(Catalog.VEHICLES, id)["name"]


func buy_equipment(id: String) -> String:
	var e := _find(Catalog.EQUIPMENT, id)
	if has_equipment(id):
		return "Ya lo tienes."
	if not can_afford(e["price"]):
		return "No tienes dinero suficiente."
	_spend(e["price"], e["name"])
	s["equipment"].append(id)
	changed.emit()
	return "Comprado: %s." % e["name"]


func can_build(b: Dictionary) -> String:
	if s["tier"] < b["req_tier"]:
		return "Necesita un terreno mayor"
	if not b.get("repeat", false) and has_building(b["id"]):
		return "Ya construido"
	if not can_afford(b["price"]):
		return "Sin dinero"
	return ""


func build(id: String) -> String:
	var b := _find(Catalog.BUILDINGS, id)
	var why := can_build(b)
	if why != "":
		return why
	_spend(b["price"], b["name"])
	s["buildings"][id] = s["buildings"].get(id, 0) + 1
	advance_minutes(30)
	changed.emit()
	world_changed.emit()
	return "Construido: %s." % b["name"]


func buy_land_upgrade(id: String) -> String:
	var l := _find(Catalog.LANDS, id)
	if l["tier"] != s["tier"] + 1:
		return "Primero amplía al terreno anterior."
	if not can_afford(l["price"]):
		return "No tienes dinero suficiente."
	_spend(l["price"], l["name"])
	s["tier"] = l["tier"]
	_rep(3)
	changed.emit()
	world_changed.emit()
	return "¡Terreno ampliado! %s" % l["name"]


func hire(id: String) -> String:
	var st := _find(Catalog.STAFF, id)
	if id == "paseador" and not has_building("patio"):
		return "Necesitas el patio de paseo."
	if id == "peluquero" and not has_building("limpieza"):
		return "Necesitas la zona de limpieza."
	if id == "veterinario" and not has_building("consulta"):
		return "Necesitas la consulta veterinaria."
	if id == "voluntario":
		if staff_count("voluntario") >= 3 + s["reputation"] / 15:
			return "No hay más voluntarios disponibles. Sube la reputación o haz campañas."
	s["staff"][id] = staff_count(id) + 1
	changed.emit()
	return "Se incorpora: %s%s." % [st["name"], " (%d €/mes)" % st["wage"] if st["wage"] > 0 else ""]


func fire(id: String) -> String:
	if staff_count(id) <= 0:
		return ""
	s["staff"][id] -= 1
	changed.emit()
	return "Has prescindido de un/a %s." % _find(Catalog.STAFF, id)["name"].to_lower()


func run_campaign(id: String) -> String:
	var c := _find(Catalog.CAMPAIGNS, id)
	if s["reputation"] < c.get("min_rep", 0):
		return "Necesitas reputación %d." % c["min_rep"]
	if not can_afford(c["price"]):
		return "No tienes dinero suficiente."
	_spend(c["price"], c["name"])
	var bonus: int = s["reputation"] / 25
	var new_donors := rng.randi_range(c["donors"][0], c["donors"][1] + bonus)
	for i in new_donors:
		s["donors"].append(rng.randi_range(Catalog.DONOR_MONTHLY[0], Catalog.DONOR_MONTHLY[1]))
	var cash := 0
	if c.has("cash"):
		cash = rng.randi_range(c["cash"][0], c["cash"][1])
		_earn(cash, c["name"])
	if new_donors > 0 and staff_count("voluntario") < 2 + s["reputation"] / 15 and rng.randf() < 0.4:
		s["staff"]["voluntario"] = staff_count("voluntario") + 1
	advance_minutes(60)
	changed.emit()
	return "%s: %d nuevos socios%s." % [c["name"], new_donors, ", %d € recaudados" % cash if cash > 0 else ""]


func grant_check() -> Array:
	var g: Dictionary = Catalog.GRANT
	var list := sheltered()
	var chipped := list.filter(func(a: Dictionary) -> bool: return a["chip"] == "nuestro").size()
	var ratio := float(chipped) / maxf(1.0, list.size())
	return [
		["Reputación ≥ %d" % g["min_rep"], s["reputation"] >= g["min_rep"]],
		["≥ %d %% de animales con chip" % int(g["min_chipped"] * 100), list.size() >= 3 and ratio >= g["min_chipped"]],
		["Zona de cuarentena", has_building("cuarentena")],
		["Sin cuotas del préstamo impagadas", s["loan"].get("missed", 0) == 0],
		["No haber cobrado en los últimos 12 meses", s["day"] - s["grant_day"] >= 360],
	]


func apply_grant() -> String:
	for req in grant_check():
		if not req[1]:
			return "No cumples: %s." % req[0]
	# Inspección.
	var g: Dictionary = Catalog.GRANT
	var problems: PackedStringArray = []
	if average("hygiene") < g["min_hygiene"]: problems.append("higiene insuficiente")
	if average("health") < 55: problems.append("salud de los animales")
	if occupancy() > slots(): problems.append("sobreocupación")
	s["grant_day"] = s["day"]
	advance_minutes(90)
	if problems.is_empty():
		_earn(g["amount"], g["name"])
		_rep(4)
		changed.emit()
		return "Inspección superada. ¡Subvención concedida: %d €!" % g["amount"]
	_rep(-3)
	changed.emit()
	return "Inspección no superada (%s). Podrás volver a pedirla dentro de un año." % ", ".join(problems)


# =====================================================================
# Eventos
# =====================================================================

func _random_event() -> String:
	if s["day"] < 3 or rng.randf() > 0.22:
		return ""
	var month := month_index()
	var pool := ["camada", "donacion_pienso", "voluntario", "inspeccion", "parvo", "temporal", "queja", "prensa"]
	if month in [9, 10, 11]:  # junio, julio, agosto
		pool += ["calor", "calor", "incendio", "abandono_verano"]
	if month in [1, 2, 3]:  # oct-dic: lluvias
		pool += ["inundacion"]
	if month == 5:  # febrero
		pool += ["caza", "caza"]
	var e: String = pool[rng.randi() % pool.size()]
	match e:
		"camada":
			var n := rng.randi_range(3, 5)
			for i in n:
				var a := _make_animal({"species": "perro" if rng.randf() < 0.6 else "gato", "size": "pequeño", "easy": true})
				a["age"] = 0
				a["location"] = "refugio"
				a["origin"] = "Caja en la puerta"
				s["animals"].append(a)
			return "📦 Alguien ha dejado una caja con %d cachorros en la puerta del refugio." % n
		"donacion_pienso":
			s["stock"]["pienso"] += 30.0
			return "🎁 La tienda de piensos nos dona 30 kg de pienso."
		"voluntario":
			s["staff"]["voluntario"] = staff_count("voluntario") + 1
			return "🙋 Se ofrece un nuevo voluntario."
		"inspeccion":
			if average("hygiene") < 40 or occupancy() > slots() + 2:
				_spend(500, "Multa de inspección")
				_rep(-5)
				return "📋 Inspección sorpresa: suspenso. Multa de 500 €."
			_rep(2)
			return "📋 Inspección sorpresa superada."
		"parvo":
			if has_building("cuarentena"):
				return "🦠 Brote de parvovirus en la comarca. La cuarentena ha protegido al refugio."
			var n := 0
			for a in sheltered():
				if not a["vaccinated"] and a["species"] == "perro" and rng.randf() < 0.6:
					a["sick"] = true
					n += 1
			return "🦠 Brote de parvovirus: %d perros sin vacunar han enfermado." % n if n > 0 else "🦠 Brote de parvovirus cerca. Tus perros vacunados están a salvo."
		"temporal":
			s["events"]["temporal"] = 2
			return "🌬 Temporal de viento: las vallas sufren y hay más riesgo de fugas."
		"queja":
			if occupancy() > 6 and not has_building("vallado"):
				_spend(200, "Multa por ruidos")
				return "📢 Un vecino denuncia los ladridos: multa de 200 €."
			return ""
		"prensa":
			if s["stats"]["rescued"] >= 5:
				_rep(4)
				s["donors"].append(rng.randi_range(10, 30))
				return "📰 El periódico local publica un reportaje sobre el refugio. +reputación y un nuevo socio."
			return ""
		"calor":
			s["events"]["calor"] = 4
			_spend(15 * occupancy(), "Agua y ventiladores (ola de calor)")
			return "🌡 Ola de calor: más agua y riesgo de golpes de calor (el patio con sombra ayuda)."
		"incendio":
			s["events"]["incendio"] = 2
			for i in rng.randi_range(2, 4):
				_new_call({"injured": true, "spot": "Pinar"})
			return "🔥 Incendio forestal en el pinar: avisos urgentes de animales heridos."
		"inundacion":
			s["events"]["temporal"] = 1
			for i in rng.randi_range(1, 3):
				_new_call({"spot": "Ribera del río"})
			if land_info().get("flood_risk", false):
				_spend(1500, "Daños por inundación")
				for a in sheltered():
					a["hygiene"] = maxi(0, a["hygiene"] - 30)
				return "🌊 DANA: el río se desborda e inunda el refugio. Daños por 1.500 €."
			return "🌊 DANA: el río se desborda. Hay animales atrapados en la ribera."
		"caza":
			s["events"]["caza"] = 5
			return "🐕 Fin de la temporada de caza: se disparan los abandonos de perros."
		"abandono_verano":
			for i in 2:
				_new_call({})
			return "🧳 Llegan las vacaciones y, con ellas, los abandonos."
	return ""


# =====================================================================
# Utilidades
# =====================================================================

func _spend(amount: int, what: String) -> void:
	s["money"] -= amount
	s["stats"]["day_spent"] += amount
	_log("-%d € · %s" % [amount, what])


func _earn(amount: int, what: String) -> void:
	s["money"] += amount
	s["stats"]["day_income"] += amount
	_log("+%d € · %s" % [amount, what])


func _rep(delta: int) -> void:
	s["reputation"] = clampi(s["reputation"] + delta, 0, 100)


func _log(text: String) -> void:
	s["log"].push_front("[%s %s] %s" % [date_text().get_slice("·", 0).strip_edges(), time_text(), text])
	if s["log"].size() > 80:
		s["log"].pop_back()


func _reset_day_stats() -> void:
	for k in ["day_adopted", "day_rescued", "day_income", "day_spent"]:
		s["stats"][k] = 0


func _remove_animal(a: Dictionary) -> void:
	s["animals"].erase(a)
	world_changed.emit()


func _find(list: Array, id: String) -> Dictionary:
	for x in list:
		if x["id"] == id:
			return x
	return {}


func _find_by_name(list: Array, n: String) -> Dictionary:
	for x in list:
		if x["name"] == n:
			return x
	return list[0]


func _find_id(list: Array, id: int) -> Dictionary:
	for x in list:
		if x["id"] == id:
			return x
	return {}


func _clamp_world(p: Vector3) -> Vector3:
	return Vector3(clampf(p.x, -150, 150), 0, clampf(p.z, -150, 150))


# =====================================================================
# Guardado
# =====================================================================

func save_game() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(_encode(s)))


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func load_game() -> bool:
	if not has_save():
		return false
	var data = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if typeof(data) != TYPE_DICTIONARY:
		return false
	s = _decode(data)
	changed.emit()
	world_changed.emit()
	return true


func _encode(v: Variant) -> Variant:
	match typeof(v):
		TYPE_VECTOR3:
			return {"__v3": [v.x, v.y, v.z]}
		TYPE_DICTIONARY:
			var d := {}
			for k in v:
				d[k] = _encode(v[k])
			return d
		TYPE_ARRAY:
			return v.map(_encode)
	return v


func _decode(v: Variant) -> Variant:
	match typeof(v):
		TYPE_DICTIONARY:
			if v.has("__v3"):
				return Vector3(v["__v3"][0], v["__v3"][1], v["__v3"][2])
			var d := {}
			for k in v:
				d[k] = _decode(v[k])
			return d
		TYPE_ARRAY:
			return v.map(_decode)
		TYPE_FLOAT:
			# JSON convierte los enteros en float: los devolvemos a int si no tienen decimales.
			if v == floor(v) and absf(v) < 1e12:
				return int(v)
	return v


# =====================================================================
# Controles
# =====================================================================

func _setup_input() -> void:
	var keys := {
		"move_forward": [KEY_W, KEY_UP], "move_back": [KEY_S, KEY_DOWN],
		"move_left": [KEY_A, KEY_LEFT], "move_right": [KEY_D, KEY_RIGHT],
		"sprint": [KEY_SHIFT], "jump": [KEY_SPACE], "interact": [KEY_E],
		"tablet": [KEY_TAB], "camera": [KEY_V], "menu": [KEY_ESCAPE],
	}
	for action: String in keys:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for k: Key in keys[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = k
			InputMap.action_add_event(action, ev)
