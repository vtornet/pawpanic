class_name Tutorial
extends RefCounted
## Tutorial de la primera partida: objetivos paso a paso, con un marcador en el mundo.
## El estado vive en Game.s["tutorial"] = {"active": bool, "step": int, "flags": {}}.

## target: dónde poner el marcador ("call" = el animal del aviso, "shelter" = puerta de la caseta,
## o una clave de World.PLACES). check: cuándo se da por hecho.
const STEPS := [
	{"id": "tablet", "text": "Abre la tablet con Tab y mira el aviso de recogida.",
		"hint": "En la tablet llevas toda la gestión: avisos, animales, adopciones, tienda, obras y personal.", "target": ""},
	{"id": "recoger", "text": "Ve hasta el aviso (columna de luz roja) y recoge al perro con E.",
		"hint": "A pie solo puedes llevar un animal. Más adelante podrás comprar una bici con carro o una furgoneta.", "target": "call"},
	{"id": "revision", "text": "Llévalo a la clínica veterinaria y pide una revisión en recepción.",
		"hint": "La revisión lee el chip (por si tiene dueño) y detecta enfermedades, heridas o maltrato.", "target": "clinica"},
	{"id": "preparar", "text": "Vacúnalo, ponle el chip y desparasítalo, también en la clínica.",
		"hint": "Sin vacunas, chip y desparasitación no se puede adoptar. Y sin chip, si se escapa, no lo encontrarás.", "target": "clinica"},
	{"id": "dejar", "text": "Vuelve al refugio y déjalo en la caseta (pasa por la puerta con él).",
		"hint": "Tienes 4 plazas. Si metes más animales de la cuenta, enferman, se escapan y baja la reputación.", "target": "shelter"},
	{"id": "pienso", "text": "Compra pienso: en la tienda del pueblo o desde la tablet (Tab → Tienda).",
		"hint": "Cada animal come a diario. Sin pienso pierden salud. Los productos de limpieza también se gastan.", "target": "tienda"},
	{"id": "comer", "text": "Dales de comer en el comedero de la caseta.",
		"hint": "Los voluntarios a veces lo hacen por ti, pero no siempre vienen.", "target": "shelter"},
	{"id": "adopcion", "text": "Una familia viene a conocer al perro. Habla con ella en la entrada del refugio.",
		"hint": "Escucha qué buscan y hazles preguntas: no todo el mundo es apto para adoptar.", "target": "visitors"},
	{"id": "dormir", "text": "Termina el día: ve a la mesa de la caseta y elige «Dormir».",
		"hint": "Al cerrar el día se gastan pienso y limpieza, y a fin de mes se cobran la cuota del préstamo y los gastos fijos.", "target": "shelter"},
]


static func state() -> Dictionary:
	if not Game.s.has("tutorial"):
		Game.s["tutorial"] = {"active": false, "step": 0, "flags": {}}
	return Game.s["tutorial"]


static func active() -> bool:
	return state().get("active", false) and state()["step"] < STEPS.size()


static func current() -> Dictionary:
	return STEPS[state()["step"]] if active() else {}


static func flag(name: String) -> void:
	if active():
		state()["flags"][name] = true
		check()


static func skip() -> void:
	state()["active"] = false
	Game.changed.emit()


## Comprueba si el paso actual está hecho y avanza.
static func check() -> void:
	if not active():
		return
	var advanced := false
	while active() and _done(current()["id"]):
		state()["step"] += 1
		advanced = true
		_on_enter(current().get("id", ""))
	if advanced:
		if not active():
			Game._earn(300, "Ayuda municipal de bienvenida")
			Game.notify.emit("¡Tutorial completado! El ayuntamiento te da 300 € de ayuda de bienvenida. A partir de aquí, el refugio es tuyo.", "bien")
		else:
			Game.notify.emit("Objetivo: " + current()["text"], "aviso")
		Game.changed.emit()


static func _done(id: String) -> bool:
	var f: Dictionary = state()["flags"]
	var animals: Array = Game.s["animals"]
	match id:
		"tablet":
			return f.has("tablet")
		"recoger":
			return Game.s["stats"]["rescued"] >= 1
		"revision":
			return animals.any(func(a: Dictionary) -> bool: return a["reviewed"])
		"preparar":
			return animals.any(func(a: Dictionary) -> bool: return a["vaccinated"] and a["dewormed"] and a["chip"] == "nuestro")
		"dejar":
			return not Game.sheltered().is_empty()
		"pienso":
			return f.has("pienso")
		"comer":
			return Game.s["fed_today"] or f.has("comer")
		"adopcion":
			return Game.s["stats"]["adopted"] >= 1
		"dormir":
			return f.has("dormir")
	return false


## Al llegar a un paso, se prepara lo que necesita.
static func _on_enter(id: String) -> void:
	if id == "adopcion":
		# Una familia apta que encaja con el primer animal listo, en media hora.
		var ready := Game.sheltered().filter(Game.is_adoptable)
		if ready.is_empty():
			ready = Game.sheltered()
		if ready.is_empty():
			return
		var a: Dictionary = ready[0]
		Game.s["requests"].append({"id": Game.s["next_id"], "who": "Familia García", "species": a["species"], "size": a["size"],
			"energy": "tranquilo" if a["energy"] in ["tranquilo", "miedoso", "sociable"] else "enérgico",
			"home": "casa con jardín", "state": "pendiente", "visit_at": Game.now_abs() + 30, "look": 3, "suspect": ""})
		Game.s["next_id"] += 1
