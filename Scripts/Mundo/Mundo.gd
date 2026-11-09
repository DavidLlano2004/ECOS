@tool
class_name Mundo
extends Node2D
## El mundo de ECOS: un mismo mapa en dos épocas (Pasado cálido y Presente apagado).
##
## El diseño está en Resources/Mundo/mapa.txt (un carácter por tile, ver la leyenda al inicio del archivo).
## Este script lo vuelca a las capas de cada época. Gracias a @tool también se ve en el editor:
## abre la escena, o pulsa el botón "Reconstruir mapa" del inspector después de editar mapa.txt.
##
## Cada época tiene las capas (de abajo hacia arriba): Suelo, Orilla (arena), Camino, Agua, Colision,
## y un nodo Objetos (y-sort) con la capa Detalles (rocas, acantilados, muros, puentes) y el jugador.
## Al guardar la escena en el editor las capas se vacían para no inflar el archivo; se vuelven a
## construir solas al abrirla.

const RUTA_MAPA := "res://Resources/Mundo/mapa.txt"
const TAMANO_TILE := 32
const TILES := Vector2i(96, 54)
## Límites de la cámara (todo el mapa, en píxeles).
const LIMITES := Rect2(Vector2.ZERO, Vector2(TILES.x * TAMANO_TILE, TILES.y * TAMANO_TILE))

# Conjuntos de terrenos del TileSet (ver tools/construir_tileset.gd)
const TERRENO_CAMINO := 0
const TERRENO_ARENA := 1
const TERRENO_AGUA := 2

## Caracteres que son agua (el puente va sobre agua).
const AGUA := "wPqQ"

@export_tool_button("Reconstruir mapa", "Reload") var _boton_reconstruir: Callable = construir_mapa

var _epoca_actual := "pasado"


func _ready() -> void:
	construir_mapa()
	if Engine.is_editor_hint():
		return
	GameState.epoca_cambiada.connect(mostrar_epoca)
	var jugador := _jugador()
	if jugador != null:
		jugador.global_position = posicion_zona("Hub")
		jugador.establecer_limites(LIMITES)  # el mundo es quien define hasta dónde puede ver la cámara
	mostrar_epoca(GameState.epoca)


func _unhandled_input(evento: InputEvent) -> void:
	# Solo en compilaciones de depuración: F2 cambia de época para comparar las dos versiones
	if Engine.is_editor_hint() or not OS.is_debug_build():
		return
	if evento is InputEventKey and evento.pressed and not evento.echo and evento.keycode == KEY_F2:
		GameState.cambiar_epoca()


func _notification(que: int) -> void:
	if not Engine.is_editor_hint():
		return
	# Al guardar en el editor se vacían las capas (el mapa vive en mapa.txt) y luego se reconstruyen
	if que == NOTIFICATION_EDITOR_PRE_SAVE:
		_vaciar_capas()
	elif que == NOTIFICATION_EDITOR_POST_SAVE:
		construir_mapa()


# --- Zonas y época ---

## Posición (en píxeles) del marcador de una zona: "Hub", "Rabia", "Miedo", "Tristeza", "Soledad",
## "Culpa", "Ansiedad", "Verguenza" o "Final".
func posicion_zona(nombre: String) -> Vector2:
	var marcador := get_node_or_null("Marcadores/%s" % ("Spawn_Hub" if nombre == "Hub" else "Zona_" + nombre)) as Marker2D
	if marcador == null:
		push_warning("Mundo: no existe el marcador de la zona '%s'." % nombre)
		return Vector2.ZERO
	return marcador.global_position


## Muestra una época ("pasado" o "presente"). Las dos tienen la misma forma y la misma posición,
## así que el jugador solo se pasa a la capa de objetos de la época activa.
func mostrar_epoca(epoca: String) -> void:
	_epoca_actual = epoca
	var es_pasado := epoca == "pasado"
	var pasado := $Pasado as Node2D
	var presente := $Presente as Node2D
	pasado.visible = es_pasado
	presente.visible = not es_pasado
	_activar_colisiones(pasado, es_pasado)
	_activar_colisiones(presente, not es_pasado)
	var jugador := _jugador()
	if jugador != null:
		var destino: Node = (pasado if es_pasado else presente).get_node("Objetos")
		if jugador.get_parent() != destino:
			jugador.reparent(destino, true)  # conserva su posición


func _activar_colisiones(nodo: Node, activo: bool) -> void:
	for hijo in nodo.get_children():
		if hijo is TileMapLayer:
			hijo.collision_enabled = activo
		_activar_colisiones(hijo, activo)


func _jugador() -> Node2D:
	if Engine.is_editor_hint():
		return null
	return get_tree().get_first_node_in_group("player") as Node2D


# --- Decoración ---

## Marcadores de un grupo de decoración: "arboles", "rocas", "faroles", "bancos", "arcos" o "espejos".
func marcadores_de(grupo: String) -> Array[Marker2D]:
	var lista: Array[Marker2D] = []
	var decoracion := get_node_or_null("Decoracion")
	if decoracion == null:
		return lista
	for marcador in decoracion.find_children("*", "Marker2D", true, false):
		if marcador.is_in_group(grupo):
			lista.append(marcador)
	return lista


## Coloca la decoración sobre los marcadores cuando ya existan los sprites.
## Cada diccionario relaciona un grupo con una PackedScene o con una Texture2D:
##   colocar_decoracion({"arboles": preload("res://.../arbol_pasado.png"), "rocas": preload(...)},
##                      {"arboles": preload("res://.../arbol_presente.png")})
## Si no se da el diccionario del Presente se usa el del Pasado. Las texturas se apoyan en el
## marcador por la base (los pies del objeto). Devuelve cuántos objetos se colocaron.
func colocar_decoracion(del_pasado: Dictionary, del_presente: Dictionary = {}) -> int:
	var total := 0
	var catalogos := {"Pasado": del_pasado, "Presente": del_presente if not del_presente.is_empty() else del_pasado}
	for epoca in catalogos:
		var objetos := get_node("%s/Objetos" % epoca)
		var catalogo: Dictionary = catalogos[epoca]
		for grupo in catalogo:
			for marcador in marcadores_de(grupo):
				var objeto := _crear_objeto(catalogo[grupo])
				if objeto == null:
					continue
				objeto.name = "%s_%s" % [marcador.name, epoca]
				objetos.add_child(objeto)
				objeto.global_position = marcador.global_position
				total += 1
	return total


func _crear_objeto(origen: Variant) -> Node2D:
	if origen is PackedScene:
		return origen.instantiate() as Node2D
	if origen is Texture2D:
		var sprite := Sprite2D.new()
		sprite.texture = origen
		sprite.offset = Vector2(0, -origen.get_height() / 2.0)  # apoyado por la base
		return sprite
	push_warning("Mundo: la decoración debe ser una PackedScene o una Texture2D.")
	return null


# --- Constructor del mapa ---

## Lee mapa.txt y lo vuelca a las capas de las dos épocas.
func construir_mapa() -> void:
	var filas := _leer_mapa()
	if filas.is_empty():
		return
	var pasado := get_node_or_null("Pasado")
	var presente := get_node_or_null("Presente")
	# Los terrenos eligen al azar entre las variantes de una pieza: se fija la semilla para que
	# el mapa sea siempre igual, y luego se vuelve a aleatorizar para el resto del juego
	seed(20240901)
	if pasado != null:
		_construir_epoca(pasado, filas, null)
	randomize()
	# El Presente copia los terrenos ya elegidos del Pasado: misma forma, mismos tiles, otra paleta
	if presente != null:
		_construir_epoca(presente, filas, pasado)


func _leer_mapa() -> PackedStringArray:
	var filas := PackedStringArray()
	if not FileAccess.file_exists(RUTA_MAPA):
		push_error("Mundo: no existe %s" % RUTA_MAPA)
		return filas
	for linea in FileAccess.get_file_as_string(RUTA_MAPA).split("\n"):
		var texto := linea.strip_edges(false, true)
		if texto == "" or texto.begins_with(";"):
			continue
		filas.append(texto)
	if filas.size() != TILES.y:
		push_error("Mundo: el mapa tiene %d filas y debería tener %d." % [filas.size(), TILES.y])
		return PackedStringArray()
	for i in filas.size():
		if filas[i].length() != TILES.x:
			push_error("Mundo: la fila %d mide %d y debería medir %d." % [i, filas[i].length(), TILES.x])
			return PackedStringArray()
	return filas


func _vaciar_capas() -> void:
	for epoca in ["Pasado", "Presente"]:
		var nodo := get_node_or_null(epoca)
		if nodo == null:
			continue
		for capa in _capas_de(nodo):
			capa.clear()


func _capas_de(epoca: Node) -> Array[TileMapLayer]:
	var capas: Array[TileMapLayer] = []
	for ruta in ["Suelo", "Orilla", "Camino", "Agua", "Colision", "Objetos/Detalles"]:
		var capa := epoca.get_node_or_null(ruta) as TileMapLayer
		if capa != null:
			capas.append(capa)
	return capas


func _construir_epoca(epoca: Node, filas: PackedStringArray, referencia: Node) -> void:
	var suelo := epoca.get_node("Suelo") as TileMapLayer
	var orilla := epoca.get_node("Orilla") as TileMapLayer
	var camino := epoca.get_node("Camino") as TileMapLayer
	var agua := epoca.get_node("Agua") as TileMapLayer
	var colision := epoca.get_node("Colision") as TileMapLayer
	var detalles := epoca.get_node("Objetos/Detalles") as TileMapLayer
	var tiles := _buscar_tiles(suelo.tile_set)
	for capa in _capas_de(epoca):
		capa.clear()

	var celdas_camino: Array[Vector2i] = []
	var celdas_arena: Array[Vector2i] = []
	var celdas_agua: Array[Vector2i] = []

	for y in TILES.y:
		for x in TILES.x:
			var c := Vector2i(x, y)
			var ch := filas[y][x]
			suelo.set_cell(c, 0, tiles[_nombre_suelo(_suelo_de(filas, x, y), x, y)])
			if ch == "c":
				celdas_camino.append(c)
			if AGUA.contains(ch):
				celdas_agua.append(c)
			if ch == "s" or AGUA.contains(ch):
				celdas_arena.append(c)  # la arena va debajo del agua, así la orilla se ve natural
			match ch:
				"R":
					detalles.set_cell(c, 0, tiles["roca"])
				"C":
					var hay_cara := y + 1 >= TILES.y or filas[y + 1][x] != "C"
					detalles.set_cell(c, 0, tiles["acantilado_%s_%d" % ["cara" if hay_cara else "cima", _variante(x, y, 2)]])
				"M":
					# remate solo en la primera pieza de cada tramo (si arriba hay muro, va el cuerpo sin remate)
					var con_remate := y == 0 or filas[y - 1][x] != "M"
					detalles.set_cell(c, 0, tiles["%s_%d" % ["muro_piedra" if con_remate else "muro_cuerpo", _variante(x, y, 2)]])
				"P":
					detalles.set_cell(c, 0, tiles["puente_h"])
				"q":
					detalles.set_cell(c, 0, tiles["puente_roto_izq"])
				"Q":
					detalles.set_cell(c, 0, tiles["puente_roto_der"])
				"X":
					colision.set_cell(c, 0, tiles["colision"])
				"w":
					if _es_agua_profunda(filas, x, y):
						colision.set_cell(c, 0, tiles["colision_agua_profunda"])

	# Un anillo de bloques invisibles fuera del mapa: el jugador nunca puede salir
	for x in range(-1, TILES.x + 1):
		colision.set_cell(Vector2i(x, -1), 0, tiles["colision"])
		colision.set_cell(Vector2i(x, TILES.y), 0, tiles["colision"])
	for y in range(0, TILES.y):
		colision.set_cell(Vector2i(-1, y), 0, tiles["colision"])
		colision.set_cell(Vector2i(TILES.x, y), 0, tiles["colision"])

	# Terrenos: Godot elige solo las piezas de transición según los vecinos (o se copian de la época de referencia)
	if referencia != null:
		for nombre_capa in ["Orilla", "Camino", "Agua"]:
			var origen := referencia.get_node(nombre_capa) as TileMapLayer
			var destino := epoca.get_node(nombre_capa) as TileMapLayer
			for c in origen.get_used_cells():
				destino.set_cell(c, 0, origen.get_cell_atlas_coords(c))
		return
	orilla.set_cells_terrain_connect(celdas_arena, TERRENO_ARENA, 0)
	camino.set_cells_terrain_connect(celdas_camino, TERRENO_CAMINO, 0)
	agua.set_cells_terrain_connect(celdas_agua, TERRENO_AGUA, 0)


## Agua profunda: una celda de agua con las 8 vecinas también de agua (ahí hay colisión).
## Los bordes quedan poco profundos y se pueden pisar; así los ríos se cruzan por el vado.
func _es_agua_profunda(filas: PackedStringArray, x: int, y: int) -> bool:
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var nx := x + dx
			var ny := y + dy
			if nx < 0 or ny < 0 or nx >= TILES.x or ny >= TILES.y:
				continue
			if not AGUA.contains(filas[ny][nx]):
				return false
	return true


func _nombre_suelo(ch: String, x: int, y: int) -> String:
	match ch:
		"f":
			return "hierba_flores_%d" % _variante(x, y, 2)
		"d":
			return "pasto_seco_%d" % _variante(x, y, 2)
		"r":
			return "tierra_roja_%d" % _variante(x, y, 2)
		"v":
			return "volcanico_%d" % _variante(x, y, 2)
		"b":
			return "bosque_%d" % _variante(x, y, 2)
		"u":
			return "ruinas_%d" % _variante(x, y, 2)
		"a":
			return "adoquines_%d" % _variante(x, y, 2)
	return "hierba_%d" % _variante(x, y, 4)  # el resto de casillas llevan hierba debajo


## Variante "al azar" pero siempre la misma para la misma casilla (así el mapa no cambia entre ejecuciones).
func _variante(x: int, y: int, cuantas: int) -> int:
	return int(absi((x * 73856093) ^ (y * 19349663)) / 7) % cuantas


## nombre del tile -> coordenadas en el atlas (usa el dato personalizado "nombre" del TileSet).
func _buscar_tiles(tileset: TileSet) -> Dictionary:
	var resultado := {}
	var fuente := tileset.get_source(0) as TileSetAtlasSource
	for i in fuente.get_tiles_count():
		var coords := fuente.get_tile_id(i)
		var nombre := str(fuente.get_tile_data(coords, 0).get_custom_data("nombre"))
		if nombre != "":
			resultado[nombre] = coords
	return resultado


## Qué suelo hay en una casilla. Las casillas con obstáculos, caminos o agua no guardan su suelo en
## el mapa, así que se toma el más común entre sus vecinas (una roca sobre tierra roja lleva tierra roja debajo).
func _suelo_de(filas: PackedStringArray, x: int, y: int) -> String:
	var ch := filas[y][x]
	if not "RCMX".contains(ch):
		return ch if "fdrvbua.".contains(ch) else "."  # arena, camino y agua llevan hierba debajo
	var votos := {}
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var nx := x + dx
			var ny := y + dy
			if nx < 0 or ny < 0 or nx >= TILES.x or ny >= TILES.y:
				continue
			var vecino := filas[ny][nx]
			if "fdrvbua".contains(vecino):
				votos[vecino] = votos.get(vecino, 0) + 1
	var mejor := "."
	var mejor_votos := 0
	for clave in votos:
		if votos[clave] > mejor_votos:
			mejor = clave
			mejor_votos = votos[clave]
	return mejor
