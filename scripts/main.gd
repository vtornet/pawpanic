extends Node
## Punto de entrada: crea el mundo y la interfaz.
##
## Argumentos opcionales tras "--":
##   --smoke          prueba automática de la simulación y cierra
##   --tutorial-test  juega el tutorial completo y cierra
##   --balance        simula un año con varios estilos de juego (solo lógica) y muestra resultados
##   --quit-after=N   cierra tras N segundos

var world: World
var ui: GameUI


func _ready() -> void:
	# El simulador de equilibrio solo necesita la lógica (Game), sin mundo ni interfaz.
	if "--balance" in OS.get_cmdline_user_args():
		var bs: Node = load("res://tests/balance_sim.gd").new()
		add_child(bs)
		bs.run.call_deferred(null, null)
		return
	world = World.new()
	world.name = "World"
	add_child(world)
	ui = GameUI.new()
	ui.name = "UI"
	ui.world = world
	add_child(ui)

	for arg in OS.get_cmdline_user_args():
		if arg == "--smoke":
			var script: GDScript = load("res://tests/smoke_test.gd")
			if script == null or not script.can_instantiate():
				printerr("SMOKE FAIL: la prueba no compila")
				get_tree().quit(1)
				return
			var test: Node = script.new()
			add_child(test)
			test.run.call_deferred(world, ui)
		elif arg == "--tutorial-test":
			var tt: Node = load("res://tests/tutorial_test.gd").new()
			add_child(tt)
			tt.run.call_deferred(world, ui)
		elif arg.begins_with("--quit-after="):
			get_tree().create_timer(float(arg.get_slice("=", 1))).timeout.connect(get_tree().quit)
