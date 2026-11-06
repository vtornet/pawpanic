extends Node
## Capturas de pantalla automáticas de varias zonas del juego, para revisar los gráficos.
## Uso (necesita pantalla; en Linux sin pantalla, con xvfb-run):
##   godot --rendering-driver opengl3 -- --shots=/ruta/carpeta


func run(world: World, ui: GameUI, out_dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(out_dir)
	Game.rng.seed = 99
	Game.register("Huellas de Isla")
	Game.take_loan("grande")
	Game.buy_start_land("parcela_camino")
	Game.build_starter()
	Tutorial.skip()
	Game.s["money"] = 900000
	for id in ["mediana", "grande"]:
		Game.buy_land_upgrade(id)
	for b in ["caniles", "gatera", "patio", "cuarentena", "consulta", "limpieza", "conejera"]:
		Game.build(b)
	for sp in ["perro", "perro", "perro", "perro", "gato", "gato", "perro", "conejo", "perro"]:
		var a := Game._make_animal({"species": sp})
		a["location"] = "refugio"
		Game.s["animals"].append(a)
	Game.hire("voluntario")
	Game.s["minute"] = 11 * 60
	Game.changed.emit()
	Game.world_changed.emit()
	ui.close_panel()
	await _frames(10)
	var base: Vector3 = Game.s["land_pos"]
	var shots := [
		["01_plaza", Vector3(0, 0, 22), 0.0, -4.0, false],
		["02_calle_clinica", Vector3(12, 0, -8), 120.0, -6.0, false],
		["03_refugio_entrada", base + Vector3(0, 0, -24), 180.0, -8.0, false],
		["04_caseta_dentro", base + World.HOUSE_POS + Vector3(0, 0, -1.5), 180.0, -18.0, false],
		["05_clinica_dentro", World.PLACES["clinica"]["pos"] + Vector3(-3, 0, 0), -90.0, -8.0, false],
		["06_tercera_persona", Vector3(-3, 0, 14), 200.0, -12.0, true],
		["07_tienda_dentro", World.PLACES["tienda"]["pos"] + Vector3(-4, 0, -2), -100.0, -10.0, false],
		["07b_ayuntamiento_dentro", World.PLACES["ayuntamiento"]["pos"] + Vector3(4.5, 0, 0), 90.0, -8.0, false],
		["07c_peluqueria_dentro", World.PLACES["peluqueria"]["pos"] + Vector3(3, 0, 0), 90.0, -12.0, false],
		["07d_fachada_clinica", World.PLACES["clinica"]["pos"] + Vector3(-14, 0, 4), -75.0, -2.0, false],
	]
	for s in shots:
		world.player.set_view(s[1], s[2], s[3], s[4])
		await _frames(12)
		_save(out_dir.path_join(s[0] + ".png"))
	# Galería de animales.
	var lineup := Node3D.new()
	world.add_child(lineup)
	var x := 0.0
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var list := []
	for size in ["pequeño", "mediano", "grande"]:
		for i in 6:
			list.append({"species": "perro", "size": size})
	for i in 5:
		list.append({"species": "gato"})
	for sp in ["conejo", "cabra", "burro", "caballo", "erizo", "ave", "tortuga"]:
		list.append({"species": sp})
	var col := 0
	var row := 0
	for opts in list:
		Game.rng.seed = rng.randi()
		var a := Game._make_animal(opts)
		a["injured"] = false
		a["species"] = opts["species"]
		if opts.has("size"):
			a["size"] = opts["size"]
		var n := AnimalMesh.build(a)
		lineup.add_child(n)
		n.global_position = Vector3(120 + col * 2.0, 0.05, -150 - row * 2.6)
		n.rotation.y = deg_to_rad(-35)
		col += 1
		if col >= 12:
			col = 0
			row += 1
	x = 22.0
	world.player.set_view(Vector3(131, 1.5, -144.5), 0.0, -16.0, false)
	await _frames(12)
	_save(out_dir.path_join("08_animales.png"))
	# Noche.
	Game.s["minute"] = 20 * 60 + 40
	world.player.set_view(Vector3(0, 0, 22), 0.0, -4.0, false)
	await _frames(40)
	_save(out_dir.path_join("09_noche.png"))
	print("SHOTS DONE")
	get_tree().quit()


func _save(path: String) -> void:
	get_viewport().get_texture().get_image().save_png(path)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame
