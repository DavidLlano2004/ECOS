extends Node
## Casos de ventana de la revisión de calidad (necesita ventana real, no sirve con --headless):
##   godot --path . res://tools/pruebas_ventana.tscn
## (e) pantalla completa y volver con un diálogo abierto; (f) cambiar el tamaño de la ventana con un diálogo abierto;
## (g) minimizar y restaurar. Imprime "OK" o "FALLO" por comprobación y "RESULTADO: N de M".

var pasadas := 0
var total := 0


func comprobar(c: bool, nombre: String) -> void:
	total += 1
	if c:
		pasadas += 1
		print("OK     ", nombre)
	else:
		print("FALLO  ", nombre)


func _ready() -> void:
	await get_tree().create_timer(0.5).timeout
	GameState.nueva_partida()
	Dialogo.respuesta_de_prueba = -99
	var mundo: Node = load("res://Scenes/Mundo/Mundo.tscn").instantiate()
	add_child(mundo)
	await get_tree().create_timer(1.0).timeout
	var ventana := get_window()
	var modo_original := ventana.mode
	var tamano_original := ventana.size
	# Se abre un diálogo (sin respuesta automática) con la Guía
	var guia: Node
	for g in get_tree().get_nodes_in_group("guia"):
		if g.is_visible_in_tree():
			guia = g
	guia.interactuar()
	await get_tree().create_timer(1.0).timeout
	comprobar(Dialogo.hay_dialogo(), "hay un diálogo abierto para las pruebas de ventana")
	# (e) Pantalla completa y vuelta con el diálogo abierto
	Opciones.poner_pantalla_completa(true)
	await get_tree().create_timer(1.0).timeout
	comprobar(ventana.mode == Window.MODE_FULLSCREEN or ventana.mode == Window.MODE_EXCLUSIVE_FULLSCREEN, "(e) pasa a pantalla completa")
	comprobar(Dialogo.hay_dialogo() and is_instance_valid(Dialogo.get_child(Dialogo.get_child_count() - 1)), "(e) el diálogo sigue abierto en pantalla completa")
	for i in 4:
		Opciones.poner_pantalla_completa(i % 2 == 1)
		await get_tree().create_timer(0.5).timeout
	Opciones.poner_pantalla_completa(false)
	await get_tree().create_timer(1.0).timeout
	comprobar(ventana.mode == Window.MODE_WINDOWED and Dialogo.hay_dialogo(), "(e) vuelve a ventana con el diálogo todavía abierto")
	# (f) Cambiar el tamaño de la ventana con el diálogo abierto
	for tam in [Vector2i(960, 540), Vector2i(1500, 700), Vector2i(700, 700), tamano_original]:
		ventana.size = tam
		await get_tree().create_timer(0.4).timeout
	comprobar(Dialogo.hay_dialogo() and ventana.size == tamano_original, "(f) cambiar de tamaño varias veces no rompe el diálogo")
	var balloon: Node
	for h in Dialogo.get_children():
		if h is DialogoBalloon:
			balloon = h
	var rect_ok := balloon != null
	if balloon != null:
		for c in balloon.find_children("*", "Control", true, false):
			if c.visible and (c.size.x < 0.0 or c.size.y < 0.0):
				rect_ok = false
	comprobar(rect_ok, "(f) los controles del diálogo mantienen tamaños válidos")
	# (g) Minimizar y restaurar
	var cuadros_antes := Engine.get_frames_drawn()
	ventana.mode = Window.MODE_MINIMIZED
	await get_tree().create_timer(1.0).timeout
	ventana.mode = Window.MODE_WINDOWED
	await get_tree().create_timer(1.0).timeout
	comprobar(Engine.get_frames_drawn() > cuadros_antes + 10 and Dialogo.hay_dialogo() and not get_tree().paused, "(g) minimizar y restaurar: el juego sigue y el diálogo también")
	for h in Dialogo.get_children():
		if h is DialogoBalloon:
			h._cancelar()
	await get_tree().create_timer(4.0).timeout   # la criatura/Guía se despide antes de soltar al jugador
	comprobar(not Dialogo.hay_dialogo(), "se puede cerrar el diálogo después de todo")
	ventana.mode = modo_original
	print("RESULTADO: %d de %d comprobaciones pasaron" % [pasadas, total])
	get_tree().quit(0 if pasadas == total else 1)
