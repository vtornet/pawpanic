class_name Achievements
extends RefCounted
## Logros. Los identificadores están pensados para usarse tal cual como logros de Steam.
## Se guardan en Game.s["achievements"] = {id: día en que se consiguió}.

const LIST := [
	{"id": "PRIMER_RESCATE", "name": "Primer rescate", "desc": "Recoge a tu primer animal."},
	{"id": "PRIMERA_ADOPCION", "name": "Un hogar para siempre", "desc": "Consigue tu primera adopción."},
	{"id": "ADOPCIONES_10", "name": "Casamentero", "desc": "10 adopciones."},
	{"id": "ADOPCIONES_50", "name": "Media comarca adopta", "desc": "50 adopciones."},
	{"id": "ADOPCIONES_100", "name": "Cien vidas cambiadas", "desc": "100 adopciones."},
	{"id": "FAUNA_5", "name": "Amigo de la fauna", "desc": "Entrega 5 animales salvajes al centro de recuperación."},
	{"id": "DENUNCIA", "name": "Justicia animal", "desc": "Presenta tu primera denuncia por maltrato."},
	{"id": "OLFATO_FINO", "name": "Olfato fino", "desc": "Rechaza a 5 solicitantes que no eran aptos."},
	{"id": "SEGUNDA_OPORTUNIDAD", "name": "Segunda oportunidad", "desc": "Recupera a un animal en una visita de seguimiento."},
	{"id": "SOCIOS_50", "name": "El pueblo te apoya", "desc": "Llega a 50 socios."},
	{"id": "SIN_DEUDAS", "name": "Libres de deudas", "desc": "Termina de pagar el préstamo."},
	{"id": "CONVENIO", "name": "Precio de amigo", "desc": "Firma el convenio con la clínica veterinaria."},
	{"id": "SUBVENCION", "name": "Papeles en regla", "desc": "Consigue la subvención municipal."},
	{"id": "CONSULTA_PROPIA", "name": "Veterinario en casa", "desc": "Ten consulta propia con veterinario contratado."},
	{"id": "GRAN_REFUGIO", "name": "Gran refugio", "desc": "Compra la finca."},
	{"id": "GRANJA", "name": "Granja de rescate", "desc": "Acoge a un burro, un caballo o una cabra."},
	{"id": "GRAN_FURGONETA", "name": "Flota de rescate", "desc": "Compra la gran furgoneta adaptada."},
	{"id": "REFERENTE", "name": "Referente", "desc": "Alcanza 100 de reputación."},
	{"id": "NI_UNO_MENOS", "name": "Ni uno menos", "desc": "Pasa 90 días sin perder ningún animal."},
]


static func unlocked() -> Dictionary:
	if not Game.s.has("achievements"):
		Game.s["achievements"] = {}
	return Game.s["achievements"]


static func _met(id: String) -> bool:
	var s: Dictionary = Game.s
	var st: Dictionary = s["stats"]
	match id:
		"PRIMER_RESCATE": return st["rescued"] >= 1
		"PRIMERA_ADOPCION": return st["adopted"] >= 1
		"ADOPCIONES_10": return st["adopted"] >= 10
		"ADOPCIONES_50": return st["adopted"] >= 50
		"ADOPCIONES_100": return st["adopted"] >= 100
		"FAUNA_5": return st.get("wild", 0) >= 5
		"DENUNCIA": return st["denuncias"] >= 1
		"OLFATO_FINO": return st.get("refused_ok", 0) >= 5
		"SEGUNDA_OPORTUNIDAD": return st.get("reclaimed", 0) >= 1
		"SOCIOS_50": return s["donors"].size() >= 50
		"SIN_DEUDAS": return not s["loan"].is_empty() and s["loan"].get("months_left", 1) == 0
		"CONVENIO": return s.get("vet_agreement", false)
		"SUBVENCION": return st.get("grants", 0) >= 1
		"CONSULTA_PROPIA": return Game.has_building("consulta") and Game.staff_count("veterinario") > 0
		"GRAN_REFUGIO": return s["tier"] >= 4
		"GRANJA": return Game.sheltered().any(Game.is_large)
		"GRAN_FURGONETA": return "furgon" in s["vehicles"]
		"REFERENTE": return s["reputation"] >= 100
		"NI_UNO_MENOS": return s["step"] == "jugando" and s["day"] - st.get("last_lost_day", 0) >= 90 and st["rescued"] >= 10
	return false


## Comprueba los logros pendientes y avisa de los nuevos.
static func check() -> void:
	if Game.s.get("step", "") != "jugando":
		return
	var done := unlocked()
	for a in LIST:
		if not done.has(a["id"]) and _met(a["id"]):
			done[a["id"]] = Game.s["day"]
			Game.notify.emit("🏆 Logro: %s — %s" % [a["name"], a["desc"]], "bien")
