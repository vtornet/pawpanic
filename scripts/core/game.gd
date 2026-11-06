extends Node
## Estado y reglas de la partida (autoload "Game").
## No sabe nada del mundo 3D ni de la interfaz: solo datos y decisiones.
## El mundo y la interfaz escuchan sus señales y llaman a sus acciones.

signal changed                       # cualquier dato ha cambiado (refrescar interfaz)
signal world_changed                 # animales en la calle / escapados han cambiado
signal notify(text: String, kind: String)
signal day_ended(summary: String)
signal game_over(reason: String)
signal adopted(request: Dictionary, animal: Dictionary)   # para que el mundo muestre a la familia marchándose
signal departed(visit: Dictionary, animal: Dictionary)    # un dueño se va con su animal
signal sound(id: String)              # efecto de sonido de una acción (lo reproduce el autoload Sound)

const SAVE_PATH := "user://partida.json"
const MONTHS := ["septiembre", "octubre", "noviembre", "diciembre", "enero", "febrero",
	"marzo", "abril", "mayo", "junio", "julio", "agosto"]

const DOG_NAMES := ["Toby", "Luna", "Coco", "Rocky", "Lola", "Max", "Nala", "Bruno", "Kira", "Thor",
	"Canela", "Chispa", "Lucas", "Mía", "Duna", "Rufo", "Pipa", "Simba", "Trufa", "Lur", "Bimba", "Zeus",
	"Nieve", "Odín", "Sasha", "Tango", "Boira", "Golfo", "Perla", "Moro"]
const RABBIT_NAMES := ["Tambor", "Copito", "Bolita", "Orejitas", "Algodón", "Zanahoria", "Pompón", "Nube"]
const FARM_NAMES := ["Platero", "Lucero", "Canela", "Rocío", "Trueno", "Margarita", "Perla", "Moreno", "Estrella", "Chispa"]
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
		"stock": {"pienso": 15.0, "pienso_premium": 0.0, "limpieza": 5.0, "arena": 0.0, "heno": 0.0},
		"staff": {"voluntario": 2},
		"donors": [12, 15],
		"animals": [],
		"calls": [],
		"requests": [],
		"returns": [],          # {animal, day}
		"consequences": [],     # adopciones a quien no debía: {type, animal, day}
		"visits": [],           # dueños que recogen y familias que devuelven, en persona
		"followups": [],        # seguimiento de las adopciones recientes
		"achievements": {},     # logros conseguidos: id -> día
		"next_id": 1,
		"fed_today": false,
		"forwarded_today": 0,
		"cleaned_today": false,
		"events": {},           # evento -> días restantes
		"grant_day": -999,
		"log": [],
		"tutorial": {"active": true, "step": 0, "flags": {}},
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
	if own:
		return sv["own"]
	if service != "bano" and s.get("vet_agreement", false):
		return int(round(sv["ext"] * (1.0 - Catalog.VET_AGREEMENT["discount"])))
	return sv["ext"]


## Convenio con la clínica: precios especiales para la protectora.
func can_sign_agreement() -> bool:
	return not s.get("vet_agreement", false) and s["reputation"] >= Catalog.VET_AGREEMENT["min_rep"]


func sign_agreement() -> String:
	if not can_sign_agreement():
		return ""
	s["vet_agreement"] = true
	_log("Firmado el convenio con la clínica veterinaria (-%d %% en servicios)." % int(Catalog.VET_AGREEMENT["discount"] * 100))
	sound.emit("sello_documento")
	changed.emit()
	return "«Trato hecho. Con lo que estáis haciendo por los animales del pueblo, os lo merecéis. Desde hoy, un %d %% menos en todo.»" % int(Catalog.VET_AGREEMENT["discount"] * 100)


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
	sound.emit("sello_documento")
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
	sound.emit("sello_documento")
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
	# Primer aviso: cerca y sencillo, como tutorial (sano, sin dueño, sin miedo).
	_new_call({"species": "perro", "near": true, "easy": true})
	var first := animal(s["calls"][-1]["animal"])
	first["has_owner_chip"] = false
	first["sick"] = false
	first["injured"] = false
	first["abuse"] = false
	first["skittish"] = false
	s["calls"][-1]["urgent"] = false
	s["calls"][-1]["deadline"] = s["day"] + 1
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
	_update_visits()
	if s["minute"] >= Catalog.DAY_END:
		end_day()
	elif now != before:
		changed.emit()


func _hourly() -> void:
	var hour := int(s["minute"]) / 60
	# Avisos según el tamaño del refugio: uno al día al principio, dos o tres con un gran refugio.
	var call_chance: float = 0.05 + 0.035 * s["tier"]
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
	if Tutorial.current().get("id", "") == "dormir":
		Tutorial.flag("dormir")
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
		var need := feed_need(a)
		var food := food_of(a)
		var got_food := false
		if fed < care_capacity:
			if food == "heno":
				if s["stock"]["heno"] >= need:
					s["stock"]["heno"] -= need
					got_food = true
			elif s["stock"]["pienso_premium"] >= need:
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
		if over >= 2:
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
		var sick_chance := 0.008 * (2.0 if a["hygiene"] < 40 else 1.0) * (0.5 if a["vaccinated"] else 1.0)
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

	# --- Fauna silvestre que no llegó al centro ---
	for a in carried().duplicate():
		if is_wild(a):
			_remove_animal(a)
			_rep(-1)
			lines.append("El %s que llevabas no ha llegado a tiempo al centro de recuperación. No ha sobrevivido." % a["name"].to_lower())

	# --- Casas de acogida ---
	lines.append_array(_foster_day())

	# --- Fugas ---
	var escape_base := 0.0015 if has_building("vallado") else 0.005
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
			st["last_lost_day"] = s["day"]
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
			_close_followup(r["animal"]["id"])
			var v := _schedule_return(r["animal"], r["reason"], r.get("who", "La familia adoptante"))
			lines.append("↩ %s ha llamado: quieren devolver a %s. Vendrán mañana." % [v["who"], r["animal"]["name"]])

	# --- Visitas que se quedaron esperando al cerrar ---
	for v in s["visits"].duplicate():
		if v["state"] == "esperando":
			lines.append(_visit_timeout(v))

	# --- Consecuencias de adopciones a quien no debía ---
	for c in s["consequences"].duplicate():
		if c["day"] <= s["day"]:
			s["consequences"].erase(c)
			_close_followup(c["animal"]["id"])
			lines.append(_consequence(c))
	# El seguimiento se hace durante el primer mes.
	for f in s["followups"].duplicate():
		if f["closed"] or s["day"] - f["day"] > 30:
			s["followups"].erase(f)

	# --- Coordinador de adopciones: seguimiento automático ---
	lines.append_array(_coordinator_day())

	# --- Solicitudes de adopción ---
	for rq in s["requests"].duplicate():
		if rq.get("state", "") == "esperando":
			# Llegaron tarde: vuelven mañana.
			rq["state"] = "pendiente"
			rq["visit_at"] = (s["day"] + 1) * 1440 + rng.randi_range(10 * 60, 13 * 60)
			lines.append("%s se ha ido al cerrar; volverá mañana por la mañana." % rq["who"])
	_generate_requests(true)

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
	s["forwarded_today"] = 0
	_reset_day_stats()

	if s["loan"].get("missed", 0) >= 3:
		s["step"] = "fin"
		game_over.emit("Tres cuotas del préstamo sin pagar. El banco ha embargado el terreno.")
	elif s["reputation"] <= 0:
		s["step"] = "fin"
		game_over.emit("La protectora ha perdido toda la confianza. La administración retira la licencia.")
	else:
		# Avisos de primera hora.
		for i in rng.randi_range(0, s["tier"] / 2):
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
	# Bajas normales cada mes (y más si la reputación cae).
	var leave_p := 0.04 + (0.08 if s["reputation"] < 35 else 0.0)
	var gone := 0
	for d in s["donors"].duplicate():
		if rng.randf() < leave_p:
			s["donors"].erase(d)
			gone += 1
	if gone > 0:
		out.append("Se han dado de baja %d socio(s)." % gone)
	return out


# =====================================================================
# Avisos y animales
# =====================================================================

## Ración diaria (kg) y comida de cada animal según su especie.
func feed_need(a: Dictionary) -> float:
	return Catalog.FEED_PER_DAY[a["size"]] * Catalog.SPECIES.get(a["species"], {}).get("factor", 1.0)


## Consumo diario total de una comida ("pienso" o "heno").
func daily_need(food: String) -> float:
	var t := 0.0
	for a in sheltered():
		if food_of(a) == food:
			t += feed_need(a)
	return t


func food_of(a: Dictionary) -> String:
	return Catalog.SPECIES.get(a["species"], {}).get("food", "pienso")


func is_large(a: Dictionary) -> bool:
	return Catalog.SPECIES.get(a["species"], {}).get("large", false)


## Especie de un animal nuevo: perros y gatos siempre; conejos y granja solo si hay dónde alojarlos.
func is_wild(a: Dictionary) -> bool:
	return Catalog.SPECIES.get(a["species"], {}).get("wild", false)


## Especie de un aviso: a veces es fauna silvestre herida.
func _call_species() -> String:
	if rng.randf() < 0.1:
		return ["erizo", "ave", "tortuga"][rng.randi() % 3]
	return _random_species()


func _random_species() -> String:
	var r := rng.randf()
	if has_building("establo") and r < 0.12:
		var f := rng.randf()
		return "cabra" if f < 0.5 else ("burro" if f < 0.8 else "caballo")
	if has_building("conejera") and r < 0.24:
		return "conejo"
	return "gato" if rng.randf() < 0.3 else "perro"


func _make_animal(opts: Dictionary) -> Dictionary:
	var species: String = opts.get("species", _random_species())
	if Catalog.SPECIES.get(species, {}).get("wild", false):
		return _make_wild(species)
	var names: Array = {"gato": CAT_NAMES, "conejo": RABBIT_NAMES, "cabra": FARM_NAMES, "burro": FARM_NAMES, "caballo": FARM_NAMES}.get(species, DOG_NAMES)
	var size: String = opts.get("size", "")
	if size == "":
		size = Catalog.SPECIES.get(species, {}).get("size", ["pequeño", "mediano", "grande"][rng.randi() % 3])
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


## Fauna silvestre herida: siempre urgente, sin chip y sin dueño.
const WILD_NAMES := {"erizo": ["Erizo"], "ave": ["Cernícalo", "Mochuelo", "Lechuza", "Ratonero"], "tortuga": ["Tortuga mora", "Galápago"]}


func _make_wild(species: String) -> Dictionary:
	var names: Array = WILD_NAMES[species]
	var a := {
		"id": s["next_id"], "name": names[rng.randi() % names.size()], "species": species, "size": "pequeño",
		"energy": "miedoso", "age": rng.randi_range(1, 6), "sex": "macho" if rng.randf() < 0.5 else "hembra",
		"health": rng.randi_range(25, 55), "nutrition": 50, "hygiene": 60, "mood": 30,
		"reviewed": false, "chip": "no", "has_owner_chip": false, "vaccinated": false, "sterilized": false,
		"dewormed": false, "injured": true, "sick": false, "abuse": false, "abuse_known": false, "skittish": false,
		"location": "calle", "pos": Vector3.ZERO, "days_in": 0, "returned_count": 0, "owner_case": "", "owner_day": 0, "origin": "",
	}
	s["next_id"] += 1
	return a


func _new_call(opts: Dictionary) -> void:
	if s["calls"].size() >= 6:
		return
	if not opts.has("species") and not opts.get("easy", false):
		opts = opts.duplicate()
		opts["species"] = _call_species()
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
	var desc := "%s avisa: %s %s %s en %s" % [who, a["species"],
		a["size"], "herido" if a["injured"] else ("en mal estado" if a["health"] < 40 else "abandonado"), spot["name"]]
	if is_wild(a):
		desc = "%s avisa: %s herido en %s. Es fauna protegida: hay que llevarlo al centro de recuperación (CREA)." % [who, a["name"].to_lower(), spot["name"]]
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
			_rep(-1)
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
	s["stats"]["last_lost_day"] = s["day"]
	_rep(-2)
	return "‼ %s se ha escapado y no tenía chip. No podremos encontrarlo." % a["name"]


## Recoger un animal en la calle o un escapado.
func pick_up(id: int) -> String:
	var a := animal(id)
	if a.is_empty() or not a["location"] in ["calle", "escapado"]:
		return ""
	var sp: Dictionary = Catalog.SPECIES.get(a["species"], {})
	if sp.get("needs", "") != "" and not has_building(sp["needs"]):
		return "No tienes dónde alojar un %s (necesitas: %s). Deriva el aviso a otra protectora." % [a["species"], sp["needs"]]
	if sp.get("trailer", false) and (not has_equipment("remolque") or s["vehicle"] in ["a_pie", "bici"]):
		return "Para llevar un %s necesitas el remolque para équidos y un coche o furgoneta." % a["species"]
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
	sound.emit("recoger_animal")
	advance_minutes(10)
	world_changed.emit()
	changed.emit()
	return "Has recogido a %s." % a["name"]


func deposit_all() -> String:
	var n := 0
	var wild := 0
	for a in carried():
		if is_wild(a):
			wild += 1
			continue
		a["location"] = "refugio"
		n += 1
	if n == 0:
		if wild > 0:
			return "La fauna silvestre no puede quedarse en el refugio: es protegida. Llévala al centro de recuperación (CREA)."
		return "No llevas ningún animal."
	sound.emit("reja")
	var msg := "Has dejado %d animal(es) en el refugio." % n
	if wild > 0:
		msg += " La fauna silvestre sigue contigo: llévala al CREA."
	if occupancy() > slots():
		msg += " ⚠ Hay más animales que plazas."
	changed.emit()
	return msg


# =====================================================================
# Cuando el refugio está lleno: derivar avisos y casas de acogida
# =====================================================================

const FORWARD_PER_DAY := 2
const SHELTERS := ["la protectora de Lepe", "la asociación de Ayamonte", "el refugio de Cartaya", "la protectora comarcal"]


## Pasar un aviso a otra protectora. Sin penalización, pero solo un par al día.
func forward_call(call_id: int) -> String:
	var c := _find_id(s["calls"], call_id)
	if c.is_empty():
		return ""
	if s.get("forwarded_today", 0) >= FORWARD_PER_DAY:
		return "Hoy ya no queda sitio en ninguna protectora cercana. Tendrás que atenderlo tú."
	s["forwarded_today"] = s.get("forwarded_today", 0) + 1
	s["calls"].erase(c)
	var a := animal(c["animal"])
	if not a.is_empty() and a["location"] == "calle":
		_remove_animal(a)
	changed.emit()
	return "Has llamado a %s: se hacen cargo del aviso de %s." % [SHELTERS[rng.randi() % SHELTERS.size()], c["place"]]


## Casas de acogida disponibles: algunos voluntarios (y más con buena reputación).
func foster_capacity() -> int:
	return staff_count("voluntario") / 2 + int(s["reputation"]) / 25


func fostered() -> Array:
	return animals_at("acogida")


func send_to_foster(id: int) -> String:
	var a := animal(id)
	if a.is_empty() or a["location"] != "refugio":
		return ""
	if fostered().size() >= foster_capacity():
		return "No hay casas de acogida libres. Consigue más voluntarios o mejora la reputación."
	if a["sick"] or a["injured"]:
		return "Las casas de acogida no pueden atender a animales enfermos o heridos."
	a["location"] = "acogida"
	a["foster_days"] = 0
	changed.emit()
	return "%s se va a una casa de acogida. Allí estará mejor mientras le buscamos familia." % a["name"]


func back_from_foster(id: int) -> String:
	var a := animal(id)
	if a.is_empty() or a["location"] != "acogida":
		return ""
	a["location"] = "refugio"
	changed.emit()
	return "%s vuelve al refugio desde su casa de acogida." % a["name"]


## Cada día en acogida: mejora el ánimo, cuesta algo de pienso y a veces la familia se lo queda.
func _foster_day() -> PackedStringArray:
	var out: PackedStringArray = []
	for a in fostered():
		a["foster_days"] = a.get("foster_days", 0) + 1
		a["mood"] = mini(100, a["mood"] + 5)
		a["hygiene"] = mini(100, a["hygiene"] + 5)
		a["nutrition"] = mini(100, a["nutrition"] + 10)
		_spend(1, "Pienso para casas de acogida")
		# Solo pueden adoptarlo si ya está preparado (revisado, vacunado, desparasitado y con chip).
		var ready: bool = a["reviewed"] and a["vaccinated"] and a["dewormed"] and a["chip"] == "nuestro" and a.get("owner_case", "") == ""
		if ready and a["foster_days"] >= 7 and rng.randf() < 0.06:
			_remove_animal(a)
			s["stats"]["adopted"] += 1
			_earn(Catalog.ADOPTION_FEE, "Adopción (familia de acogida)")
			_rep(3)
			out.append("🏠 La familia de acogida de %s ha decidido adoptarlo. ¡Se queda con ellos para siempre!" % a["name"])
	return out


## Entregar la fauna silvestre que llevas al centro de recuperación.
func deliver_wildlife() -> String:
	var wild := carried().filter(is_wild)
	if wild.is_empty():
		return ""
	var names: PackedStringArray = []
	for a in wild:
		names.append(a["name"].to_lower())
		_remove_animal(a)
		_rep(3 if a["health"] >= 40 else 2)
		s["stats"]["wild"] = s["stats"].get("wild", 0) + 1
	advance_minutes(15)
	changed.emit()
	var msg := "«Gracias. Nos ocupamos de %s; cuando se recupere, lo devolveremos a su medio.»" % ", ".join(names)
	if s["stats"]["wild"] == 3:
		msg += " «Ya sois colaboradores habituales del centro. Os pondremos en nuestra web.»"
		_rep(3)
	return msg


func take_out(id: int) -> String:
	var a := animal(id)
	if a.is_empty() or a["location"] != "refugio":
		return ""
	if carried().size() >= capacity():
		return "No puedes llevar más animales con %s." % vehicle()["name"]
	a["location"] = "llevando"
	sound.emit("reja")
	changed.emit()
	return "Llevas a %s contigo." % a["name"]


func feed_all() -> String:
	if s["fed_today"]:
		return "Ya les has dado de comer hoy."
	s["fed_today"] = true
	sound.emit("comer")
	advance_minutes(20 + 3 * occupancy())
	changed.emit()
	return "Les has puesto comida y agua a todos (se descuenta el pienso al final del día)."


func clean_all() -> String:
	if s["cleaned_today"]:
		return "Ya has limpiado hoy."
	s["cleaned_today"] = true
	sound.emit("fregona_cubo")
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
	if is_wild(a) and service != "tratamiento":
		return "Es fauna silvestre: aquí solo se le pueden dar primeros auxilios (tratamiento). Llévalo al CREA."
	var price := service_price(service, own)
	if not own and is_large(a) and a["location"] == "refugio":
		price += Catalog.LARGE_VET_TRAVEL  # el veterinario de grandes animales viene al refugio
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
				# Si ya se estaba contactando con el dueño (lector de chips), ahora toca decidir si denunciar.
				if a["chip"] == "dueño" and a.get("owner_case", "") in ["contactando", "sin_respuesta"]:
					a["owner_case"] = "decidir"
					found.append("el chip identifica al propietario: puedes denunciarle")
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
	sound.emit("servicio_" + service + ":" + a["species"])
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
		sound.emit("sello_documento")
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
			a["owner_case"] = "recogida"
			var owners := ["Familia Romero", "Señor Vázquez", "Carmen, la dueña", "Familia Domínguez", "Un chico joven", "Matrimonio mayor"]
			var v := {"id": s["next_id"], "kind": "dueño", "who": owners[rng.randi() % owners.size()], "animal_id": a["id"],
				"state": "pendiente", "visit_at": (s["day"] + 1) * 1440 + rng.randi_range(10 * 60, 18 * 60), "look": rng.randi()}
			s["next_id"] += 1
			s["visits"].append(v)
			var m: int = v["visit_at"] % 1440
			return "📞 El dueño de %s ha contestado: vendrá a recogerlo mañana a las %02d:%02d." % [a["name"], m / 60, m % 60]
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

## Minuto absoluto de la partida (para programar visitas).
func now_abs() -> int:
	return int(s["day"]) * 1440 + int(s["minute"])


func _generate_requests(next_morning: bool = false) -> void:
	var chance: float = 0.25 + s["reputation"] / 160.0
	chance += land_info().get("adopt_bonus", 0.0)
	if has_building("patio"):
		chance += 0.15
	for i in 3:
		if s["requests"].size() < 4 and rng.randf() < chance:
			var species := _random_species()  # nunca fauna silvestre
			var homes := ["piso pequeño", "piso con terraza", "casa con jardín", "casa de campo"]
			var home: String = homes[rng.randi() % homes.size()]
			if Catalog.SPECIES[species].get("large", false):
				home = "casa de campo" if rng.randf() < 0.5 else "finca con terreno"
			var sizes := ["pequeño", "mediano"] if home.begins_with("piso") else ["mediano", "grande"]
			if Catalog.SPECIES[species].has("size"):
				sizes = [Catalog.SPECIES[species]["size"]]
			var families := ["Familia García", "Pareja joven", "Señora jubilada", "Familia con niños", "Estudiante", "Pareja de jubilados", "Familia López", "Chico que vive solo"]
			var rq_new := {
				"id": s["next_id"],
				"who": families[rng.randi() % families.size()],
				"species": species,
				"size": sizes[rng.randi() % sizes.size()],
				"energy": "tranquilo" if rng.randf() < 0.5 else "enérgico",
				"home": home,
				"state": "pendiente",
				"visit_at": _visit_time(next_morning),
				"look": rng.randi(),
				"suspect": "",
			}
			# Algunos solicitantes no son aptos. El jugador tiene que darse cuenta hablando con ellos.
			if rng.randf() < SUSPECT_CHANCE:
				var type: String = SUSPECTS.keys()[rng.randi() % SUSPECTS.size()]
				var prof: Dictionary = SUSPECTS[type]
				rq_new["suspect"] = type
				rq_new["who"] = prof["who"][rng.randi() % prof["who"].size()]
				rq_new["species"] = prof["species"][rng.randi() % prof["species"].size()]
				rq_new["size"] = prof["size"][rng.randi() % prof["size"].size()] if rq_new["species"] == "perro" else "pequeño"
				rq_new["energy"] = prof.get("energy", rq_new["energy"])
				rq_new["home"] = prof["home"]
			s["requests"].append(rq_new)
			s["next_id"] += 1
			var rq: Dictionary = s["requests"][-1]
			notify.emit("Nueva solicitud de adopción: %s vendrá al refugio %s." % [rq["who"], visit_text(rq)], "info")


func _visit_time(next_morning: bool) -> int:
	# Visitan entre las 10:00 y las 19:00, hoy o mañana.
	var day: int = s["day"] + (1 if next_morning else rng.randi_range(0, 1))
	var minute := rng.randi_range(10 * 60, 19 * 60)
	var t := day * 1440 + minute
	if t < now_abs() + 30:
		t = (s["day"] + 1) * 1440 + minute
	return t


func visit_text(rq: Dictionary) -> String:
	var t: int = rq["visit_at"]
	var day := t / 1440
	var m := t % 1440
	var when := "hoy" if day == s["day"] else ("mañana" if day == s["day"] + 1 else "el día %d" % day)
	return "%s a las %02d:%02d" % [when, m / 60, m % 60]


## Llegadas y esperas de las familias. Se llama cada vez que avanza el reloj.
func _update_visits() -> void:
	var now := now_abs()
	_update_person_visits(now)
	for rq in s["requests"].duplicate():
		if not rq.has("visit_at"):  # partidas guardadas antes de las visitas
			rq["visit_at"] = _visit_time(false)
		var st: String = rq.get("state", "pendiente")
		if st == "pendiente" and now >= rq["visit_at"] and s["minute"] < Catalog.DAY_END - 120:
			rq["state"] = "esperando"
			rq["wait_until"] = now + 150
			notify.emit("%s ha llegado al refugio para conocer a los animales. Ve a atenderles." % rq["who"], "aviso")
			_log("%s ha llegado al refugio." % rq["who"])
			changed.emit()
		elif st == "esperando" and now > rq["wait_until"]:
			s["requests"].erase(rq)
			_rep(-1)
			notify.emit("%s se ha cansado de esperar y se ha ido." % rq["who"], "mal")
			changed.emit()


func _update_person_visits(now: int) -> void:
	for v in s["visits"].duplicate():
		if v["state"] == "pendiente" and now >= v["visit_at"] and s["minute"] < Catalog.DAY_END - 60:
			v["state"] = "esperando"
			v["wait_until"] = now + 150
			var nm: String = visit_animal_name(v)
			if v["kind"] == "dueño":
				notify.emit("%s ha llegado al refugio para recoger a %s." % [v["who"], nm], "aviso")
			else:
				notify.emit("%s está en la puerta del refugio con %s: quieren devolverlo." % [v["who"], nm], "aviso")
			changed.emit()
		elif v["state"] == "esperando" and now > v["wait_until"]:
			notify.emit(_visit_timeout(v), "mal")
			changed.emit()


## Qué pasa si nadie atiende una visita.
func _visit_timeout(v: Dictionary) -> String:
	if v["kind"] == "dueño":
		v["state"] = "pendiente"
		v["visit_at"] = (s["day"] + 1) * 1440 + rng.randi_range(10 * 60, 18 * 60)
		return "%s se ha cansado de esperar. Volverá mañana a por %s." % [v["who"], visit_animal_name(v)]
	# Devolución: lo dejan atado a la puerta.
	s["visits"].erase(v)
	var a: Dictionary = v["animal"]
	a["location"] = "refugio"
	a["mood"] = maxi(0, a["mood"] - 40)
	a["returned_count"] += 1
	s["animals"].append(a)
	s["stats"]["returned"] += 1
	_rep(-2)
	world_changed.emit()
	return "Nadie atendió a %s y han dejado a %s atado a la puerta del refugio. Está muy asustado." % [v["who"], a["name"]]


func _schedule_return(a: Dictionary, reason: String, who: String) -> Dictionary:
	var v := {"id": s["next_id"], "kind": "devolucion", "who": who, "animal": a, "reason": reason,
		"state": "pendiente", "visit_at": (s["day"] + 1) * 1440 + rng.randi_range(10 * 60, 18 * 60), "look": rng.randi()}
	s["next_id"] += 1
	s["visits"].append(v)
	return v


func visit_animal_name(v: Dictionary) -> String:
	if v["kind"] == "devolucion":
		return v["animal"]["name"]
	return animal(v["animal_id"]).get("name", "su animal")


func person_visits() -> Array:
	return s["visits"].filter(func(v: Dictionary) -> bool: return v["state"] == "esperando")


## Entregar el animal a su dueño.
func hand_over(visit_id: int) -> String:
	var v := _find_id(s["visits"], visit_id)
	if v.is_empty():
		return ""
	var a := animal(v["animal_id"])
	if a.is_empty():
		s["visits"].erase(v)
		changed.emit()
		return "«¿Cómo que no está?»"
	if not a["location"] in ["refugio", "llevando"]:
		return "«¿No está aquí? Bueno... esperaré un poco.»"
	s["visits"].erase(v)
	var reward := 0
	if rng.randf() < 0.55:
		reward = rng.randi_range(2, 20) * 10
		_earn(reward, "Recompensa de un dueño")
	_remove_animal(a)
	sound.emit("perro_contento")
	s["stats"]["to_owner"] += 1
	_rep(2)
	departed.emit(v, a)
	changed.emit()
	var thanks := ["¡%s! ¡Ven aquí, bonito! No sabéis el disgusto que teníamos en casa.", "Ay, %s... Menos mal. Os estaré siempre agradecido.",
		"¡%s! Se escapó por la valla del jardín, ya la hemos arreglado. Mil gracias."]
	var t: String = thanks[rng.randi() % thanks.size()] % a["name"]
	if reward > 0:
		t += " Tomad, %d € para lo que necesitéis, por favor." % reward
	return "«%s»" % t


## Aceptar la devolución.
func take_back(visit_id: int) -> String:
	var v := _find_id(s["visits"], visit_id)
	if v.is_empty():
		return ""
	s["visits"].erase(v)
	var a: Dictionary = v["animal"]
	a["location"] = "refugio"
	a["mood"] = maxi(0, a["mood"] - 30)
	a["returned_count"] += 1
	s["animals"].append(a)
	s["stats"]["returned"] += 1
	_rep(-1)
	sound.emit("jingle_devolucion")
	changed.emit()
	world_changed.emit()
	return "«Lo sentimos mucho, de verdad. Era lo mejor para él.» %s vuelve al refugio, algo desanimado." % a["name"]


## Darles consejos para que lo intenten de nuevo. A veces sale bien.
func advise_keep(visit_id: int) -> String:
	var v := _find_id(s["visits"], visit_id)
	if v.is_empty():
		return ""
	s["visits"].erase(v)
	var a: Dictionary = v["animal"]
	changed.emit()
	if rng.randf() < 0.55:
		_rep(1)
		return "«Vale... lo intentaremos con lo que nos has dicho. Gracias por la paciencia.» Se van con %s." % a["name"]
	s["returns"].append({"animal": a, "day": s["day"] + rng.randi_range(3, 6), "reason": v["reason"], "who": v["who"]})
	return "«Bueno... lo intentaremos, pero no prometemos nada.» Se van con %s." % a["name"]


func visitors() -> Array:
	return s["requests"].filter(func(r: Dictionary) -> bool: return r.get("state", "") == "esperando")


## Llamar a la familia para que venga cuanto antes.
func call_visit_now(request_id: int) -> String:
	var rq := _find_id(s["requests"], request_id)
	if rq.is_empty() or rq.get("state", "") != "pendiente":
		return ""
	rq["visit_at"] = now_abs() + 30
	changed.emit()
	return "Has llamado a %s: vienen en media hora." % rq["who"]


func match_score(rq: Dictionary, a: Dictionary) -> int:
	if rq["species"] != a["species"]:
		return -1
	var score := int(rq["size"] == a["size"])
	var e: String = a["energy"]
	if e == rq["energy"] or e == "sociable" or (e == "miedoso" and rq["energy"] == "tranquilo"):
		score += 1
	return score


const SUSPECT_CHANCE := 0.22
## Perfiles no aptos. "who" son nombres neutros: lo que les delata es lo que dicen.
const SUSPECTS := {
	"cazador": {"who": ["Señor Martín", "Familia López", "Pareja de jubilados"], "species": ["perro"], "size": ["mediano", "grande"], "energy": "enérgico", "home": "casa de campo"},
	"guarda": {"who": ["Chico que vive solo", "Señor Martín"], "species": ["perro"], "size": ["grande"], "energy": "enérgico", "home": "casa con jardín"},
	"criador": {"who": ["Pareja joven", "Familia García", "Señora Ruiz"], "species": ["perro", "gato"], "size": ["pequeño", "mediano"], "home": "casa con jardín"},
	"regalo": {"who": ["Chico que vive solo", "Estudiante", "Pareja joven"], "species": ["perro", "gato"], "size": ["pequeño"], "home": "piso pequeño"},
	"acumulador": {"who": ["Señora jubilada", "Señora Ruiz"], "species": ["gato"], "size": ["pequeño"], "energy": "tranquilo", "home": "piso pequeño"},
}


## Rechazar a una familia en la entrevista.
func refuse_adopter(request_id: int) -> String:
	var rq := _find_id(s["requests"], request_id)
	if rq.is_empty():
		return ""
	s["requests"].erase(rq)
	changed.emit()
	if rq.get("suspect", "") != "":
		s["stats"]["refused_ok"] = s["stats"].get("refused_ok", 0) + 1
		var angry := {
			"cazador": "«¡Pues nada, ya encontraré perro en otro sitio! Con tanta tontería...»",
			"guarda": "«Vaya, por un perro para la nave... Ya lo compraré por internet.»",
			"criador": "«¿Y quién eres tú para decidir? Hay más protectoras.»",
			"regalo": "«Jo, pues vaya sorpresa me habéis chafado.»",
			"acumulador": "«¡Los pobrecitos están mejor conmigo que aquí! No lo entendéis...»",
		}
		return angry.get(rq["suspect"], "«Bueno, pues nada.»")
	_rep(-1)
	return "«Vaya... nos hacía mucha ilusión. Bueno, gracias de todas formas.»"


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
	sound.emit("jingle_adopcion")
	adopted.emit(rq, a)
	var suspect: String = rq.get("suspect", "")
	if suspect != "":
		# Las consecuencias llegan días después.
		s["consequences"].append({"type": suspect, "animal": a, "day": s["day"] + rng.randi_range(3, 9), "who": rq["who"]})
		return_chance = 0.0
	if rng.randf() < return_chance:
		var reasons := ["No se adapta al piso", "Ladra demasiado", "Rompe cosas", "Se lleva mal con los niños",
			"No tenemos tiempo para pasearlo", "Es más grande de lo que esperábamos"]
		s["returns"].append({"animal": a, "day": s["day"] + rng.randi_range(2, 8), "reason": reasons[rng.randi() % reasons.size()], "who": rq["who"]})
	if rng.randf() < 0.3:
		s["donors"].append(rng.randi_range(Catalog.DONOR_MONTHLY[0], Catalog.DONOR_MONTHLY[1]))
	s["followups"].append({"id": s["next_id"], "animal_id": a["id"], "name": a["name"], "species": a["species"],
		"who": rq["who"], "day": s["day"], "called": false, "visited": false, "closed": false})
	s["next_id"] += 1
	changed.emit()
	var fit: String = ["no encaja nada con lo que buscaban", "encaja en parte", "¡encaje perfecto!"][score]
	return "¡%s se va a casa con %s! (%s) +%d €" % [a["name"], rq["who"], fit, Catalog.ADOPTION_FEE + donation]


func _consequence(c: Dictionary) -> String:
	var a: Dictionary = c["animal"]
	var st: Dictionary = s["stats"]
	st["bad_adoptions"] = st.get("bad_adoptions", 0) + 1
	match c["type"]:
		"cazador", "guarda":
			# Reaparece abandonado o en malas condiciones: aviso de rescate. El chip identifica al adoptante.
			var spot := "Pinar" if c["type"] == "cazador" else "Polígono industrial"
			a["location"] = "calle"
			a["health"] = rng.randi_range(12, 30)
			a["nutrition"] = rng.randi_range(5, 20)
			a["hygiene"] = 10
			a["mood"] = 5
			a["injured"] = true
			a["abuse"] = true
			a["abuse_known"] = false
			a["reviewed"] = false
			a["chip"] = "desconocido"
			a["has_owner_chip"] = true   # ahora el chip está a nombre del adoptante
			a["owner_case"] = ""
			a["skittish"] = true
			a["origin"] = spot
			a["pos"] = _find_by_name(SPOTS, spot)["pos"] + Vector3(rng.randf_range(-5, 5), 0, rng.randf_range(-5, 5))
			s["animals"].append(a)
			s["calls"].append({"id": a["id"], "animal": a["id"], "place": spot, "urgent": true, "deadline": s["day"],
				"desc": ("Un senderista avisa: perro muy delgado y herido, abandonado en el %s" if c["type"] == "cazador" else "Un vecino avisa: perro atado sin agua ni sombra en el %s, en muy mal estado") % spot})
			_rep(-6)
			world_changed.emit()
			notify.emit("Aviso urgente en el %s: un perro en muy mal estado." % spot, "mal")
			if c["type"] == "cazador":
				return "‼ Aviso urgente: un perro abandonado y herido en el pinar. Por la descripción... podría ser %s, que adoptó «%s»." % [a["name"], c["who"]]
			return "‼ Aviso urgente: un perro atado en una nave del polígono, en muy mal estado. Podría ser %s, que adoptó «%s»." % [a["name"], c["who"]]
		"criador":
			if a["sterilized"]:
				# No le sirve para criar: lo devuelve.
				_schedule_return(a, "Es que... no es lo que esperábamos. Mejor que se quede aquí.", c["who"])
				return "↩ «%s» quiere devolver a %s. Como está esterilizado, no les sirve para criar." % [c["who"], a["name"]]
			_rep(-6)
			return "‼ Un socio nos envía un anuncio de internet: venden cachorros «de %s», como si fuera de raza, a 400 €. Lo adoptó «%s» y lo están usando para criar." % [a["name"], c["who"]]
		"regalo":
			_rep(-1)
			_schedule_return(a, "Era un regalo sorpresa y al final no lo quería. Nadie tiene tiempo para él.", c["who"])
			return "↩ «%s» quiere devolver a %s: el regalo sorpresa no salió bien." % [c["who"], a["name"]]
		"acumulador":
			a["location"] = "refugio"
			a["health"] = rng.randi_range(25, 45)
			a["hygiene"] = 10
			a["sick"] = true
			s["animals"].append(a)
			var n := rng.randi_range(2, 4)
			for i in n:
				var cat := _make_animal({"species": "gato", "size": "pequeño"})
				cat["location"] = "refugio"
				cat["health"] = rng.randi_range(20, 45)
				cat["sick"] = rng.randf() < 0.6
				cat["origin"] = "Intervención por acumulación"
				s["animals"].append(cat)
			_rep(-4)
			return "‼ El ayuntamiento interviene en el piso de «%s»: más de 30 gatos en condiciones insalubres. Nos traen de vuelta a %s, enfermo, y %d gatos más." % [c["who"], a["name"], n]
	return ""


# =====================================================================
# Seguimiento post-adopción
# =====================================================================

const FOLLOWUP_VISIT_MINUTES := 90


func open_followups() -> Array:
	return s["followups"].filter(func(f: Dictionary) -> bool: return not f["closed"])


func _close_followup(animal_id: int) -> void:
	for f in s["followups"]:
		if f["animal_id"] == animal_id:
			f["closed"] = true


func _pending_return(animal_id: int) -> Dictionary:
	for r in s["returns"]:
		if r["animal"]["id"] == animal_id:
			return r
	return {}


func _pending_consequence(animal_id: int) -> Dictionary:
	for c in s["consequences"]:
		if c["animal"]["id"] == animal_id:
			return c
	return {}


## Estado real de una adopción: "bien", "devolucion" (va a fracasar) o el tipo de adoptante no apto.
func followup_status(f: Dictionary) -> String:
	var c := _pending_consequence(f["animal_id"])
	if not c.is_empty():
		return c["type"]
	if not _pending_return(f["animal_id"]).is_empty():
		return "devolucion"
	return "bien"


## Llamada: rápida. Las familias buenas cuentan la verdad; las no aptas dan largas.
func followup_call(fid: int) -> Dictionary:
	var f := _find_id(s["followups"], fid)
	if f.is_empty():
		return {}
	sound.emit("telefono_llamada")
	advance_minutes(15)
	var status := followup_status(f)
	var first: bool = not f["called"]
	f["called"] = true
	var nm: String = f["name"]
	var t: String
	match status:
		"bien":
			t = ["¡Hola! %s está fenomenal. Ya duerme en el sofá, aunque le hemos dicho mil veces que no.",
				"%s es uno más de la familia. Los niños no se separan de él. ¡Gracias por llamar!",
				"Todo muy bien. %s se ha adaptado genial, el veterinario dice que está estupendo."][rng.randi() % 3] % nm
			if first:
				_rep(1)
		"devolucion":
			t = ["Pues... la verdad es que está costando. %s ladra mucho cuando nos vamos y los vecinos se quejan.",
				"Bueno, regular. %s rompe cosas y no sabemos muy bien qué hacer con él.",
				"Estamos un poco agobiados. %s no para y nosotros no llegamos a todo."][rng.randi() % 3] % nm
		"cazador":
			t = "Sí, sí, %s está bien, en el campo con los otros. Oye, que te tengo que dejar, que estoy liado." % nm
		"guarda":
			t = "Está bien, está en la nave. ¿Para qué llamáis tanto? Ya os dije que estaba bien."
		"criador":
			t = "¡%s está genial! Oye, por cierto, ¿no tendréis alguna hembra más, de las bonitas?" % nm
		"regalo":
			t = "Uf... Bueno, mi novia no está muy convencida. Ya veremos. Ahora no puedo hablar."
		"acumulador":
			t = "¡Están todos estupendos, mis niños! %s se lleva muy bien con los demás. Bueno, con casi todos." % nm
	changed.emit()
	return {"text": "📞 %s: «%s»" % [f["who"], t], "status": status}


## Visita: lleva hora y media, pero se ve la realidad.
func followup_visit(fid: int) -> Dictionary:
	var f := _find_id(s["followups"], fid)
	if f.is_empty():
		return {}
	if s["minute"] > Catalog.DAY_END - FOLLOWUP_VISIT_MINUTES - 30:
		return {"text": "Es demasiado tarde para hacer una visita hoy. Mejor mañana.", "status": "tarde"}
	advance_minutes(FOLLOWUP_VISIT_MINUTES)
	var status := followup_status(f)
	f["visited"] = true
	var nm: String = f["name"]
	var t: String
	match status:
		"bien":
			t = "Visitas a %s en su nueva casa: tiene su cama, sus juguetes y una familia que lo adora. Da gusto verlo." % nm
			_rep(1)
			if rng.randf() < 0.3:
				s["stock"]["pienso"] += 15.0
				t += " Al despediros, la familia os da un saco de pienso para el refugio."
		"devolucion":
			t = "%s está nervioso y la familia, desbordada. Con unos buenos consejos y algo de paciencia, quizá funcione." % nm
		"cazador":
			t = "Encuentras a %s en un cercado embarrado con otros perros, muy delgado, con agua sucia y sin refugio. El contrato de adopción no permite tenerlo así." % nm
		"guarda":
			t = "%s está atado con una cadena corta en el patio de una nave, sin sombra y con el cuenco vacío. Te mira y mueve la cola." % nm
		"criador":
			t = "En la casa hay varias jaulas con perros y gatos y un cartel de «se venden cachorros». %s está en una de ellas." % nm
		"regalo":
			t = "%s pasa el día solo en una terraza. Nadie lo saca a pasear; la «sorpresa» no salió bien." % nm
		"acumulador":
			t = "El piso huele fatal: hay decenas de gatos, muchos enfermos. %s está escondido debajo de un mueble, asustado." % nm
	changed.emit()
	return {"text": "🏠 " + t, "status": status}


## Consejos a una familia con problemas: a menudo evitan la devolución.
func followup_advise(fid: int, in_person: bool) -> String:
	var f := _find_id(s["followups"], fid)
	if f.is_empty():
		return ""
	var r := _pending_return(f["animal_id"])
	if r.is_empty():
		return "«Gracias por los consejos, los tendremos en cuenta.»"
	if rng.randf() < (0.8 if in_person else 0.55):
		s["returns"].erase(r)
		f["closed"] = true
		_rep(1)
		changed.emit()
		return "«Vale, probaremos con rutinas fijas, más paseos y juguetes. ¡Gracias por no dejarnos solos!» (La adopción sigue adelante.)"
	changed.emit()
	return "«Lo intentaremos... pero no prometemos nada.»"


## Recuperar el animal: el contrato de adopción lo permite si no se cumplen las condiciones.
func followup_reclaim(fid: int, denounce: bool) -> String:
	var f := _find_id(s["followups"], fid)
	if f.is_empty():
		return ""
	var a: Dictionary = {}
	var c := _pending_consequence(f["animal_id"])
	if not c.is_empty():
		s["consequences"].erase(c)
		a = c["animal"]
	var r := _pending_return(f["animal_id"])
	if not r.is_empty():
		s["returns"].erase(r)
		a = r["animal"]
	if a.is_empty():
		return ""
	f["closed"] = true
	s["stats"]["reclaimed"] = s["stats"].get("reclaimed", 0) + 1
	a["location"] = "refugio"
	a["mood"] = maxi(0, a["mood"] - 20)
	if c.get("type", "") in ["cazador", "guarda", "acumulador"]:
		a["health"] = maxi(20, a["health"] - 25)
		a["nutrition"] = maxi(10, a["nutrition"] - 30)
	s["animals"].append(a)
	_rep(3)
	var msg := "Recuperas a %s gracias a la cláusula del contrato de adopción. Vuelve al refugio, a salvo." % a["name"]
	if denounce:
		s["stats"]["denuncias"] += 1
		if rng.randf() < 0.7:
			_rep(4)
			msg += " La denuncia en el SEPRONA prospera: multa y prohibición de tener animales."
		else:
			_rep(1)
			msg += " La denuncia queda archivada, pero el animal ya está a salvo."
	world_changed.emit()
	changed.emit()
	return msg


# =====================================================================
# Coordinador de adopciones
# =====================================================================

## Su opinión sobre una solicitud: acierta casi siempre, pero no siempre.
func coordinator_doubts(rq: Dictionary) -> bool:
	if staff_count("coordinador") == 0:
		return false
	var roll := absi(hash(str(rq["id"]) + "coord")) % 100
	return roll < 80 if rq.get("suspect", "") != "" else roll < 5


## Cada día hace el seguimiento de las adopciones de hace 3 días o más.
func _coordinator_day() -> PackedStringArray:
	var out: PackedStringArray = []
	var budget := staff_count("coordinador") * 3
	if budget == 0:
		return out
	for f in open_followups():
		if budget <= 0:
			break
		if f["called"] or s["day"] - f["day"] < 3:
			continue
		budget -= 1
		f["called"] = true
		var status := followup_status(f)
		match status:
			"bien":
				_rep(1)
			"devolucion":
				if rng.randf() < 0.6:
					s["returns"].erase(_pending_return(f["animal_id"]))
					f["closed"] = true
					_rep(1)
					out.append("📋 Tu coordinador/a ha ayudado a la familia de %s con unos consejos: se lo quedan." % f["name"])
				else:
					out.append("📋 Tu coordinador/a cree que la adopción de %s no va bien. Quizá lo devuelvan." % f["name"])
			_:
				# Sospecha: hace la visita y, si confirma el problema, recupera al animal.
				if rng.randf() < 0.75:
					var denounce: bool = status in ["cazador", "guarda", "acumulador"]
					followup_reclaim(f["id"], denounce)
					out.append("📋 En una visita de seguimiento, tu coordinador/a ha encontrado a %s en malas condiciones y lo ha recuperado%s." % [
						f["name"], " (con denuncia)" if denounce else ""])
	return out


## Lo que dice la familia al conocer al animal (antes de decidir).
func adopter_reaction(rq: Dictionary, a: Dictionary) -> String:
	var score := match_score(rq, a)
	var r := [
		["Mmm... es muy distinto a lo que buscábamos. Pero bueno, si nos decís que es buena idea...",
			"No sé yo... no es lo que teníamos pensado."],
		["Es muy bonito. No es exactamente lo que buscábamos, pero nos gusta.",
			"Nos ha caído bien. Igual hay que adaptarse un poco, pero vale."],
		["¡Es justo lo que buscábamos! Mira cómo nos mira...", "¡Nos encanta! Es perfecto para nosotros."],
	]
	var opts: Array = r[maxi(score, 0)]
	var line: String = opts[rng.randi() % opts.size()]
	var clue := {
		"cazador": " ¿Y cómo es de olfato? ¿Rastrea? Es lo que necesito.",
		"guarda": " ¿Ladra mucho? Mejor, así avisa si entra alguien en la nave.",
		"criador": " Oye, ¿no estará esterilizado, verdad?" if not a["sterilized"] else " Vaya... ¿está esterilizado? Eso no me lo habíais dicho.",
		"regalo": " ¡Le va a encantar a mi novia! Bueno, eso espero.",
		"acumulador": " Con los demás va a estar estupendamente. Tengo... unos cuantos.",
	}
	return line + clue.get(rq.get("suspect", ""), "")


## La familia se va sin animal (no hay ninguno adecuado). Sin penalización.
func send_visitor_home(request_id: int) -> String:
	var rq := _find_id(s["requests"], request_id)
	if rq.is_empty():
		return ""
	s["requests"].erase(rq)
	changed.emit()
	return "«Vale, gracias. Si llega alguno que encaje, nos llamáis.»"


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
	sound.emit("caja_registradora")
	if id.begins_with("pienso"):
		Tutorial.flag("pienso")
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
	sound.emit("caja_registradora")
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
	sound.emit("obra")
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
	sound.emit("jingle_nuevo_terreno")
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
	if id == "coordinador" and s["tier"] < 2:
		return "Necesitas al menos la parcela mediana (hay que tener sitio para una oficina)."
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
	# El pueblo no es infinito: cuantos más socios tienes, menos rinde cada campaña.
	var room := maxf(0.0, 1.0 - float(s["donors"].size()) / donor_cap())
	new_donors = int(round(new_donors * room))
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


## Socios posibles según la reputación y el tamaño del refugio.
func donor_cap() -> int:
	return 15 + int(s["reputation"] * 0.6) + int(s["tier"]) * 15


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
		s["stats"]["grants"] = s["stats"].get("grants", 0) + 1
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
			var n := rng.randi_range(2, 4)
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
	if amount >= 150:
		sound.emit("dinero_sale")
	s["stats"]["day_spent"] += amount
	_log("-%d € · %s" % [amount, what])


func _earn(amount: int, what: String) -> void:
	s["money"] += amount
	if amount > 0:
		sound.emit("dinero_entra")
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
	for k in ["visits", "consequences", "returns", "followups"]:
		if not s.has(k):
			s[k] = []  # partidas de versiones anteriores
	if not s["stock"].has("heno"):
		s["stock"]["heno"] = 0.0
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
