extends Node
## Genera tools/preview_mapa_pasado.png y tools/preview_mapa_presente.png: el mapa completo
## (3072x1728) dibujado con los tiles, los props, la decoración y la luz del juego (sin viñeta
## ni jugador), para revisarlo sin abrir el juego.
##
## Uso (hace falta ventana, no vale --headless):
##   godot --path . res://tools/preview_mapa.tscn
## Regenéralas cada vez que cambies mapa.txt, el tileset o la decoración.

const ESCENA_MUNDO := "res://Scenes/Mundo/Mundo.tscn"


func _ready() -> void:
	for epoca in ["pasado", "presente"]:
		await _sacar_foto(epoca)
	get_tree().quit()


func _sacar_foto(epoca: String) -> void:
	var vista := SubViewport.new()
	vista.size = Vector2i(3072, 1728)
	vista.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vista)
	var mundo := (load(ESCENA_MUNDO) as PackedScene).instantiate()
	var jugador := mundo.get_node_or_null("Pasado/Objetos/Jugador")
	if jugador != null:
		jugador.free()  # sin jugador ni cámara
	vista.add_child(mundo)
	mundo.mostrar_epoca(epoca)
	var vineta := mundo.get_node_or_null("Vineta")
	if vineta != null:
		vineta.queue_free()
	for _i in 6:
		await get_tree().process_frame
	var imagen := vista.get_texture().get_image()
	var ruta := ProjectSettings.globalize_path("res://tools/preview_mapa_%s.png" % epoca)
	imagen.save_png(ruta)
	print("Vista previa: ", ruta)
	vista.queue_free()
	await get_tree().process_frame
