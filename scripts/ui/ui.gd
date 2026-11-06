class_name GameUI
extends CanvasLayer
## Toda la interfaz: arranque, HUD, tablet de gestión, paneles de lugares,
## resumen del día y menú de pausa.

var world: World

var _root: Control
var _hud_left: Label
var _hud_right: Label
var _prompt: Label
var _crosshair: Label
var _toasts: VBoxContainer
var _objective: Label
var _objective_hint: Label

var _modal: PanelContainer      # paneles grandes (tablet, lugares, arranque)
var _modal_body: VBoxContainer
var _modal_title: Label
var _close_btn: Button
var _open := ""                 # "" | "tablet" | "refugio" | "clinica" | ... | "intro" | "resumen" | "pausa" | "fin"
var _tab := 0
var _scroll: ScrollContainer
var _summary_text := ""
var _game_over_text := ""
var _rebuild_queued := false
var _dialog_id := ""
var _dialog: Dictionary = {}


func _ready() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_root.theme = _make_theme()

	_hud_left = _label(20)
	_hud_left.position = Vector2(20, 14)
	_root.add_child(_hud_left)
	_hud_right = _label(18)
	_hud_right.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_hud_right.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_hud_right.position = Vector2(-520, 14)
	_hud_right.size = Vector2(500, 0)
	_root.add_child(_hud_right)
	_crosshair = _label(22)
	_crosshair.text = "·"
	_crosshair.set_anchors_preset(Control.PRESET_CENTER)
	_crosshair.position = Vector2(-4, -16)
	_root.add_child(_crosshair)
	_prompt = _label(24)
	_prompt.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.size = Vector2(1000, 40)
	_prompt.position = Vector2(-500, -140)
	_root.add_child(_prompt)
	var help := _label(15)
	help.text = "WASD mover · Ratón mirar · Shift correr · E interactuar · Tab tablet · V cámara · Esc menú"
	help.modulate.a = 0.7
	help.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	help.position = Vector2(20, -34)
	_root.add_child(help)

	# Objetivo del tutorial, arriba en el centro.
	_objective = _label(22)
	_objective.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_objective.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_objective.autowrap_mode = TextServer.AUTOWRAP_WORD
	_objective.size = Vector2(760, 0)
	_objective.position = Vector2(-380, 14)
	_objective.modulate = Color(1, 0.88, 0.45)
	_root.add_child(_objective)
	_objective_hint = _label(16)
	_objective_hint.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_objective_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_objective_hint.autowrap_mode = TextServer.AUTOWRAP_WORD
	_objective_hint.size = Vector2(760, 0)
	_objective_hint.position = Vector2(-380, 76)
	_objective_hint.modulate = Color(1, 1, 1, 0.8)
	_root.add_child(_objective_hint)

	_toasts = VBoxContainer.new()
	_toasts.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_toasts.position = Vector2(-560, -330)
	_toasts.size = Vector2(540, 300)
	_toasts.alignment = BoxContainer.ALIGNMENT_END
	_toasts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_toasts)

	_modal = PanelContainer.new()
	_modal.set_anchors_preset(Control.PRESET_FULL_RECT)
	_modal.offset_left = 140
	_modal.offset_right = -140
	_modal.offset_top = 60
	_modal.offset_bottom = -60
	_root.add_child(_modal)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 22)
	_modal.add_child(margin)
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 12)
	margin.add_child(outer)
	var title_row := HBoxContainer.new()
	outer.add_child(title_row)
	_modal_title = _label(28)
	_modal_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(_modal_title)
	var close := Button.new()
	close.text = "Cerrar (Esc)"
	close.pressed.connect(close_panel)
	_close_btn = close
	title_row.add_child(close)
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer.add_child(_scroll)
	_modal_body = VBoxContainer.new()
	_modal_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_modal_body.add_theme_constant_override("separation", 8)
	_scroll.add_child(_modal_body)
	_modal.visible = false

	Game.changed.connect(_on_changed)
	Game.notify.connect(func(t: String, k: String) -> void: toast(t, k))
	Game.day_ended.connect(_on_day_ended)
	Game.game_over.connect(_on_game_over)
	world.open_panel.connect(open_panel)
	world.talk.connect(open_dialog)
	world.prompt_changed.connect(func(t: String) -> void: _prompt.text = t)
	world.message.connect(_act)

	if Game.s["step"] != "jugando":
		open_panel("intro")
	_update_hud()


# =====================================================================
# Abrir y cerrar
# =====================================================================

func open_panel(kind: String) -> void:
	_open = kind
	_modal.visible = true
	# El diálogo ocupa solo la parte de abajo, para seguir viendo al personaje.
	var dialog := kind == "dialogo"
	_modal.offset_left = 260 if dialog else 140
	_modal.offset_right = -260 if dialog else -140
	_modal.offset_top = 380 if dialog else 60
	_modal.offset_bottom = -50 if dialog else -60
	_close_btn.visible = kind in ["consulta", "limpieza", "dialogo", "tablet", "refugio", "clinica", "peluqueria", "tienda", "ayuntamiento", "pausa"]
	Game.paused = true
	world.player.ui_open = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if kind == "tablet":
		Tutorial.flag("tablet")
	_rebuild()
	_scroll.scroll_vertical = 0


func close_panel() -> void:
	if _open in ["intro", "fin"]:
		return
	_open = ""
	_modal.visible = false
	Game.paused = false
	world.player.ui_open = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("tablet"):
		if _open == "tablet":
			close_panel()
		elif _open == "":
			open_panel("tablet")
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("menu"):
		if _open == "":
			open_panel("pausa")
		elif _open == "resumen":
			_close_summary()
		else:
			close_panel()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed and _open == "" and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _on_changed() -> void:
	Tutorial.check()
	_update_hud()
	if _open != "" and not _rebuild_queued:
		_rebuild_queued = true
		_rebuild_keep_scroll.call_deferred()


func _rebuild_keep_scroll() -> void:
	_rebuild_queued = false
	if _open == "":
		return
	var sv := _scroll.scroll_vertical
	_rebuild()
	await get_tree().process_frame
	_scroll.scroll_vertical = sv


func _rebuild() -> void:
	for c in _modal_body.get_children():
		_modal_body.remove_child(c)
		c.queue_free()
	match _open:
		"intro": _build_intro()
		"tablet": _build_tablet()
		"refugio": _build_refugio()
		"consulta": _build_own_services("Consulta propia", ["revision", "vacunas", "chip", "desparasitar", "tratamiento", "esterilizar"],
			"Necesitas contratar a un veterinario (Tablet → Personal) para usar la consulta.")
		"limpieza": _build_own_services("Zona de limpieza", ["bano", "desparasitar"],
			"Necesitas un peluquero o algún voluntario para usar la zona de limpieza.")
		"clinica": _build_clinica()
		"peluqueria": _build_peluqueria()
		"tienda": _build_tienda_lugar()
		"ayuntamiento": _build_ayuntamiento()
		"resumen": _build_summary()
		"dialogo": _build_dialog()
		"pausa": _build_pause()
		"fin": _build_game_over()


# =====================================================================
# HUD
# =====================================================================

func _update_hud() -> void:
	var s := Game.s
	if s["step"] != "jugando" and s["step"] != "fin":
		_hud_left.text = ""
		_hud_right.text = ""
		return
	_hud_left.text = "%s\n%s  ·  %s\nDinero: %d €   ·   Reputación: %d\nRefugio: %d / %d plazas" % [
		s["name"], Game.date_text(), Game.time_text(), Game.money(), s["reputation"], Game.occupancy(), Game.slots()]
	var car := Game.carried()
	var names := PackedStringArray(car.map(func(a: Dictionary) -> String: return a["name"]))
	_hud_right.text = "%s · llevas %d / %d%s\nAvisos: %d   ·   Escapados: %d%s" % [
		Game.vehicle()["name"], car.size(), Game.capacity(),
		("\n" + ", ".join(names)) if not names.is_empty() else "",
		s["calls"].size(), Game.animals_at("escapado").size(),
		"\n‼ Visitas esperando en el refugio: %d" % (Game.visitors().size() + Game.person_visits().size()) if not (Game.visitors().is_empty() and Game.person_visits().is_empty()) else ""]
	_crosshair.visible = _open == ""
	if Tutorial.active() and s["step"] == "jugando":
		var st := Tutorial.state()
		_objective.text = "Tutorial %d/%d · %s" % [st["step"] + 1, Tutorial.STEPS.size(), Tutorial.current()["text"]]
		_objective_hint.text = Tutorial.current()["hint"] + "   (Esc → Saltar tutorial)"
	else:
		_objective.text = ""
		_objective_hint.text = ""


func toast(text: String, kind: String = "info") -> void:
	var l := _label(17)
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD
	l.custom_minimum_size.x = 540
	l.modulate = {"mal": Color(1, 0.6, 0.55), "aviso": Color(1, 0.85, 0.4), "bien": Color(0.6, 1, 0.65)}.get(kind, Color.WHITE)
	_toasts.add_child(l)
	while _toasts.get_child_count() > 6:
		_toasts.get_child(0).queue_free()
		_toasts.remove_child(_toasts.get_child(0))
	var tw := create_tween()
	tw.tween_interval(6.0)
	tw.tween_property(l, "modulate:a", 0.0, 1.0)
	tw.tween_callback(l.queue_free)


func _act(result: String) -> void:
	if result != "":
		toast(result, "info")


# =====================================================================
# Arranque
# =====================================================================

func _build_intro() -> void:
	var s := Game.s
	match s["step"]:
		"registro":
			_modal_title.text = "Paw Panic · Registra tu protectora"
			_p("Tienes %d € de ahorros y muchas ganas de ayudar. Lo primero es registrar la protectora como asociación y darla de alta como núcleo zoológico (tasas: %d €)." % [Game.money(), Catalog.REGISTRATION_FEE])
			var name_edit := LineEdit.new()
			name_edit.placeholder_text = "Nombre de la protectora (p. ej. Huellas de Isla)"
			name_edit.custom_minimum_size = Vector2(500, 44)
			name_edit.max_length = 40
			_modal_body.add_child(name_edit)
			_btn("Registrar la protectora (%d €)" % Catalog.REGISTRATION_FEE, func() -> void:
				if not Game.register(name_edit.text):
					toast("Escribe un nombre de al menos 3 letras.", "mal"))
			if Game.has_save():
				_sep()
				_btn("Cargar partida guardada", func() -> void:
					if Game.load_game():
						world.place_player_at_shelter()
						if Game.s["step"] == "jugando":
							_open = ""
							close_panel()
						else:
							_rebuild())
			name_edit.grab_focus.call_deferred()
		"prestamo":
			_modal_title.text = "Banco · Pide un préstamo"
			_p("«%s» ya está registrada. Tienes %d €. Para comprar un terreno y construir necesitas un préstamo. La cuota se cobra cada 30 días: si no hay saldo, cuenta como impago. Tres impagos seguidos y el banco embarga." % [s["name"], Game.money()])
			for l in Catalog.LOANS:
				var total := int(round(l["amount"] * (1.0 + l["interest"] * l["months"] / 12.0)))
				var monthly := int(ceil(float(total) / l["months"]))
				_btn("%s: %d € a %d meses (%.1f %%) → cuota %d €/mes" % [l["name"], l["amount"], l["months"], l["interest"] * 100, monthly],
					Game.take_loan.bind(l["id"]))
		"terreno":
			_modal_title.text = "Elige el terreno"
			_p("Dinero disponible: %d €. Recuerda reservar %d € para la caseta y algo para pienso y veterinario." % [Game.money(), Catalog.STARTER_BUILDING["price"]])
			for l in Catalog.LANDS:
				if l["tier"] != 1:
					continue
				var ok := Game.can_afford(l["price"] + Catalog.STARTER_BUILDING["price"])
				_btn("%s — %d €\n%s" % [l["name"], l["price"], l["desc"]], Game.buy_start_land.bind(l["id"]), not ok)
		"caseta":
			_modal_title.text = "Construye la caseta"
			var b: Dictionary = Catalog.STARTER_BUILDING
			_p("Terreno: %s. Una caseta sencilla con %d plazas, solo para que los animales duerman y coman. Todo lo demás (veterinario, baños...) tendrás que pagarlo fuera, de momento.\n\nEmpiezas con 2 voluntarios, 15 kg de pienso y algo de productos de limpieza." % [Game.land_info()["name"], b["slots"]])
			_btn("Construir %s (%d €)" % [b["name"], b["price"]], func() -> void:
				if Game.build_starter():
					world.place_player_at_shelter()
					_open = ""
					close_panel()
					toast("Pulsa Tab para abrir la tablet y ver el primer aviso.", "aviso"),
				not Game.can_afford(b["price"]))
		_:
			_open = ""
			close_panel()


# =====================================================================
# Tablet
# =====================================================================

const TABS := ["Resumen", "Avisos", "Animales", "Adopciones", "Tienda", "Obras", "Personal", "Donantes"]


func _build_tablet() -> void:
	_modal_title.text = "Tablet · %s" % Game.s["name"]
	var bar := HBoxContainer.new()
	_modal_body.add_child(bar)
	for i in TABS.size():
		var b := Button.new()
		b.text = TABS[i]
		b.toggle_mode = true
		b.button_pressed = i == _tab
		b.pressed.connect(func() -> void:
			_tab = i
			_rebuild()
			_scroll.scroll_vertical = 0)
		bar.add_child(b)
	_sep()
	match TABS[_tab]:
		"Resumen": _tab_summary()
		"Avisos": _tab_calls()
		"Animales": _tab_animals()
		"Adopciones": _tab_adoptions()
		"Tienda": _tab_shop(true)
		"Obras": _tab_build()
		"Personal": _tab_staff()
		"Donantes": _tab_donors()


func _tab_summary() -> void:
	var s := Game.s
	var loan: Dictionary = s["loan"]
	_h("%s · %s" % [Game.date_text(), Game.time_text()])
	_p("Dinero: %d €   ·   Reputación: %d / 100" % [Game.money(), s["reputation"]])
	if loan.get("months_left", 0) > 0:
		_p("Préstamo: cuota de %d € cada 30 días · quedan %d meses (%d €)%s" % [loan["monthly"], loan["months_left"], loan["left"],
			"   ‼ impagos: %d" % loan["missed"] if loan["missed"] > 0 else ""])
	var next_month: int = 30 - ((s["day"] - 1) % 30)
	_p("Próximo cierre de mes en %d días · Gastos fijos: sueldos %d € + luz/agua/seguro %d € · Socios: +%d €" % [
		next_month, Game.monthly_wages(), Catalog.FIXED_MONTHLY - (Catalog.SOLAR_SAVING if Game.has_building("placas") else 0), Game.monthly_donors()])
	_p("Refugio: %d / %d plazas · Terreno: %s (nivel %d)" % [Game.occupancy(), Game.slots(), Game.land_info().get("name", ""), s["tier"]])
	var st: Dictionary = s["stock"]
	var need := Game.daily_need("pienso")
	var hay := Game.daily_need("heno")
	_p("Pienso: %.1f kg (%s) · Premium: %.1f kg · Heno: %.0f kg%s · Limpieza: %.1f usos · Arena: %.0f" % [
		st["pienso"], "≈ %d días" % int((st["pienso"] + st["pienso_premium"]) / need) if need > 0 else "sin consumo", st["pienso_premium"],
		st.get("heno", 0.0), " (≈ %d días)" % int(st.get("heno", 0.0) / hay) if hay > 0 else "", st["limpieza"], st["arena"]])
	_p("Salud media %d · Higiene media %d · Ánimo medio %d" % [Game.average("health"), Game.average("hygiene"), Game.average("mood")])
	_p("Hoy: %s · %s" % ["comida puesta ✔" if s["fed_today"] else "sin dar de comer (los voluntarios quizá lo hagan)",
		"limpio ✔" if s["cleaned_today"] else "sin limpiar"])
	if not s["events"].is_empty():
		var names := {"calor": "Ola de calor", "incendio": "Incendio forestal", "caza": "Abandonos de fin de caza", "temporal": "Temporal"}
		var ev: PackedStringArray = []
		for e in s["events"]:
			ev.append("%s (%d días)" % [names.get(e, e), s["events"][e]])
		_p("Situación: " + ", ".join(ev))
	var t: Dictionary = s["stats"]
	_p("Historial: %d rescatados · %d adoptados · %d devueltos · %d con su dueño · %d perdidos · %d denuncias" % [
		t["rescued"], t["adopted"], t["returned"], t["to_owner"], t["lost"], t["denuncias"]])
	_sep()
	_h("Registro")
	for line in s["log"].slice(0, 15):
		_p(line, 15)


func _tab_calls() -> void:
	var s := Game.s
	_h("Avisos de recogida")
	if s["calls"].is_empty():
		_p("No hay avisos ahora mismo.")
	for c in s["calls"]:
		var a := Game.animal(c["animal"])
		var dist := int(Game.player_pos.distance_to(a.get("pos", Vector3.ZERO)))
		_p("%s%s\n   A %d m · plazo: %s" % ["‼ URGENTE · " if c["urgent"] else "", c["desc"], dist,
			"hoy antes de las 20:00" if c["deadline"] == s["day"] else "mañana"])
		_btn("Derivar a otra protectora (quedan %d hoy)" % maxi(0, Game.FORWARD_PER_DAY - s.get("forwarded_today", 0)),
			func() -> void: _act(Game.forward_call(c["id"])), s.get("forwarded_today", 0) >= Game.FORWARD_PER_DAY)
	_p("Los avisos aparecen en el mundo como columnas de luz roja. Con %s puedes llevar %d animal(es)." % [Game.vehicle()["name"], Game.capacity()], 15)
	var esc := Game.animals_at("escapado")
	if not esc.is_empty():
		_sep()
		_h("Animales escapados (con chip)")
		for a in esc:
			var seen: Vector3 = a.get("seen_pos", a["pos"])
			_p("📡 %s · última señal a las %s, a %d m de ti%s" % [a["name"], a.get("seen_at", "?"), int(Game.player_pos.distance_to(seen)),
				"" if Game.has_equipment("rastreador") else " (la señal es intermitente: puede haberse movido)"])
	var decide: Array = s["animals"].filter(func(a: Dictionary) -> bool: return a.get("owner_case", "") == "decidir")
	if not decide.is_empty():
		_sep()
		_h("Casos de posible maltrato")
		for a in decide:
			_p("%s tiene chip de un propietario y el veterinario ha encontrado indicios de maltrato." % a["name"])
			var row := _row()
			_btn("Denunciar en el SEPRONA", func() -> void: _act(Game.owner_decision(a["id"], true)), false, row)
			_btn("Contactar con el dueño", func() -> void: _act(Game.owner_decision(a["id"], false)), false, row)


func _animal_line(a: Dictionary) -> String:
	var flags: PackedStringArray = []
	flags.append("revisado" if a["reviewed"] else "sin revisar")
	match a["chip"]:
		"desconocido": flags.append("chip ?")
		"no": flags.append("sin chip")
		"dueño": flags.append("chip de dueño")
		"nuestro": flags.append("chip ✔")
	if a["vaccinated"]: flags.append("vacunado")
	if a["dewormed"]: flags.append("desparasitado")
	if a["sterilized"]: flags.append("esterilizado")
	if a["sick"]: flags.append("ENFERMO")
	if a["injured"]: flags.append("HERIDO")
	if a["abuse_known"]: flags.append("maltrato")
	var case_names := {"contactando": "contactando con el dueño", "decidir": "¿denunciar?", "denuncia": "denuncia en curso", "sin_respuesta": "dueño sin responder", "recogida": "su dueño viene a recogerlo"}
	if a.get("owner_case", "") != "":
		flags.append(case_names[a["owner_case"]])
	return "%s · %s %s, %s, %d años · salud %d · nutrición %d · higiene %d · ánimo %d\n   %s" % [
		a["name"], a["species"], a["size"], a["energy"], a["age"], a["health"], a["nutrition"], a["hygiene"], a["mood"], " · ".join(flags)]


func _tab_animals() -> void:
	var where := {"llevando": "Contigo", "refugio": "En el refugio", "acogida": "En casas de acogida", "escapado": "Escapados"}
	for loc in where:
		var list := Game.animals_at(loc)
		if list.is_empty():
			continue
		_h("%s (%d)" % [where[loc], list.size()])
		for a in list:
			var line := _animal_line(a)
			if loc == "refugio":
				line += "\n   " + ("✔ LISTO PARA ADOPCIÓN" if Game.is_adoptable(a) else "Para adoptar falta: " + ", ".join(Game.missing_for_adoption(a)))
			_p(line, 16)
	if Game.occupancy() == 0 and Game.carried().is_empty():
		_p("Aún no tienes animales. Atiende los avisos.")


func _tab_adoptions() -> void:
	var s := Game.s
	_h("Solicitudes de adopción")
	if s["requests"].is_empty():
		_p("No hay solicitudes. Llegan más con buena reputación, un terreno cerca del pueblo o un patio de paseo.")
	for rq in s["requests"]:
		var waiting: bool = rq.get("state", "") == "esperando"
		_p("%s · vive en %s · busca %s %s y %s\n   %s" % [rq["who"], rq["home"], rq["species"], rq["size"], rq["energy"],
			"‼ ESTÁ ESPERANDO EN LA ENTRADA DEL REFUGIO" if waiting else "Visita: " + Game.visit_text(rq)])
		if not waiting:
			var row := _row()
			_btn("Llamar para que vengan ya", func() -> void: _act(Game.call_visit_now(rq["id"])), false, row)
			_btn("Rechazar solicitud", func() -> void: Game.reject_request(rq["id"]), false, row)
	_sep()
	var available := Game.sheltered().filter(Game.is_adoptable)
	_h("Listos para adopción (%d)" % available.size())
	for a in available:
		_p("%s · %s %s, %s, %d años" % [a["name"], a["species"], a["size"], a["energy"], a["age"]], 16)
	_p("Las familias vienen en persona: habla con ellas en la entrada del refugio y preséntales al animal que mejor encaje. Un mal emparejamiento acaba a menudo en devolución.", 15)


func _tab_shop(include_big: bool) -> void:
	_h("Productos (envío al refugio)")
	for p in Catalog.PRODUCTS:
		var row := _row()
		var price := int(p["price"] * (0.9 if Game.has_building("almacen") else 1.0))
		_p("%s — %d €" % [p["name"], price], 17, row)
		for q in [1, 5]:
			_btn("× %d" % q, func() -> void: _act(Game.buy_product(p["id"], q)), not Game.can_afford(price * q), row)
	if not include_big:
		return
	_sep()
	_h("Vehículos")
	for v in Catalog.VEHICLES:
		if v["id"] == "a_pie":
			continue
		var owned: bool = v["id"] in Game.s["vehicles"]
		_btn("%s — %s · lleva %d animales · %d km/h" % [v["name"], "en propiedad" if owned else "%d €" % v["price"], v["capacity"], int(v["speed"] * 3.6)],
			func() -> void: _act(Game.buy_vehicle(v["id"])), owned or not Game.can_afford(v["price"]))
	_p("Para cambiar de vehículo, ve a la puerta del refugio.", 15)
	_sep()
	_h("Equipamiento")
	for e in Catalog.EQUIPMENT:
		var owned := Game.has_equipment(e["id"])
		_btn("%s — %s\n%s" % [e["name"], "en propiedad" if owned else "%d €" % e["price"], e["desc"]],
			func() -> void: _act(Game.buy_equipment(e["id"])), owned or not Game.can_afford(e["price"]))


func _tab_build() -> void:
	_h("Terreno")
	for l in Catalog.LANDS:
		if l["tier"] <= 1:
			continue
		var done: bool = Game.s["tier"] >= l["tier"]
		_btn("%s — %s\n%s" % [l["name"], "hecho" if done else "%d €" % l["price"], l["desc"]],
			func() -> void: _act(Game.buy_land_upgrade(l["id"])), done or l["tier"] != Game.s["tier"] + 1 or not Game.can_afford(l["price"]))
	_sep()
	_h("Construcciones")
	for b in Catalog.BUILDINGS:
		var why := Game.can_build(b)
		var n: int = Game.s["buildings"].get(b["id"], 0)
		_btn("%s — %d €%s%s%s" % [b["name"], b["price"], "  (tienes %d)" % n if n > 0 else "",
			"\n" + b["desc"] if b.has("desc") else "", "\n[%s]" % why if why != "" else ""],
			func() -> void: _act(Game.build(b["id"])), why != "")


func _tab_staff() -> void:
	_h("Personal · sueldos: %d €/mes" % Game.monthly_wages())
	for st in Catalog.STAFF:
		var row := _row()
		_p("%s × %d%s\n%s" % [st["name"], Game.staff_count(st["id"]), " · %d €/mes" % st["wage"] if st["wage"] > 0 else " · sin sueldo", st["desc"]], 16, row)
		_btn("Contratar" if st["wage"] > 0 else "Buscar", func() -> void: _act(Game.hire(st["id"])), false, row)
		_btn("Despedir" if st["wage"] > 0 else "Despedir", func() -> void: _act(Game.fire(st["id"])), Game.staff_count(st["id"]) == 0, row)


func _tab_donors() -> void:
	_h("Socios: %d · %d € al mes" % [Game.s["donors"].size(), Game.monthly_donors()])
	_p("Las familias adoptantes a veces se hacen socias. Para conseguir más, organiza campañas. Con más reputación, más éxito.")
	for c in Catalog.CAMPAIGNS:
		var locked: bool = Game.s["reputation"] < c.get("min_rep", 0)
		_btn("%s — %d €%s\n%s" % [c["name"], c["price"], "  [reputación %d]" % c["min_rep"] if locked else "", c.get("desc", "Socios nuevos y recaudación.")],
			func() -> void: _act(Game.run_campaign(c["id"])), locked or not Game.can_afford(c["price"]))


# =====================================================================
# Lugares
# =====================================================================

func _build_refugio() -> void:
	_modal_title.text = "Refugio · %s" % Game.s["name"]
	var car := Game.carried()
	if not car.is_empty():
		_btn("Dejar en el refugio a: " + ", ".join(PackedStringArray(car.map(func(a: Dictionary) -> String: return a["name"]))),
			func() -> void: _act(Game.deposit_all()))
	var row := _row()
	_btn("Dar de comer y agua a todos", func() -> void: _act(Game.feed_all()), Game.s["fed_today"], row)
	_btn("Limpiar instalaciones", func() -> void: _act(Game.clean_all()), Game.s["cleaned_today"], row)
	_btn("Dormir (terminar el día)", func() -> void:
		close_panel()
		Game.sleep(), false, row)
	if Game.s["vehicles"].size() > 1:
		var vrow := _row()
		_p("Vehículo:", 17, vrow)
		for id in Game.s["vehicles"]:
			var v := Game._find(Catalog.VEHICLES, id)
			_btn(v["name"], func() -> void: _act(Game.use_vehicle(id)), id == Game.s["vehicle"], vrow)
	_sep()
	_h("Animales en el refugio (%d / %d plazas) · casas de acogida: %d / %d" % [Game.occupancy(), Game.slots(), Game.fostered().size(), Game.foster_capacity()])
	for a in Game.fostered():
		var frow := _row()
		_p("🏡 %s está en una casa de acogida (%d días)" % [a["name"], a.get("foster_days", 0)], 16, frow)
		_btn("Traer de vuelta", func() -> void: _act(Game.back_from_foster(a["id"])), false, frow)
	if Game.occupancy() == 0:
		_p("No hay animales todavía.")
	for a in Game.sheltered():
		_p(_animal_line(a), 16)
		var arow := _row()
		_btn("Llevar conmigo", func() -> void: _act(Game.take_out(a["id"])), false, arow)
		_btn("A casa de acogida", func() -> void: _act(Game.send_to_foster(a["id"])),
			Game.fostered().size() >= Game.foster_capacity() or a["sick"] or a["injured"], arow)
		for sv in Catalog.SERVICES:
			if Game.can_do_own(sv):
				_btn("%s (%d €)" % [Catalog.SERVICES[sv]["name"], Game.service_price(sv, true)],
					func() -> void: _act(Game.apply_service(a["id"], sv, true)), false, arow)
	_p("Para ir al veterinario o a la peluquería, lleva a los animales contigo («Llevar conmigo»).", 15)


## Servicios hechos en las instalaciones propias, para los animales del refugio.
func _build_own_services(title: String, services: Array, missing: String) -> void:
	_modal_title.text = title
	var usable := services.filter(func(sv: String) -> bool: return Game.can_do_own(sv))
	if usable.is_empty():
		_p(missing)
		return
	var prices: PackedStringArray = []
	for sv in usable:
		prices.append("%s %d € (fuera: %d €)" % [Catalog.SERVICES[sv]["name"], Catalog.SERVICES[sv]["own"], Catalog.SERVICES[sv]["ext"]])
	_p("Precios con tus instalaciones: " + " · ".join(prices), 15)
	_sep()
	var list := Game.sheltered()
	if list.is_empty():
		_p("No hay animales en el refugio.")
	# Primero los que necesitan algo.
	list.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return Game.is_adoptable(b) and not Game.is_adoptable(a))
	for a in list:
		_p(_animal_line(a), 16)
		var row := _row()
		for sv in usable:
			_btn("%s (%d €)" % [Catalog.SERVICES[sv]["name"], Catalog.SERVICES[sv]["own"]],
				func() -> void: _act(Game.apply_service(a["id"], sv, true)), not Game.can_afford(Catalog.SERVICES[sv]["own"]), row)


func _services_for_carried(services: Array, place: String) -> void:
	var car := Game.carried()
	if car.is_empty():
		_p("No traes ningún animal. Recógelos en la calle o sácalos del refugio con «Llevar conmigo».")
		return
	for a in car:
		_p(_animal_line(a), 16)
		var row := _row()
		for sv in services:
			var price := Game.service_price(sv, false)
			_btn("%s (%d €)" % [Catalog.SERVICES[sv]["name"], price],
				func() -> void: _act(Game.apply_service(a["id"], sv, false)), not Game.can_afford(price), row)
	_sep()
	if Game.s.get("vet_agreement", false) and place == "la clínica":
		_p("Precios con el convenio de la protectora (-30 %).", 15)
	_p("Servicios en %s. Cuando tengas instalaciones y personal propios, saldrá mucho más barato." % place, 15)


func _build_clinica() -> void:
	_modal_title.text = "Clínica veterinaria"
	_p("La revisión incluye la lectura del chip y detecta enfermedades, heridas e indicios de maltrato.")
	_services_for_carried(["revision", "vacunas", "chip", "desparasitar", "tratamiento", "esterilizar"], "la clínica")


func _build_peluqueria() -> void:
	_modal_title.text = "Peluquería canina"
	_services_for_carried(["bano", "desparasitar"], "la peluquería")


func _build_tienda_lugar() -> void:
	_modal_title.text = "Tienda de piensos y limpieza"
	_tab_shop(false)
	_sep()
	_p("Vehículos y equipamiento: desde la tablet (Tab → Tienda).", 15)


func _build_ayuntamiento() -> void:
	_modal_title.text = "Ayuntamiento · Banco · SEPRONA"
	var loan: Dictionary = Game.s["loan"]
	_h("Banco")
	if loan.get("months_left", 0) > 0:
		_p("%s: quedan %d € en %d cuotas de %d €. Impagos: %d." % [loan["name"], loan["left"], loan["months_left"], loan["monthly"], loan["missed"]])
	else:
		_p("No tienes préstamos pendientes.")
	_sep()
	_h(Catalog.GRANT["name"] + " (%d €)" % Catalog.GRANT["amount"])
	for req in Game.grant_check():
		_p("%s %s" % ["✔" if req[1] else "✘", req[0]], 16)
	_p("Si cumples los requisitos, un inspector revisará la higiene, la salud de los animales y la ocupación.", 15)
	_btn("Solicitar subvención", func() -> void: _act(Game.apply_grant()))
	_sep()
	_h("SEPRONA (Guardia Civil)")
	var decide: Array = Game.s["animals"].filter(func(a: Dictionary) -> bool: return a.get("owner_case", "") == "decidir")
	if decide.is_empty():
		_p("No tienes casos pendientes de denuncia. Si el veterinario encuentra indicios de maltrato en un animal con chip, podrás denunciar al propietario.")
	for a in decide:
		_p("%s: indicios de maltrato, propietario identificado por el chip." % a["name"])
		_btn("Presentar denuncia", func() -> void: _act(Game.owner_decision(a["id"], true)))


# =====================================================================
# Conversaciones
# =====================================================================

func open_dialog(npc_id: String) -> void:
	_dialog_id = npc_id
	_dialog = Dialogues.talk(npc_id)
	open_panel("dialogo")


func _build_dialog() -> void:
	var who := ""
	if Dialogues.PEOPLE.has(_dialog_id):
		var p: Dictionary = Dialogues.PEOPLE[_dialog_id]
		who = "%s · %s" % [p["name"], p["role"]]
	elif _dialog.has("who"):
		who = _dialog["who"]
	else:
		for n in get_tree().get_nodes_in_group("npc"):
			if n.npc_id == _dialog_id:
				who = "%s · %s" % [n.display_name, n.role]
	_modal_title.text = who
	var raw: String = _dialog["text"]
	var l := _p(raw if raw.begins_with("«") or raw.begins_with("—") else "«%s»" % raw, 20)
	l.add_theme_color_override("font_color", Color(1, 0.96, 0.85))
	_sep()
	for opt in _dialog["options"]:
		var target = opt[1]
		if target is Callable:
			# Acción: su resultado es la siguiente frase de la conversación.
			_btn(opt[0], func() -> void:
				var next: Dictionary = target.call()
				if not next.has("who"):
					next["who"] = who
				_dialog = next
				_rebuild())
		elif target == "":
			_btn(opt[0], close_panel)
		else:
			_btn(opt[0], func() -> void:
				_open = ""
				open_panel(target))


# =====================================================================
# Resumen del día, pausa y fin
# =====================================================================

func _on_day_ended(summary: String) -> void:
	_summary_text = summary
	if _open == "fin":
		return
	open_panel("resumen")


func _build_summary() -> void:
	_modal_title.text = "Fin del día"
	_p(_summary_text)
	_btn("Empezar el día siguiente", _close_summary)


func _close_summary() -> void:
	_open = ""
	close_panel()
	world.place_player_at_shelter()


func _build_pause() -> void:
	_modal_title.text = "Pausa"
	_btn("Seguir jugando", close_panel)
	if Tutorial.active():
		_btn("Saltar tutorial", func() -> void:
			Tutorial.skip()
			toast("Tutorial desactivado.", "info")
			close_panel())
	_btn("Guardar partida", func() -> void:
		Game.save_game()
		toast("Partida guardada.", "bien"))
	_btn("Cargar partida", func() -> void:
		if Game.load_game():
			world.place_player_at_shelter()
			close_panel(), not Game.has_save())
	_btn("Nueva partida", func() -> void:
		Game.new_game()
		_open = ""
		open_panel("intro"))
	_btn("Salir del juego", get_tree().quit)
	_sep()
	_p("Se guarda automáticamente al final de cada día.", 15)


func _on_game_over(reason: String) -> void:
	_game_over_text = reason
	open_panel("fin")


func _build_game_over() -> void:
	_modal_title.text = "Fin de la partida"
	_p(_game_over_text)
	var t: Dictionary = Game.s["stats"]
	_p("Días: %d · Rescatados: %d · Adoptados: %d" % [Game.s["day"], t["rescued"], t["adopted"]])
	_btn("Nueva partida", func() -> void:
		Game.new_game()
		_open = "intro"
		_rebuild())


# =====================================================================
# Utilidades de interfaz
# =====================================================================

func _label(size: int) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 6)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _h(text: String) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 22)
	l.add_theme_color_override("font_color", Color(1, 0.85, 0.55))
	_modal_body.add_child(l)


func _p(text: String, size: int = 18, parent: Control = null) -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", size)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	(parent if parent else _modal_body).add_child(l)
	return l


func _btn(text: String, cb: Callable, disabled: bool = false, parent: Control = null) -> Button:
	var b := Button.new()
	b.text = text
	b.disabled = disabled
	b.custom_minimum_size.y = 38
	b.pressed.connect(cb)
	if parent == null:
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	(parent if parent else _modal_body).add_child(b)
	return b


func _row() -> HFlowContainer:
	var r := HFlowContainer.new()
	r.add_theme_constant_override("h_separation", 8)
	r.add_theme_constant_override("v_separation", 6)
	_modal_body.add_child(r)
	return r


func _sep() -> void:
	_modal_body.add_child(HSeparator.new())


func _make_theme() -> Theme:
	var t := Theme.new()
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color(0.1, 0.12, 0.14, 0.94)
	panel.set_corner_radius_all(14)
	t.set_stylebox("panel", "PanelContainer", panel)
	var btn := StyleBoxFlat.new()
	btn.bg_color = Color(0.2, 0.42, 0.38)
	btn.set_corner_radius_all(8)
	btn.content_margin_left = 12
	btn.content_margin_right = 12
	btn.content_margin_top = 6
	btn.content_margin_bottom = 6
	var hover := btn.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.26, 0.52, 0.47)
	var pressed := btn.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(0.85, 0.55, 0.2)
	var disabled := btn.duplicate() as StyleBoxFlat
	disabled.bg_color = Color(0.22, 0.22, 0.24)
	t.set_stylebox("normal", "Button", btn)
	t.set_stylebox("hover", "Button", hover)
	t.set_stylebox("pressed", "Button", pressed)
	t.set_stylebox("hover_pressed", "Button", pressed)
	t.set_stylebox("disabled", "Button", disabled)
	t.set_font_size("font_size", "Button", 17)
	t.set_font_size("font_size", "Label", 18)
	t.set_font_size("font_size", "LineEdit", 20)
	return t
