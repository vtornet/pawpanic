extends Node3D
## Punto de entrada: crea el nivel y muestra el menú (solo / crear / unirse).
##
## Argumentos opcionales tras "--" (útiles para probar dos ventanas a la vez):
##   --solo            empieza directamente en solitario
##   --host            crea partida
##   --join=IP         se une a una partida
##   --quit-after=N    cierra tras N segundos (pruebas automáticas)

var level: Level
var _menu: Control
var _status: Label
var _ip: LineEdit


func _ready() -> void:
	level = Level.new()
	level.name = "Level"
	add_child(level)
	_build_menu()

	Net.session_started.connect(_on_session_started)
	Net.session_failed.connect(_on_session_failed)

	for arg in OS.get_cmdline_user_args():
		if arg == "--solo":
			Net.play_solo()
		elif arg == "--host":
			_host()
		elif arg.begins_with("--join="):
			_ip.text = arg.get_slice("=", 1)
			_join()
		elif arg == "--smoke":
			_run_smoke.call_deferred()
		elif arg.begins_with("--report-after="):
			get_tree().create_timer(float(arg.get_slice("=", 1))).timeout.connect(_report)
		elif arg.begins_with("--quit-after="):
			get_tree().create_timer(float(arg.get_slice("=", 1))).timeout.connect(get_tree().quit)


func _build_menu() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)

	_menu = PanelContainer.new()
	_menu.set_anchors_preset(Control.PRESET_CENTER)
	_menu.custom_minimum_size = Vector2(460, 0)
	_menu.position = Vector2(-230, -220)
	layer.add_child(_menu)

	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 32)
	_menu.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	margin.add_child(box)

	var title := Label.new()
	title.text = "PAW PANIC"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 52)
	box.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Caos cooperativo en la protectora"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(subtitle)

	box.add_child(_button("Jugar solo", func() -> void: Net.play_solo()))
	box.add_child(_button("Crear partida", _host))

	var join_row := HBoxContainer.new()
	_ip = LineEdit.new()
	_ip.text = "127.0.0.1"
	_ip.placeholder_text = "IP del anfitrión"
	_ip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	join_row.add_child(_ip)
	join_row.add_child(_button("Unirse", _join))
	box.add_child(join_row)

	_status = Label.new()
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD
	box.add_child(_status)


func _button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size.y = 44
	b.pressed.connect(cb)
	return b


func _host() -> void:
	var err := Net.host()
	if err != OK:
		_status.text = "No se pudo crear la partida (puerto %d ocupado?)" % Net.DEFAULT_PORT


func _join() -> void:
	var err := Net.join(_ip.text.strip_edges())
	_status.text = "Conectando..." if err == OK else "Dirección no válida"


func _on_session_started() -> void:
	_menu.visible = false
	if multiplayer.is_server():
		level.start_session()
		print("[PawPanic] Partida iniciada como anfitrión")
	else:
		level.join_session()
		print("[PawPanic] Conectado como cliente %d" % multiplayer.get_unique_id())


func _report() -> void:
	print("[PawPanic] REPORT id=%d jugadores=%d perros=%d" % [
		multiplayer.get_unique_id(), level.players_root.get_child_count(), level.dogs().size()])


func _run_smoke() -> void:
	var test: Node = load("res://tests/smoke_test.gd").new()
	add_child(test)
	test.run(level)


func _on_session_failed(reason: String) -> void:
	_menu.visible = true
	_status.text = reason
