extends Node
## Red del juego. Modelo "anfitrión con autoridad":
## el anfitrión (peer 1) simula perros, adoptantes, dinero y reputación;
## cada jugador mueve su propio personaje y pide acciones al anfitrión.
##
## Hoy usa ENet (IP directa / LAN). Para Steam, solo hay que cambiar
## host()/join() por los lobbies de GodotSteam: el resto del juego no cambia.

const DEFAULT_PORT := 24680
const MAX_PLAYERS := 4

signal session_started
signal session_failed(reason: String)


func _ready() -> void:
	_setup_input()
	multiplayer.connected_to_server.connect(func() -> void: session_started.emit())
	multiplayer.connection_failed.connect(_on_failed.bind("No se pudo conectar con el anfitrión."))
	multiplayer.server_disconnected.connect(_on_failed.bind("El anfitrión ha cerrado la partida."))


func play_solo() -> void:
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	session_started.emit()


func host(port: int = DEFAULT_PORT) -> Error:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(port, MAX_PLAYERS)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = peer
	session_started.emit()
	return OK


func join(address: String, port: int = DEFAULT_PORT) -> Error:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(address, port)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = peer
	return OK


func is_host() -> bool:
	return multiplayer.is_server()


func _on_failed(reason: String) -> void:
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	session_failed.emit(reason)


## Las acciones se crean por código para que el proyecto funcione sin tocar
## el editor. Más adelante se pueden mover a Proyecto > Mapa de entrada.
func _setup_input() -> void:
	var actions := {
		"move_up": [KEY_W, KEY_UP],
		"move_down": [KEY_S, KEY_DOWN],
		"move_left": [KEY_A, KEY_LEFT],
		"move_right": [KEY_D, KEY_RIGHT],
		"interact": [KEY_E, KEY_SPACE],
		"dash": [KEY_SHIFT],
	}
	var pad_buttons := {
		"interact": JOY_BUTTON_A,
		"dash": JOY_BUTTON_B,
	}
	for action: String in actions:
		if not InputMap.has_action(action):
			InputMap.add_action(action, 0.25)
		for key: Key in actions[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = key
			InputMap.action_add_event(action, ev)
		if pad_buttons.has(action):
			var jb := InputEventJoypadButton.new()
			jb.button_index = pad_buttons[action]
			InputMap.action_add_event(action, jb)
	var axes := {
		"move_left": [JOY_AXIS_LEFT_X, -1.0],
		"move_right": [JOY_AXIS_LEFT_X, 1.0],
		"move_up": [JOY_AXIS_LEFT_Y, -1.0],
		"move_down": [JOY_AXIS_LEFT_Y, 1.0],
	}
	for action: String in axes:
		var jm := InputEventJoypadMotion.new()
		jm.axis = axes[action][0]
		jm.axis_value = axes[action][1]
		InputMap.action_add_event(action, jm)
