extends Node
## Sonido del juego (autoload "Sound").
##
## Indexa todo lo que hay en res://audio por nombre de archivo, sin carpeta:
## "perro_grande_ladrido" encuentra perro_grande_ladrido_1, _2 y _3 y elige uno al azar.
##
##   Sound.play("clic")                         efecto sin posición (interfaz, el jugador)
##   Sound.play_at("gato_maullido", pos)        efecto en el mundo, se oye según la distancia
##   Sound.loop_on(nodo, "coche_marcha")        bucle pegado a un nodo 3D
##   Sound.set_music("dia")  /  Sound.set_ambience(["pueblo_dia", "perrera_coro"])
##
## Buses: Master > Musica, Efectos, Ambiente, Interfaz. Los volúmenes se guardan en user://ajustes.cfg.

const BUSES := ["Musica", "Efectos", "Ambiente", "Interfaz"]
const SETTINGS_PATH := "user://ajustes.cfg"
const MUSIC_DB := -6.0
const FADE := 2.5

## Sonidos que deben sonar en bucle aunque se carguen sueltos.
const LOOPS := ["perro_jadeo", "perrera_coro", "gato_ronroneo", "cascos_tierra", "patas_suelo", "bici_rodando",
	"coche_ralenti", "coche_marcha", "furgoneta_diesel", "remolque_traqueteo", "trafico_lejano", "manguera", "secador",
	"martillo_obra", "clinica_monitor", "oficina_ambiente", "murmullo_gente"]

var volumes := {"Master": 1.0, "Musica": 0.7, "Efectos": 1.0, "Ambiente": 0.8, "Interfaz": 0.8}

var _index := {}          # nombre base -> [rutas]
var _cache := {}          # ruta -> AudioStream
var _last := {}           # nombre -> ms de la última vez (para no repetir el mismo sonido 10 veces seguidas)
var _music: Array[AudioStreamPlayer] = []
var _music_track := ""
var _music_mood := ""
var _amb := {}            # nombre -> AudioStreamPlayer
var _ui_players: Array[AudioStreamPlayer] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_make_buses()
	_load_settings()
	_scan("res://audio")
	for i in 2:
		var p := AudioStreamPlayer.new()
		p.bus = "Musica"
		p.volume_db = -80.0
		add_child(p)
		p.finished.connect(_on_music_finished.bind(p))
		_music.append(p)
	# Clic en cualquier botón de la interfaz, sin tener que conectarlo uno a uno.
	get_tree().node_added.connect(_on_node_added)
	Game.sound.connect(_on_game_sound)
	Game.notify.connect(_on_notify)
	Game.day_ended.connect(func(_s: String) -> void: play("jingle_fin_dia", -2.0, 0.0, "Interfaz"))
	Game.game_over.connect(func(_r: String) -> void:
		set_music("")
		play("jingle_fin_partida", 0.0, 0.0, "Interfaz"))


func _exit_tree() -> void:
	# Al cerrar el juego, soltar los sonidos cargados (evita avisos de recursos sin liberar).
	for c in get_tree().root.find_children("*", "AudioStreamPlayer", true, false):
		(c as AudioStreamPlayer).stream = null
	for c in get_tree().root.find_children("*", "AudioStreamPlayer3D", true, false):
		(c as AudioStreamPlayer3D).stream = null
	_cache.clear()
	Models.clear()
	Shapes.clear()


# ---------------------------------------------------------------------
# Índice de archivos
# ---------------------------------------------------------------------

func _scan(dir_path: String) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	for sub in dir.get_directories():
		_scan(dir_path.path_join(sub))
	for f in dir.get_files():
		# En el juego exportado los archivos aparecen como .ogg.import / .ogg.remap.
		f = f.trim_suffix(".import").trim_suffix(".remap")
		if not (f.ends_with(".ogg") or f.ends_with(".wav")):
			continue
		var stem := f.get_basename()
		var base := stem
		var parts := stem.rsplit("_", true, 1)
		if parts.size() == 2 and parts[1].is_valid_int():
			base = parts[0]
		var path := dir_path.path_join(f)
		for key in ([stem, base] if base != stem else [stem]):
			if not _index.has(key):
				_index[key] = []
			if not path in _index[key]:
				_index[key].append(path)


func has(sound_name: String) -> bool:
	return _index.has(sound_name)


func count(sound_name: String) -> int:
	return _index.get(sound_name, []).size()


func stream(sound_name: String) -> AudioStream:
	var paths: Array = _index.get(sound_name, [])
	if paths.is_empty():
		return null
	var path: String = paths[randi() % paths.size()]
	if not _cache.has(path):
		var st := load(path) as AudioStream
		if st == null:
			return null
		if sound_name in LOOPS or path.contains("Ambientes") or path.contains("sica/"):
			_set_loop(st, sound_name in LOOPS or path.contains("Ambientes"))
		_cache[path] = st
	return _cache[path]


func _set_loop(st: AudioStream, on: bool) -> void:
	if st is AudioStreamOggVorbis:
		(st as AudioStreamOggVorbis).loop = on
	elif st is AudioStreamWAV and on:
		var w := st as AudioStreamWAV
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_end = int(w.get_length() * w.mix_rate)


func _throttled(sound_name: String, ms: int) -> bool:
	var now := Time.get_ticks_msec()
	if now - int(_last.get(sound_name, -100000)) < ms:
		return true
	_last[sound_name] = now
	return false


# ---------------------------------------------------------------------
# Efectos
# ---------------------------------------------------------------------

## Efecto sin posición. max_len > 0 corta el sonido (con un fundido rápido) a esos segundos.
func play(sound_name: String, volume_db: float = 0.0, pitch_var: float = 0.06, bus: String = "Efectos", max_len: float = 0.0, min_gap_ms: int = 60) -> AudioStreamPlayer:
	var st := stream(sound_name)
	if st == null or _throttled(sound_name, min_gap_ms):
		return null
	var p := AudioStreamPlayer.new()
	p.stream = st
	p.bus = bus
	p.volume_db = volume_db
	p.pitch_scale = 1.0 + randf_range(-pitch_var, pitch_var)
	add_child(p)
	p.play()
	p.finished.connect(p.queue_free)
	if max_len > 0.0:
		_cut(p, max_len)
	return p


## Sonido de interfaz (no se ve afectado por la pausa).
func ui(sound_name: String, volume_db: float = 0.0) -> void:
	play(sound_name, volume_db, 0.0, "Interfaz", 0.0, 40)


## Efecto colocado en el mundo.
func play_at(sound_name: String, pos: Vector3, volume_db: float = 0.0, max_distance: float = 45.0, pitch_var: float = 0.06, max_len: float = 0.0) -> AudioStreamPlayer3D:
	var st := stream(sound_name)
	if st == null:
		return null
	var p := AudioStreamPlayer3D.new()
	p.stream = st
	p.bus = "Efectos"
	p.volume_db = volume_db
	p.unit_size = 6.0
	p.max_distance = max_distance
	p.pitch_scale = 1.0 + randf_range(-pitch_var, pitch_var)
	p.attenuation_filter_cutoff_hz = 8000.0
	add_child(p)
	p.global_position = pos
	p.play()
	p.finished.connect(p.queue_free)
	if max_len > 0.0:
		_cut(p, max_len)
	return p


## Bucle pegado a un nodo 3D (motor de un coche, ronroneo...). Se libera con el nodo.
func loop_on(node: Node3D, sound_name: String, volume_db: float = 0.0, max_distance: float = 40.0) -> AudioStreamPlayer3D:
	var st := stream(sound_name)
	if st == null:
		return null
	var p := AudioStreamPlayer3D.new()
	p.stream = st
	p.bus = "Efectos"
	p.volume_db = volume_db
	p.unit_size = 5.0
	p.max_distance = max_distance
	node.add_child(p)
	p.play(randf() * maxf(0.0, st.get_length() - 0.1))
	return p


## Bucle sin posición (motor del vehículo del jugador). Empieza en silencio.
func loop(sound_name: String, bus: String = "Efectos") -> AudioStreamPlayer:
	var st := stream(sound_name)
	if st == null:
		return null
	var p := AudioStreamPlayer.new()
	p.stream = st
	p.bus = bus
	p.volume_db = -80.0
	add_child(p)
	p.play()
	return p


func _cut(p: Node, seconds: float) -> void:
	var tw := create_tween()
	tw.tween_interval(maxf(0.0, seconds - 0.06))
	tw.tween_property(p, "volume_db", -60.0, 0.06)
	tw.tween_callback(p.queue_free)


## Voz «simlish» de un personaje: una o dos sílabas.
func voice(person_name: String, role: String = "") -> void:
	var kind := voice_kind(person_name, role)
	var n := 1 if randf() < 0.5 else 2
	for i in n:
		var p := play("voz_" + kind, -2.0, 0.08, "Efectos", 0.9, 0)
		if p == null:
			return
		if i < n - 1:
			await get_tree().create_timer(0.55, true).timeout


static func voice_kind(person_name: String, role: String = "") -> String:
	var low := (person_name + " " + role).to_lower()
	if low.contains("niñ") or low.contains("crío"):
		return "nino"
	if low.begins_with("don ") or low.begins_with("doña ") or low.contains("abuel") or low.contains("jubilad"):
		return "mayor"
	var first := person_name.strip_edges().split(" ")[0].to_lower().trim_suffix(".")
	if first in ["dra", "sra", "una", "la", "doctora", "señora"]:
		return "mujer"
	if first in ["dr", "sr", "un", "el", "señor"]:
		return "hombre"
	const MEN := ["antonio", "manolo", "pepe", "fran", "juan", "josé", "jose", "paco", "luis", "rafa", "andrés", "nico", "sergio"]
	if first in MEN:
		return "hombre"
	if first.ends_with("a") or first in ["rocío", "inma", "pilar", "carmen", "loli", "reme", "charo", "paqui", "mari", "isabel", "maribel", "raquel"]:
		return "mujer"
	return "hombre"


# ---------------------------------------------------------------------
# Música
# ---------------------------------------------------------------------

## Estado de ánimo de la música: "menu", "dia", "tarde", "urgente", "interior" o "" (sin música).
func set_music(mood: String) -> void:
	if mood == _music_mood:
		return
	_music_mood = mood
	_play_track(_track_for(mood))


func _track_for(mood: String) -> String:
	match mood:
		"menu": return "menu_tema_principal"
		"tarde": return "atardecer"
		"urgente": return "urgencia"
		"interior": return "interior_clinica"
		"dia":
			return "dia_tranquilo_2" if _music_track == "dia_tranquilo_1" else "dia_tranquilo_1"
	return ""


func _play_track(track: String) -> void:
	if track == _music_track and track != "":
		return
	_music_track = track
	var old := _music[0]
	var new := _music[1]
	_music.reverse()
	if old.playing:
		var tw := create_tween()
		tw.tween_property(old, "volume_db", -80.0, FADE)
		tw.tween_callback(old.stop)
	if track == "":
		return
	var st := stream(track)
	if st == null:
		return
	new.stream = st
	new.volume_db = -40.0
	new.play()
	create_tween().tween_property(new, "volume_db", MUSIC_DB, FADE)


func _on_music_finished(p: AudioStreamPlayer) -> void:
	# Al acabar un tema de día, suena la otra variante; los demás se repiten.
	if p != _music[0]:
		return
	var next := _track_for(_music_mood)
	_music_track = ""
	_play_track(next)


func music_track() -> String:
	return _music_track


# ---------------------------------------------------------------------
# Ambiente (varias capas que se funden entre sí)
# ---------------------------------------------------------------------

## layers: {"pueblo_dia": 0.0, "perrera_coro": -10.0} (nombre -> volumen en dB).
func set_ambience(layers: Dictionary) -> void:
	for n in _amb.keys():
		if not layers.has(n):
			var p: AudioStreamPlayer = _amb[n]
			_amb.erase(n)
			var tw := create_tween()
			tw.tween_property(p, "volume_db", -60.0, FADE)
			tw.tween_callback(p.queue_free)
	for n in layers:
		var target: float = layers[n]
		var p: AudioStreamPlayer = _amb.get(n)
		if p == null:
			var st := stream(n)
			if st == null:
				continue
			_set_loop(st, true)
			p = AudioStreamPlayer.new()
			p.stream = st
			p.bus = "Ambiente"
			p.volume_db = -50.0
			add_child(p)
			p.play(randf() * maxf(0.0, st.get_length() - 1.0))
			_amb[n] = p
		if absf(p.get_meta("target", -999.0) - target) > 0.1:
			p.set_meta("target", target)
			create_tween().tween_property(p, "volume_db", target, FADE)


func ambience_layers() -> Array:
	return _amb.keys()


# ---------------------------------------------------------------------
# Buses y volúmenes
# ---------------------------------------------------------------------

func _make_buses() -> void:
	for b in BUSES:
		if AudioServer.get_bus_index(b) == -1:
			AudioServer.add_bus()
			var i := AudioServer.bus_count - 1
			AudioServer.set_bus_name(i, b)
			AudioServer.set_bus_send(i, "Master")


func set_volume(bus: String, value: float) -> void:
	volumes[bus] = clampf(value, 0.0, 1.0)
	var i := AudioServer.get_bus_index(bus)
	if i != -1:
		AudioServer.set_bus_volume_db(i, linear_to_db(maxf(volumes[bus], 0.0001)))
		AudioServer.set_bus_mute(i, volumes[bus] <= 0.001)
	_save_settings()


func _load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) == OK:
		for b in volumes:
			volumes[b] = float(cfg.get_value("volumen", b, volumes[b]))
	for b in volumes:
		var i := AudioServer.get_bus_index(b)
		if i != -1:
			AudioServer.set_bus_volume_db(i, linear_to_db(maxf(volumes[b], 0.0001)))
			AudioServer.set_bus_mute(i, volumes[b] <= 0.001)


func _save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH)
	for b in volumes:
		cfg.set_value("volumen", b, volumes[b])
	cfg.save(SETTINGS_PATH)


# ---------------------------------------------------------------------
# Botones
# ---------------------------------------------------------------------

func _on_node_added(n: Node) -> void:
	if n is BaseButton:
		var b := n as BaseButton
		b.pressed.connect(func() -> void: ui("clic", -3.0))
		b.mouse_entered.connect(func() -> void:
			if not b.disabled:
				ui("hover", -14.0))
	elif n is Slider:
		(n as Slider).drag_ended.connect(func(_c: bool) -> void: ui("clic", -6.0))


# ---------------------------------------------------------------------
# Sonidos de la partida
# ---------------------------------------------------------------------

## Qué sonido hace un animal ("" si ninguno: las tortugas no dicen nada).
static func animal_call(a: Dictionary) -> String:
	var unwell: bool = a.get("injured", false) or a.get("sick", false) or a.get("health", 100) < 35
	match a.get("species", ""):
		"perro":
			if unwell:
				return "perro_gemido"
			if a.get("energy", "") == "miedoso" and randf() < 0.4:
				return "perro_grunido"
			match a.get("size", "mediano"):
				"pequeño": return "perro_pequeno_ladrido"
				"grande": return "perro_grande_ladrido"
			return "perro_mediano_ladrido"
		"gato":
			if a.get("energy", "") == "miedoso" and randf() < 0.3:
				return "gato_bufido"
			return "gato_maullido_cria" if a.get("age", 3) < 1 else "gato_maullido"
		"conejo": return "conejo_golpe_pata" if randf() < 0.5 else "conejo_chillido_suave"
		"cabra": return "cabra_balido"
		"burro": return "burro_rebuzno"
		"caballo": return "caballo_relincho" if randf() < 0.4 else "caballo_resoplido"
		"erizo": return "erizo_resoplido"
		"ave": return "rapaz_chillido"
	return ""


func _on_game_sound(id: String) -> void:
	if id.begins_with("servicio_"):
		var parts := id.trim_prefix("servicio_").split(":")
		if parts[0] == "bano":
			play("manguera", -6.0, 0.0, "Efectos", 2.5)
			if parts.size() > 1 and parts[1] == "perro":
				await get_tree().create_timer(2.6, true).timeout
				play("perro_sacudida", -2.0)
		elif parts.size() > 1:
			await get_tree().create_timer(0.4, true).timeout
			play(animal_call({"species": parts[1]}), -6.0)
		return
	match id:
		"reja":
			play("reja_abrir", -2.0)
			await get_tree().create_timer(0.9, true).timeout
			play("reja_cerrar", -2.0)
			play("cerrojo", -6.0)
		"comer":
			play("saco_pienso", -4.0)
			await get_tree().create_timer(0.7, true).timeout
			play("pienso_cuenco", -2.0)
			await get_tree().create_timer(1.0, true).timeout
			play("comer_pienso", -6.0)
		"obra":
			play("martillo_obra", -2.0, 0.0, "Efectos", 3.5)
		"jingle_adopcion", "jingle_devolucion", "jingle_nuevo_terreno":
			play(id, -1.0, 0.0, "Interfaz")
			if id == "jingle_adopcion":
				play("sello_documento", -4.0)
		"dinero_entra", "dinero_sale":
			play(id, -6.0, 0.0, "Interfaz", 0.0, 400)
		_:
			play(id, -2.0)


func _on_notify(text: String, kind: String) -> void:
	match kind:
		"bien":
			ui("logro" if text.begins_with("🏆") else "objetivo_completado")
		"aviso":
			if text.begins_with("Objetivo:"):
				ui("objetivo_completado", -2.0)
			elif text.contains("herido") or text.contains("mal estado") or text.contains("urgente"):
				ui("aviso_urgente")
			else:
				ui("aviso_normal")
		"mal":
			ui("aviso_urgente" if text.contains("escapado") or text.contains("urgente") else "error", -2.0)
		_:
			ui("aviso_normal", -6.0)


## Resultado de una acción del jugador: si no se ha podido hacer, suena el error.
func action_result(text: String) -> void:
	if text.begins_with("No ") or text.begins_with("Ya ") or text.begins_with("Primero") or text.begins_with("Necesitas") \
			or text.begins_with("Para ") or text.begins_with("Llevas demasiados") or text.begins_with("Aún no"):
		ui("error", -4.0)
