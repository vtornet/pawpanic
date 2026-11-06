class_name Hud
extends CanvasLayer
## Interfaz en pantalla. Solo pinta lo que el anfitrión le envía.

signal next_day_pressed

var _top: Label
var _requests: Label
var _toast: Label
var _toast_time := 0.0
var _summary: PanelContainer
var _summary_text: Label
var _summary_button: Button
var _lobby: Label


func _ready() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	_top = _make_label(root, 26)
	_top.position = Vector2(24, 16)

	_requests = _make_label(root, 20)
	_requests.position = Vector2(24, 64)

	_lobby = _make_label(root, 20)
	_lobby.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_lobby.position = Vector2(-340, 16)
	_lobby.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_lobby.size = Vector2(320, 0)

	_toast = _make_label(root, 30)
	_toast.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.size = Vector2(1000, 40)
	_toast.position = Vector2(-500, 120)

	var help := _make_label(root, 18)
	help.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	help.position = Vector2(24, -40)
	help.text = "WASD mover · E coger/soltar · Shift impulso   |   Baño: deja al perro sucio · Comedero: deja al perro con hambre · Mostrador: entrega al adoptante"
	help.modulate = Color(1, 1, 1, 0.75)

	_summary = PanelContainer.new()
	_summary.set_anchors_preset(Control.PRESET_CENTER)
	_summary.custom_minimum_size = Vector2(520, 0)
	_summary.position = Vector2(-260, -180)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 28)
	margin.add_child(box)
	_summary.add_child(margin)
	_summary_text = Label.new()
	_summary_text.add_theme_font_size_override("font_size", 22)
	box.add_child(_summary_text)
	_summary_button = Button.new()
	_summary_button.add_theme_font_size_override("font_size", 22)
	_summary_button.pressed.connect(func() -> void: next_day_pressed.emit())
	box.add_child(_summary_button)
	_summary.visible = false
	root.add_child(_summary)


func _make_label(parent: Control, font_size: int) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 8)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l


func show_state(s: Dictionary) -> void:
	var secs := int(ceil(s["time_left"]))
	_top.text = "Día %d   ·   %d:%02d   ·   Dinero: %d €   ·   Reputación: %d" % [
		s["day"], secs / 60, secs % 60, s["money"], s["reputation"]]
	var lines: PackedStringArray = ["Adoptantes esperando:"]
	for a: Dictionary in s["adopters"]:
		lines.append("  • Busca un perro %s y %s  (paciencia %ds)" % [a["size"], a["energy"], int(a["patience"])])
	if s["adopters"].is_empty():
		lines.append("  (nadie por ahora)")
	_requests.text = "\n".join(lines)
	_lobby.text = "Jugadores: %d" % s["players"]


func toast(text: String) -> void:
	_toast.text = text
	_toast_time = 3.0


func show_summary(text: String, button_text: String, button_enabled: bool) -> void:
	_summary_text.text = text
	_summary_button.text = button_text
	_summary_button.disabled = not button_enabled
	_summary.visible = true


func hide_summary() -> void:
	_summary.visible = false


func _process(delta: float) -> void:
	if _toast_time > 0.0:
		_toast_time -= delta
		_toast.modulate.a = clampf(_toast_time, 0.0, 1.0)
