extends Node
## Punto de entrada: crea el mundo y la interfaz.
##
## Argumentos opcionales tras "--":
##   --smoke          prueba automática de la simulación y cierra
##   --quit-after=N   cierra tras N segundos

var world: World
var ui: GameUI


func _ready() -> void:
	world = World.new()
	world.name = "World"
	add_child(world)
	ui = GameUI.new()
	ui.name = "UI"
	ui.world = world
	add_child(ui)

	for arg in OS.get_cmdline_user_args():
		if arg == "--smoke":
			var test: Node = load("res://tests/smoke_test.gd").new()
			add_child(test)
			test.run.call_deferred(world, ui)
		elif arg.begins_with("--quit-after="):
			get_tree().create_timer(float(arg.get_slice("=", 1))).timeout.connect(get_tree().quit)
