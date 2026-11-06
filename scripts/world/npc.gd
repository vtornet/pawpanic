class_name Npc
extends Node3D
## Persona con la que se puede hablar. Usa los personajes animados de Kenney (mini-characters):
## anda o espera según «walking», se gira hacia el jugador cuando está cerca y asiente al hablar.

signal talked(npc_id: String)

const SCALE := 2.2           # los modelos miden unos 0,8 m
## Modelos genéricos (los de bata, traje o uniforme se reservan para los oficios).
const WOMEN := ["female-b", "female-c", "female-d", "female-f"]
const MEN := ["male-a", "male-b", "male-d", "male-f"]
## Oficios con un modelo fijo: look["model"] o el rol.
const ROLE_MODELS := {
	"veterinaria": "female-e", "veterinario": "male-e", "seprona": "male-c", "banco": "male-d",
	"registro": "female-d", "recepcion": "female-b", "peluquera": "female-f", "dependiente": "male-b", "crea": "female-c",
}

var npc_id := ""
var display_name := ""
var role := ""
var walking := false   # lo activa quien lo mueve (vecinos que pasean, personal del refugio)

var _model: Node3D
var _anim: AnimationPlayer
var _body: StaticBody3D
var _t := 0.0
var _seed := 0.0
var _busy := 0.0       # tiempo restante de un gesto (asentir) antes de volver a esperar


## look: {"model": "female-e" (opcional), "long_hair": bool (mujer), ...}. Los colores antiguos se ignoran.
static func create(id: String, p_name: String, p_role: String, look: Dictionary) -> Npc:
	var n := Npc.new()
	n.add_to_group("npc")
	n.npc_id = id
	n.display_name = p_name
	n.role = p_role
	n._seed = float(hash(id) % 1000)
	n._build(look)
	var it := Interactable.create("Hablar con %s (%s)" % [p_name, p_role], func() -> void:
		n.nod()
		n.talked.emit(id), 2.3)
	it.position.y = 1.0
	n.add_child(it)
	return n


static func model_for(id: String, p_name: String, look: Dictionary) -> String:
	if look.has("model"):
		return look["model"]
	for k in ROLE_MODELS:
		if id == k or id.contains("_" + k):
			return ROLE_MODELS[k]
	var female: bool = look.get("long_hair", false)
	if not look.has("long_hair") and p_name != "":
		female = Sound.voice_kind(p_name) == "mujer"
	var pool: Array = WOMEN if female else MEN
	return pool[absi(hash(id)) % pool.size()]


func _build(look: Dictionary) -> void:
	# Colisión para no atravesarlo.
	var body := StaticBody3D.new()
	_body = body
	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.3
	cap.height = 1.7
	col.shape = cap
	col.position.y = 0.85
	body.add_child(col)
	add_child(body)

	_model = Models.spawn("mini-characters/character-" + model_for(npc_id, display_name, look), SCALE)
	add_child(_model)
	_anim = Models.anim_player(_model)
	if _anim:
		for a in ["idle", "walk", "sit"]:
			if _anim.has_animation(a):
				_anim.get_animation(a).loop_mode = Animation.LOOP_LINEAR
		_anim.play("idle")
		_anim.seek(fmod(_seed * 0.37, 2.0), true)
		_anim.speed_scale = 0.9 + fmod(_seed, 7.0) * 0.03

	# Nombre encima.
	if display_name != "":
		var l := Shapes.label(display_name, Vector3(0, 2.15, 0), 32)
		l.pixel_size = 0.005
		l.modulate = Color(1, 0.95, 0.8)
		add_child(l)


## Los que pasean no bloquean al jugador.
func set_solid(value: bool) -> void:
	_body.collision_layer = 1 if value else 0


func _process(delta: float) -> void:
	_t += delta
	if _busy > 0.0:
		_busy -= delta
		return
	_play("walk" if walking else "idle")
	# Parado: se gira hacia el jugador si está cerca.
	var target_yaw := 0.0
	if not walking:
		var player := get_tree().get_first_node_in_group("player") as Node3D
		if player:
			var to := player.global_position - global_position
			if Vector2(to.x, to.z).length() < 5.0:
				var local := global_transform.basis.inverse() * to
				target_yaw = clampf(atan2(-local.x, -local.z), -1.6, 1.6)
	_model.rotation.y = lerp_angle(_model.rotation.y, target_yaw, clampf(delta * 4.0, 0.0, 1.0))


func _play(anim: String) -> void:
	if _anim and _anim.current_animation != anim and _anim.has_animation(anim):
		_anim.play(anim, 0.25)


## Pequeño gesto al empezar a hablar.
func nod() -> void:
	if _anim and _anim.has_animation("emote-yes"):
		_anim.play("emote-yes", 0.15)
		_busy = minf(1.2, _anim.get_animation("emote-yes").length)
