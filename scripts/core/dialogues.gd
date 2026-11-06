class_name Dialogues
extends RefCounted
## Qué dice cada personaje según el estado de la partida.
## Devuelve {"text": String, "options": [[texto, panel]]}; panel "" = cerrar.

const PEOPLE := {
	"recepcion": {"name": "Rocío", "role": "recepcionista"},
	"veterinaria": {"name": "Dra. Carmen", "role": "veterinaria"},
	"peluquera": {"name": "Inma", "role": "peluquera"},
	"dependiente": {"name": "Manolo", "role": "dependiente"},
	"banco": {"name": "Antonio", "role": "empleado del banco"},
	"registro": {"name": "Pilar", "role": "funcionaria"},
	"seprona": {"name": "Agente Ruiz", "role": "SEPRONA"},
}

const STAFF_NAMES := ["Lucía", "Javi", "Marisa", "Paco", "Sara", "Rafa", "Elena", "Curro", "Alba", "Juanma"]


static func talk(id: String) -> Dictionary:
	match id:
		"recepcion": return _recepcion()
		"veterinaria": return _veterinaria()
		"peluquera": return _peluquera()
		"dependiente": return _dependiente()
		"banco": return _banco()
		"registro": return _registro()
		"seprona": return _seprona()
	if id.begins_with("staff_"):
		return _staff(id)
	if id.begins_with("adoptante_"):
		return _adopter(int(id.get_slice("_", 1)))
	return {"text": "...", "options": []}


static func _pick(list: Array) -> String:
	return list[randi() % list.size()]


static func _names(list: Array) -> String:
	var n := PackedStringArray(list.map(func(a: Dictionary) -> String: return a["name"]))
	if n.size() <= 1:
		return "".join(n)
	return ", ".join(n.slice(0, n.size() - 1)) + " y " + n[n.size() - 1]


# ---------------------------------------------------------------------

static func _recepcion() -> Dictionary:
	var car := Game.carried()
	var text: String
	if car.is_empty():
		text = _pick([
			"Buenos días. Para cualquier servicio necesito que traigas al animal, ¿eh? Sin animal no puedo apuntarte nada.",
			"¡Hola! Hoy la doctora tiene la agenda bastante libre. Cuando traigas a alguno, te lo pasamos enseguida.",
			"La revisión, que incluye leer el chip, son %d €. Las vacunas, %d €. Si me traes a alguno, te hago la ficha." % [Catalog.SERVICES["revision"]["ext"], Catalog.SERVICES["vacunas"]["ext"]],
		])
	else:
		var unrev := car.filter(func(a: Dictionary) -> bool: return not a["reviewed"])
		text = "¿Traes a %s? " % _names(car)
		if not unrev.is_empty():
			text += "Primero la revisión, que así leemos el chip y la doctora mira cómo están."
		else:
			text += "Ya tienen la revisión hecha. Dime qué más necesitan."
	return {"text": text, "options": [["Ver servicios y precios", "clinica"], ["Adiós", ""]]}


static func _veterinaria() -> Dictionary:
	var car := Game.carried()
	var text := ""
	var abuse: Array = Game.s["animals"].filter(func(a: Dictionary) -> bool: return a["abuse_known"] and a.get("owner_case", "") == "decidir")
	if not abuse.is_empty():
		text = "Lo de %s no me gustó nada. Tiene chip, así que el dueño está identificado: si lo denuncias en el SEPRONA, yo firmo el informe. " % abuse[0]["name"]
	if car.is_empty():
		text += _pick([
			"Si no lleva chip y se te escapa, no hay manera de encontrarlo. Chip a todos, que es barato comparado con perderlos.",
			"Con una zona de cuarentena en el refugio te ahorrarías muchos sustos cuando hay brotes de parvovirus por la comarca.",
			"El día que montes tu propia consulta y contrates veterinario, las vacunas y los chips te costarán casi solo el material.",
			"Un animal desparasitado y vacunado se adopta antes y vuelve menos. Merece la pena.",
			"Esterilizar no es obligatorio para adoptar, pero las familias lo valoran y a ti te da buena fama.",
		])
	else:
		var a: Dictionary = car[0]
		if a["injured"] or a["sick"]:
			text += "Déjame ver a %s... Esto hay que tratarlo cuanto antes, no lo dejes pasar." % a["name"]
		elif not a["reviewed"]:
			text += "Vamos a revisar a %s: leo el chip y le hago un chequeo completo." % a["name"]
		elif not a["vaccinated"]:
			text += "%s está revisado. Le falta vacunarse, y si no tiene chip, se lo ponemos ahora." % a["name"]
		elif a["chip"] == "no":
			text += "%s necesita su chip. Sin chip no se puede adoptar." % a["name"]
		else:
			text += "%s está estupendo. ¡Ojalá encuentre familia pronto!" % a["name"]
	return {"text": text, "options": [["Ver servicios", "clinica"], ["Adiós", ""]]}


static func _peluquera() -> Dictionary:
	var car := Game.carried()
	var dirty := car.filter(func(a: Dictionary) -> bool: return a["hygiene"] < 60)
	var text: String
	if not dirty.is_empty():
		text = _pick(["¡Madre mía cómo viene %s! Un buen baño y como nuevo.", "Ay, %s necesita un baño urgente. Ven, ven."]) % dirty[0]["name"]
	elif not car.is_empty():
		text = "%s ya viene bastante limpio, pero si quieres le doy un repaso y lo desparasito." % car[0]["name"]
	else:
		text = _pick([
			"Tráemelos cuando vengan sucios: un animal limpio y guapo se adopta mucho antes.",
			"Si algún día te montas tu propia zona de limpieza, me llamas y te echo una mano.",
		])
	return {"text": text, "options": [["Ver servicios", "peluqueria"], ["Adiós", ""]]}


static func _dependiente() -> Dictionary:
	var st: Dictionary = Game.s["stock"]
	var kg: float = st["pienso"] + st["pienso_premium"]
	var need := 0.0
	for a in Game.sheltered():
		need += Catalog.FEED_PER_DAY[a["size"]]
	var text: String
	if need <= 0.0:
		text = "¡Buenas! Cuando tengas animales, aquí tienes pienso para todos los gustos. Y los productos de limpieza, que no se te olviden."
	else:
		var days := int(kg / need)
		text = "Con %d animales gastas unos %.1f kg de pienso al día. Te quedan %.0f kg, para unos %d días. " % [Game.occupancy(), need, kg, days]
		if days < 4:
			text += "Yo que tú me llevaba un par de sacos ya."
		elif st["limpieza"] < 3:
			text += "Y te veo corto de productos de limpieza."
		else:
			text += "Vas bien servido de momento."
	if Game.has_building("almacen"):
		text += " Como tienes almacén, te hago un 10 %."
	return {"text": text, "options": [["Comprar", "tienda"], ["Adiós", ""]]}


static func _banco() -> Dictionary:
	var loan: Dictionary = Game.s["loan"]
	var text: String
	if loan.get("months_left", 0) <= 0:
		text = "Su préstamo está pagado por completo. ¡Enhorabuena! No es lo habitual, se lo aseguro."
	elif loan["missed"] > 0:
		text = "Tenemos %d cuota(s) sin cobrar. Le recuerdo que al tercer impago el banco ejecuta la garantía sobre el terreno. La cuota es de %d €." % [loan["missed"], loan["monthly"]]
	else:
		var next: int = 30 - ((Game.s["day"] - 1) % 30)
		text = "Todo en orden. Le cobraremos %d € dentro de %d días; le quedan %d cuotas. Procure tener saldo." % [loan["monthly"], next, loan["months_left"]]
	return {"text": text, "options": [["Ver detalles", "ayuntamiento"], ["Adiós", ""]]}


static func _registro() -> Dictionary:
	var fails: PackedStringArray = []
	for req in Game.grant_check():
		if not req[1]:
			fails.append(req[0].to_lower())
	var text: String
	if fails.is_empty():
		text = "Cumple usted todos los requisitos de la subvención de bienestar animal. Si la solicita, mandamos a un inspector a ver las instalaciones."
	else:
		text = "Para la subvención de bienestar animal le falta: %s. Cuando lo tenga, vuelva y la tramitamos." % ", ".join(fails)
	return {"text": text, "options": [["Subvenciones e inspecciones", "ayuntamiento"], ["Adiós", ""]]}


static func _seprona() -> Dictionary:
	var decide: Array = Game.s["animals"].filter(func(a: Dictionary) -> bool: return a.get("owner_case", "") == "decidir")
	var ongoing: Array = Game.s["animals"].filter(func(a: Dictionary) -> bool: return a.get("owner_case", "") == "denuncia")
	var text: String
	if not decide.is_empty():
		text = "Me consta que %s llegó con indicios de maltrato y tiene chip. Con el informe veterinario podemos abrir diligencias contra el propietario." % decide[0]["name"]
	elif not ongoing.is_empty():
		text = "La denuncia por %s sigue su curso. En unos días le diremos algo." % ongoing[0]["name"]
	else:
		text = "Si encuentra un animal con indicios de maltrato y tiene chip, venga con el informe del veterinario y lo tramitamos. El abandono también es delito."
	return {"text": text, "options": [["Denuncias", "ayuntamiento"], ["Adiós", ""]]}


## Familia que visita el refugio. Las opciones con Callable ejecutan una acción
## y su resultado se muestra como respuesta.
static func _adopter(request_id: int) -> Dictionary:
	var rq := Game._find_id(Game.s["requests"], request_id)
	if rq.is_empty():
		return {"text": "...", "options": []}
	var intro := {
		"Familia García": "Hola, somos los García. Llevamos tiempo pensando en adoptar",
		"Pareja joven": "¡Hola! Nos acabamos de ir a vivir juntos y queremos adoptar",
		"Señora jubilada": "Buenas tardes, hijo. Desde que me quedé sola, la casa se me hace muy grande. Quiero adoptar",
		"Familia con niños": "¡Hola! Los niños llevan meses pidiéndonos adoptar",
		"Estudiante": "Hola. Estoy estudiando a distancia y paso mucho tiempo en casa. Quiero adoptar",
		"Pareja de jubilados": "Buenos días. Ahora que estamos jubilados tenemos todo el tiempo del mundo. Queremos adoptar",
		"Familia López": "Hola, somos los López. Queremos adoptar",
		"Chico que vive solo": "Hola, ¿qué tal? Vivo solo y me gustaría adoptar",
	}
	var energy_txt: String = "tranquilo, que no dé mucha guerra" if rq["energy"] == "tranquilo" else "con energía, para salir a correr y al campo"
	var home: String = rq["home"]
	var article := "una" if home.begins_with("casa") else "un"
	var text: String
	var suspect: String = rq.get("suspect", "")
	if suspect != "":
		text = SUSPECT_INTRO[suspect] % [rq["species"], rq["size"]]
	else:
		text = "%s un %s %s. Vivimos en %s %s y nos gustaría que fuera %s." % [
			intro.get(rq["who"], "Hola, queremos adoptar"), rq["species"], rq["size"], article, home, energy_txt]
	var options: Array = []
	var ready := Game.sheltered().filter(func(a: Dictionary) -> bool: return a["species"] == rq["species"] and Game.is_adoptable(a))
	var not_ready := Game.sheltered().filter(func(a: Dictionary) -> bool: return a["species"] == rq["species"] and not Game.is_adoptable(a))
	if ready.is_empty():
		text += "\n\n(No tienes ningún %s listo para adopción." % rq["species"]
		if not not_ready.is_empty():
			text += " %s aún no tiene: %s." % [not_ready[0]["name"], ", ".join(Game.missing_for_adoption(not_ready[0]))]
		text += ")"
	for a in ready.slice(0, 5):
		options.append(["Presentarle a %s (%s %s, %s, %d años)" % [a["name"], a["species"], a["size"], a["energy"], a["age"]],
			func() -> Dictionary: return _meet(request_id, a["id"])])
	if not rq.get("asked", false):
		options.append(["Hacerles unas preguntas (dónde vivirá, tiempo, experiencia)", func() -> Dictionary:
			rq["asked"] = true
			var next := _adopter(request_id)
			next["text"] = _answers(rq)
			return next])
	options.append(["No os vamos a dar ningún animal: no lo vemos claro", func() -> Dictionary:
		return {"text": Game.refuse_adopter(request_id), "options": [["Adiós", ""]]}])
	options.append(["Ahora mismo no tenemos ninguno para vosotros", func() -> Dictionary:
		return {"text": Game.send_visitor_home(request_id), "options": [["Adiós", ""]]}])
	options.append(["Un momento, ahora vuelvo", ""])
	return {"text": text, "options": options, "who": rq["who"]}


## Presentaciones de los perfiles no aptos: suenan normales, pero dejan caer alguna pista.
const SUSPECT_INTRO := {
	"cazador": "Buenas. Vengo a por un %s %s, que tenga nervio. Es para el campo; tengo más en la finca y me hace falta uno más para la temporada.",
	"guarda": "Hola. Busco un %s %s, de los que impongan. Tengo una nave en el polígono y me han entrado a robar dos veces.",
	"criador": "Hola, buscamos un %s %s, bonito, que parezca de raza. Ya tenemos alguno más en casa y nos encantan.",
	"regalo": "¡Hola! Quiero un %s %s, el más bonito que tengáis. Es una sorpresa y lo quiero hoy mismo, que es su cumpleaños.",
	"acumulador": "Hola, cariño. Vengo a por un %s %s. Es que no puedo ver a ninguno sin casa, se me parte el alma. Me los llevaría todos.",
}


## Respuestas a las preguntas de la entrevista.
static func _answers(rq: Dictionary) -> String:
	var suspect: String = rq.get("suspect", "")
	var a := {
		"cazador": "—¿Dónde va a vivir? «En la finca, en el cercado con los otros. Allí vive mejor que en un piso.»\n—¿Cuánto tiempo estará solo? «Solo no, que hay más perros. Yo subo a echarles de comer cada dos o tres días.»\n—¿Habéis tenido perros? «Toda la vida, de caza. Los que salen buenos se quedan; los que no...» (se encoge de hombros)",
		"guarda": "—¿Dónde va a vivir? «En la nave. De noche suelto, bueno, con una cadena larga, que no se vaya.»\n—¿Cuánto tiempo estará solo? «Por las noches y los fines de semana, para eso lo quiero.»\n—¿Habéis tenido perros? «Tuve otro, pero se me escapó, o se lo llevaron, no sé.»",
		"criador": "—¿Dónde va a vivir? «En casa, con nuestras hembras. ¿Tiene papeles? Es que parece de raza.»\n—¿Está de acuerdo con esterilizarlo? «Hombre... preferimos que no, que es una pena.»\n—¿Habéis tenido animales? «Sí, varios. Hemos tenido alguna camada, todos colocados.»",
		"regalo": "—¿Quién lo va a cuidar? «Mi novia. Bueno, no sabe nada todavía, es una sorpresa.»\n—¿Cuánto tiempo estará solo? «Ella trabaja todo el día, pero ya se apañará.»\n—¿Habéis tenido animales? «No, ninguno de los dos. Pero tiene que ser bonito, para la foto.»",
		"acumulador": "—¿Dónde va a vivir? «Con los demás, en casa. Tengo... unos cuantos. Ya no los cuento.»\n—¿Los tiene vacunados y esterilizados? «Ay, eso es mucho dinero para tantos. Están sanos, sanos.»\n—¿Algún vecino se ha quejado? «Los vecinos son unos exagerados, por un poco de olor.»",
	}
	if suspect != "":
		return a[suspect]
	var home: String = rq["home"]
	var legit := [
		"—¿Dónde va a vivir? «Dentro de casa, claro. Ya le hemos mirado una cama.»",
		"—¿Dónde va a vivir? «En casa con nosotros. Tenemos %s, así que espacio hay.»" % home,
	]
	var time := ["—¿Cuánto tiempo estará solo? «Trabajamos por turnos, así que casi siempre hay alguien.»",
		"—¿Cuánto tiempo estará solo? «Unas horas por la mañana. Al mediodía vengo a sacarlo.»",
		"—¿Cuánto tiempo estará solo? «Muy poco, trabajo desde casa.»"]
	var exp := ["—¿Habéis tenido animales? «Tuvimos una perra catorce años. Todavía la echamos de menos.»",
		"—¿Habéis tenido animales? «Es el primero, pero nos hemos informado mucho y tenemos veterinario cerca.»",
		"—¿Habéis tenido animales? «De pequeña siempre tuve gatos en casa de mis padres.»"]
	return "%s\n%s\n%s\n¿Os parece bien que esté esterilizado? «Sí, claro, mejor.»" % [_pick(legit), _pick(time), _pick(exp)]


## La familia conoce al animal y reacciona; el jugador decide si sigue adelante.
static func _meet(request_id: int, animal_id: int) -> Dictionary:
	var rq := Game._find_id(Game.s["requests"], request_id)
	var a := Game.animal(animal_id)
	if rq.is_empty() or a.is_empty():
		return {"text": "...", "options": [["Adiós", ""]]}
	return {"text": Game.adopter_reaction(rq, a), "who": rq["who"], "options": [
		["Firmar la adopción de %s (%d € de tasa)" % [a["name"], Catalog.ADOPTION_FEE], func() -> Dictionary:
			return {"text": Game.adopt(request_id, animal_id), "options": [["¡Hasta pronto!", ""]]}],
		["Mejor os enseño otro", func() -> Dictionary: return _adopter(request_id)],
	]}


static func _staff(id: String) -> Dictionary:
	# id = "staff_<rol>_<n>"
	var parts := id.split("_")
	var role := parts[1]
	var lines: Array = []
	var st: Dictionary = Game.s["stock"]
	var sick := Game.sheltered().filter(func(a: Dictionary) -> bool: return a["sick"] or a["injured"])
	if st["pienso"] + st["pienso_premium"] < 5.0 and Game.occupancy() > 0:
		lines.append("Oye, que el pienso se está acabando. Mañana no vamos a tener para todos.")
	if st["limpieza"] < 2.0 and Game.occupancy() > 0:
		lines.append("Nos quedamos sin productos de limpieza. Con agua sola no se limpia esto bien.")
	if not sick.is_empty():
		lines.append("%s no está bien. Habría que llevarlo a la clínica." % sick[0]["name"])
	if Game.occupancy() > Game.slots():
		lines.append("No cabemos. Hay más animales que plazas y se ponen nerviosos.")
	var ready := Game.sheltered().filter(Game.is_adoptable)
	if not ready.is_empty():
		lines.append("%s ya está listo para adoptar. ¡A ver si viene una familia buena!" % ready[0]["name"])
	if lines.is_empty():
		match role:
			"voluntario":
				lines = ["Me encanta venir los fines de semana. Bueno, y entre semana cuando puedo.",
					"Si haces alguna campaña en redes, yo la comparto con todo el pueblo.",
					"A los miedosos hay que darles tiempo. Ya verás cómo se sueltan."]
			"cuidador":
				lines = ["Comida y agua puestas. Todo en orden por aquí.", "Hoy están todos bastante tranquilos."]
			"limpiador":
				lines = ["Los caniles están como los chorros del oro.", "Con la higiene al día enferman mucho menos."]
			"paseador":
				lines = ["Un buen paseo y duermen como angelitos.", "Los enérgicos necesitan correr, si no, se quieren escapar."]
			"peluquero":
				lines = ["Limpios y guapos se adoptan antes, ya lo verás."]
			"veterinario":
				lines = ["He revisado a todos. Si alguno se pone malo, aquí estoy.", "Con la consulta propia nos ahorramos un dineral."]
			_:
				lines = ["Todo bien por aquí."]
	return {"text": _pick(lines), "options": [["Adiós", ""]]}
