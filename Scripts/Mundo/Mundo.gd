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
const TERRENO_TONO_OSCURO := 3
const TERRENO_TONO_CLARO := 4

const PROP := preload("res://Scenes/Objetos/Prop.tscn")
## Decoración suelta de 16x16 (matas, flores, piedritas y hojas) de cada época.
const DETALLES := {
	"Pasado": preload("res://Resources/Mundo/detalles_pasado.tres"),
	"Presente": preload("res://Resources/Mundo/detalles_presente.tres"),
}
const TEXTURA_LUZ := preload("res://Resources/Mundo/luz_calida.tres")
const VINETA := preload("res://Shaders/vineta.gdshader")
const TRANSICION := preload("res://Shaders/transicion_epoca.gdshader")
const SATURACION := preload("res://Shaders/saturacion.gdshader")
const PORTAL := preload("res://Scenes/Objetos/Portal.tscn")
const GUIA := preload("res://Scenes/Personajes/Guia.tscn")
const BLOQUEO := preload("res://Scenes/Objetos/BloqueoPresente.tscn")
const PUERTA_REFLEJO := preload("res://Scenes/Objetos/PuertaReflejo.tscn")
## Zonas con emoción: en la entrada de cada una hay una grieta, y su criatura vive en el Pasado.
const ZONAS_EMOCION := ["Rabia", "Miedo", "Tristeza", "Soledad", "Culpa", "Ansiedad", "Verguenza"]
## Saturación del Presente: 0.25 sin ninguna emoción integrada, 1.0 con todas.
const SATURACION_MINIMA := 0.25
## Color del ambiente: atardecer cálido en el Pasado y frío en el Presente (CanvasModulate).
const COLOR_PASADO := Color(1.0, 0.87, 0.72)
const COLOR_PRESENTE := Color(0.74, 0.83, 1.0)
## A este color tiende el ambiente del Presente cuando se integran todas las emociones.
const COLOR_PRESENTE_VIVO := Color(0.9, 0.93, 1.0)
## Casillas que no son suelo libre: no llevan sombra debajo y no se les pone decoración encima.
const OCUPADAS := "CMRXTwPqQ"

## Caracteres que son agua (el puente va sobre agua).
const AGUA := "wPqQ"

@export_tool_button("Reconstruir mapa", "Reload") var _boton_reconstruir: Callable = reconstruir_todo

var _epoca_actual := "pasado"
var _puestos: Array[Dictionary] = []   # props colocados (los usa la decoración suelta)
var _ruido_hierba := FastNoiseLite.new()
var _modulador: CanvasModulate
var _viajando := false
var _rect_transicion: ColorRect
var _material_presente := ShaderMaterial.new()
var _saturacion := SATURACION_MINIMA
var _tween_saturacion: Tween


func _ready() -> void:
	reconstruir_todo()
	if Engine.is_editor_hint():
		return
	GameState.epoca_cambiada.connect(mostrar_epoca)
	var jugador := _jugador()
	if jugador != null:
		jugador.global_position = posicion_zona("Hub") + Vector2(0, 56)  # delante del portal
		jugador.establecer_limites(LIMITES)  # el mundo es quien define hasta dónde puede ver la cámara
	GameState.emocion_resuelta.connect(func(_id: String, _resultado: String) -> void: _actualizar_saturacion(true))
	_actualizar_saturacion(false)
	mostrar_epoca(GameState.epoca)


## Reconstruye todo lo que se genera por código: mapa, props, decoración suelta, ambiente,
## portales, Guía y criaturas.
func reconstruir_todo() -> void:
	construir_mapa()
	colocar_props()
	construir_detalles()
	colocar_entidades()
	_crear_ambiente()
	_crear_particulas()
	_preparar_saturacion()
	_aplicar_ambiente(_epoca_actual == "pasado", false)
	if not Engine.is_editor_hint():
		mostrar_epoca(_epoca_actual)  # deja cada época con su visibilidad, proceso y física


func _unhandled_input(evento: InputEvent) -> void:
	# Solo en compilaciones de depuración: F2 cambia de época para comparar las dos versiones
	if Engine.is_editor_hint() or not OS.is_debug_build():
		return
	if evento is InputEventKey and evento.pressed and not evento.echo and evento.keycode == KEY_F2:
		viajar()


func _process(_delta: float) -> void:
	# Las partículas del ambiente siguen al jugador (la lluvia de luciérnagas o ceniza llena la pantalla)
	var jugador := _jugador()
	if jugador == null:
		return
	var particulas := get_node_or_null("%s/Particulas" % ("Pasado" if _epoca_actual == "pasado" else "Presente")) as CPUParticles2D
	if particulas != null:
		particulas.global_position = jugador.global_position + (Vector2(0, -30) if _epoca_actual == "pasado" else Vector2(0, -230))


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


## Muestra una época ("pasado" o "presente"). Las dos tienen la misma forma y la misma posición.
## La época contraria se oculta y se desactiva del todo (visible = false, proceso apagado, colisiones
## apagadas); el jugador se pasa a la época activa conservando su posición.
func mostrar_epoca(epoca: String) -> void:
	_epoca_actual = epoca
	var es_pasado := epoca == "pasado"
	var pasado := $Pasado as Node2D
	var presente := $Presente as Node2D
	var jugador := _jugador()
	if jugador != null:
		var destino: Node = (pasado if es_pasado else presente).get_node("Objetos")
		if jugador.get_parent() != destino:
			jugador.reparent(destino, true)  # conserva su posición
	_activar_epoca(pasado, es_pasado)
	_activar_epoca(presente, not es_pasado)
	_aplicar_ambiente(es_pasado, true)


func _activar_epoca(nodo: Node2D, activa: bool) -> void:
	nodo.visible = activa
	nodo.process_mode = Node.PROCESS_MODE_INHERIT if activa else Node.PROCESS_MODE_DISABLED
	_activar_colisiones(nodo, activa)
	_activar_fisica(nodo, activa)


func _activar_colisiones(nodo: Node, activo: bool) -> void:
	for hijo in nodo.get_children():
		if hijo is TileMapLayer:
			hijo.collision_enabled = activo
		_activar_colisiones(hijo, activo)


## Enciende o apaga las formas de colisión de props, portales, criaturas... (menos las del jugador).
## Así nada de la época oculta se puede tocar ni interactuar. Recuerda si la forma ya estaba apagada.
func _activar_fisica(nodo: Node, activo: bool) -> void:
	for hijo in nodo.get_children():
		if hijo.is_in_group("player"):
			continue
		if hijo is CollisionShape2D or hijo is CollisionPolygon2D:
			if not hijo.has_meta("ecos_apagada"):
				hijo.set_meta("ecos_apagada", hijo.disabled)
			hijo.set_deferred("disabled", (not activo) or hijo.get_meta("ecos_apagada"))
		_activar_fisica(hijo, activo)


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


## Coloca los decorados (Prop) en las dos épocas, siempre en las mismas posiciones.
## Usa los marcadores del grupo y añade más según el tema de cada zona (ver Decorador.gd).
## Los props se crean al arrancar y no se guardan en la escena; si ya había, se reemplazan.
## Devuelve cuántos puso en cada época.
func colocar_props() -> int:
	var filas := _leer_mapa()
	if filas.is_empty():
		return 0
	var zonas := {}
	for nombre in ["Hub", "Rabia", "Miedo", "Tristeza", "Soledad", "Culpa", "Ansiedad", "Verguenza", "Final"]:
		zonas[nombre] = posicion_zona(nombre)
	var marcadores := {}
	for grupo in ["arboles", "rocas", "faroles", "bancos"]:
		var posiciones: Array[Vector2] = []
		for marcador in marcadores_de(grupo):
			posiciones.append(to_local(marcador.global_position))
		marcadores[grupo] = posiciones
	var puestos := Decorador.generar(filas, zonas, marcadores)
	_puestos = puestos
	for epoca in ["Pasado", "Presente"]:
		var objetos := get_node_or_null("%s/Objetos" % epoca)
		if objetos == null:
			continue
		for viejo in objetos.get_children():
			if viejo is Prop:
				viejo.free()
		for puesto in puestos:
			var prop := PROP.instantiate() as Prop
			prop.tipo = puesto["tipo"]
			prop.con_colision = not puesto.get("borde", false)
			prop.name = "%s_%d" % [puesto["tipo"], objetos.get_child_count()]
			prop.position = puesto["pos"]
			objetos.add_child(prop)
	return puestos.size()


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
	_preparar_ruido_hierba()
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
	for ruta in ["Suelo", "TonoOscuro", "TonoClaro", "Orilla", "Camino", "Agua", "Sombras", "Colision", "Objetos/Detalles"]:
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
	var sombras := _capa_extra(epoca, "Sombras", suelo.tile_set, "Colision")
	# Manchas de hierba más oscura y más clara: capas translúcidas con bordes tramados (justo sobre el suelo)
	var tono_oscuro := _capa_extra(epoca, "TonoOscuro", suelo.tile_set, "Orilla")
	var tono_claro := _capa_extra(epoca, "TonoClaro", suelo.tile_set, "Orilla")
	var celdas_oscuras: Array[Vector2i] = []
	var celdas_claras: Array[Vector2i] = []
	for capa in _capas_de(epoca):
		capa.clear()

	var celdas_camino: Array[Vector2i] = []
	var celdas_arena: Array[Vector2i] = []
	var celdas_agua: Array[Vector2i] = []

	for y in TILES.y:
		for x in TILES.x:
			var c := Vector2i(x, y)
			var ch := filas[y][x]
			var suelo_aqui := _suelo_de(filas, x, y)
			suelo.set_cell(c, 0, tiles[_nombre_suelo(suelo_aqui, x, y)])
			if suelo_aqui == "." or suelo_aqui == "f":
				var tono := _ruido_hierba.get_noise_2d(x, y)
				if tono < -0.2:
					celdas_oscuras.append(c)
				elif tono > 0.28:
					celdas_claras.append(c)
			if ch == "c":
				celdas_camino.append(c)
			if AGUA.contains(ch):
				celdas_agua.append(c)
			if ch == "s" or AGUA.contains(ch):
				celdas_arena.append(c)  # la arena va debajo del agua, así la orilla se ve natural
			# Sombra suave de 2 px en el suelo justo debajo de muros y acantilados
			if (ch == "C" or ch == "M") and y + 1 < TILES.y and not OCUPADAS.contains(filas[y + 1][x]):
				sombras.set_cell(Vector2i(x, y + 1), 0, tiles["sombra_s"])
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
				"X", "T":
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
		for nombre_capa in ["TonoOscuro", "TonoClaro", "Orilla", "Camino", "Agua"]:
			var origen := referencia.get_node(nombre_capa) as TileMapLayer
			var destino := epoca.get_node(nombre_capa) as TileMapLayer
			for c in origen.get_used_cells():
				destino.set_cell(c, 0, origen.get_cell_atlas_coords(c))
		return
	tono_oscuro.set_cells_terrain_connect(celdas_oscuras, TERRENO_TONO_OSCURO, 0)
	tono_claro.set_cells_terrain_connect(celdas_claras, TERRENO_TONO_CLARO, 0)
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
	# El resto de casillas llevan hierba debajo (las manchas de tono van en las capas TonoOscuro y TonoClaro)
	return "hierba_%d" % _variante(x, y, 4)


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
	if not "RCMXT".contains(ch):
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


# --- Variación de la hierba, decoración suelta y ambiente ---

## Ruido de baja frecuencia: reparte zonas de hierba más clara y más oscura (siempre las mismas).
func _preparar_ruido_hierba() -> void:
	_ruido_hierba.seed = 7
	_ruido_hierba.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_ruido_hierba.frequency = 0.04


## Devuelve la capa hija `nombre` de `padre`; si no existe la crea (sin dueño, así no se guarda en la
## escena) y la deja justo antes del nodo `antes_de`.
func _capa_extra(padre: Node, nombre: String, tileset: TileSet, antes_de: String) -> TileMapLayer:
	var capa := padre.get_node_or_null(nombre) as TileMapLayer
	if capa == null:
		capa = TileMapLayer.new()
		capa.name = nombre
		capa.tile_set = tileset
		padre.add_child(capa)
		var referencia := padre.get_node_or_null(antes_de)
		if referencia != null:
			padre.move_child(capa, referencia.get_index())
	return capa


## Reparte matas de hierba, flores, piedritas y hojas (16x16) con ruido sobre la hierba:
## más densas cerca de árboles y bordes, y nunca sobre caminos, agua ni arena.
## Las dos épocas llevan los mismos detalles en los mismos sitios (en el Presente son hojas secas y colores apagados).
func construir_detalles() -> void:
	var filas := _leer_mapa()
	if filas.is_empty():
		return
	var cerca_arbol := _casillas_cerca_de_arboles(filas)
	var ruido := FastNoiseLite.new()
	ruido.seed = 99
	ruido.frequency = 0.05
	var azar := RandomNumberGenerator.new()
	azar.seed = 5150
	var colocados: Array[Dictionary] = []
	for cy in TILES.y * 2:
		for cx in TILES.x * 2:
			var tx := cx / 2
			var ty := cy / 2
			if not ".fd".contains(filas[ty][tx]):
				continue
			if _toca(filas, tx, ty, "cwPqQs"):
				continue  # junto a caminos, agua o arena no se pone nada
			var densidad := 0.06 + 0.14 * clampf((ruido.get_noise_2d(cx, cy) + 0.15) / 0.7, 0.0, 1.0)
			var junto_a_arbol := cerca_arbol.has(Vector2i(tx, ty))
			if junto_a_arbol:
				densidad += 0.22
			elif _toca(filas, tx, ty, "CMRT"):
				densidad += 0.10
			if azar.randf() >= densidad:
				continue
			var tirada := azar.randf()
			var grupo := "matas"
			if junto_a_arbol and tirada < 0.40:
				grupo = "hojas"
			elif filas[ty][tx] == "f" and tirada < 0.45:
				grupo = "flores"
			elif tirada > 0.93:
				grupo = "piedras"
			elif tirada > 0.84:
				grupo = "hojas"
			elif tirada > 0.74:
				grupo = "flores"
			colocados.append({"celda": Vector2i(cx, cy), "grupo": grupo, "variante": azar.randi()})
	for epoca in ["Pasado", "Presente"]:
		var nodo := get_node_or_null(epoca)
		if nodo == null:
			continue
		var capa := _capa_extra(nodo, "DetallesSuelo", DETALLES[epoca], "Colision")
		capa.clear()
		var grupos := _grupos_de_detalles(capa.tile_set)
		for d in colocados:
			var lista: Array = grupos[d["grupo"]]
			capa.set_cell(d["celda"], 0, lista[d["variante"] % lista.size()])


## grupo ("matas", "flores", "piedras", "hojas") -> lista de coordenadas del atlas (dato personalizado "grupo").
func _grupos_de_detalles(tileset: TileSet) -> Dictionary:
	var resultado := {}
	var fuente := tileset.get_source(0) as TileSetAtlasSource
	for i in fuente.get_tiles_count():
		var coords := fuente.get_tile_id(i)
		var grupo := str(fuente.get_tile_data(coords, 0).get_custom_data("grupo"))
		if not resultado.has(grupo):
			resultado[grupo] = []
		resultado[grupo].append(coords)
	return resultado


## ¿Alguna casilla vecina (8 direcciones) es de uno de los tipos de `letras`?
func _toca(filas: PackedStringArray, x: int, y: int, letras: String) -> bool:
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var nx := x + dx
			var ny := y + dy
			if nx < 0 or ny < 0 or nx >= TILES.x or ny >= TILES.y:
				continue
			if letras.contains(filas[ny][nx]):
				return true
	return false


## Casillas a menos de 2 tiles de un árbol (franja del límite del mapa y árboles colocados).
func _casillas_cerca_de_arboles(filas: PackedStringArray) -> Dictionary:
	var cerca := {}
	var centros: Array[Vector2i] = []
	for y in TILES.y:
		for x in TILES.x:
			if filas[y][x] == "T":
				centros.append(Vector2i(x, y))
	for puesto in _puestos:
		if puesto["tipo"] in ["arbol_dorado", "cerezo", "arbol_redondo", "tocon"]:
			centros.append(Vector2i((puesto["pos"] / TAMANO_TILE).floor()))
	for c in centros:
		for dy in range(-2, 3):
			for dx in range(-2, 3):
				cerca[c + Vector2i(dx, dy)] = true
	return cerca


# --- Ambiente: color de atardecer, luces de los portales y viñeta ---

func _crear_ambiente() -> void:
	if _modulador == null or not is_instance_valid(_modulador):
		_modulador = CanvasModulate.new()
		_modulador.name = "Atardecer"
		add_child(_modulador)
	# Luces de los portales (el del hub y la Puerta del Reflejo): cálidas en el Pasado y frías en el Presente
	for epoca in ["Pasado", "Presente"]:
		var nodo := get_node_or_null(epoca)
		if nodo == null:
			continue
		var vieja := nodo.get_node_or_null("Luz_Reflejo")  # versión antigua (ahora la luz la pone la puerta)
		if vieja != null:
			vieja.free()
	# Viñeta suave y capa de la transición entre épocas (solo en el juego, no en el editor)
	if Engine.is_editor_hint() or get_node_or_null("Vineta") != null:
		return
	var capa_transicion := CanvasLayer.new()
	capa_transicion.name = "Transicion"
	capa_transicion.layer = 6  # sobre la viñeta y bajo los diálogos
	_rect_transicion = ColorRect.new()
	_rect_transicion.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect_transicion.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var material_transicion := ShaderMaterial.new()
	material_transicion.shader = TRANSICION
	_rect_transicion.material = material_transicion
	_rect_transicion.visible = false
	capa_transicion.add_child(_rect_transicion)
	add_child(capa_transicion)
	var capa := CanvasLayer.new()
	capa.name = "Vineta"
	capa.layer = 4  # por debajo de los diálogos y los menús
	var rect := ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var material := ShaderMaterial.new()
	material.shader = VINETA
	rect.material = material
	capa.add_child(rect)
	add_child(capa)


## Cambia el color del ambiente según la época (con un fundido corto en el juego).
func _aplicar_ambiente(es_pasado: bool, con_fundido: bool) -> void:
	if _modulador == null or not is_instance_valid(_modulador):
		return
	var progreso := clampf((_saturacion - SATURACION_MINIMA) / (1.0 - SATURACION_MINIMA), 0.0, 1.0)
	var color := COLOR_PASADO if es_pasado else COLOR_PRESENTE.lerp(COLOR_PRESENTE_VIVO, progreso)
	if con_fundido and not Engine.is_editor_hint() and is_inside_tree():
		create_tween().tween_property(_modulador, "color", color, 0.5)
	else:
		_modulador.color = color


# --- Viaje entre épocas ---

## Viaja a la otra época: bloquea al jugador, ondas y destello de luz, cambia de época (conserva la
## posición) y lo libera. Lo piden los portales y las grietas con su señal `viaje_pedido`.
func viajar() -> void:
	if _viajando or Engine.is_editor_hint() or _rect_transicion == null:
		return
	_viajando = true
	var jugador := _jugador()
	if jugador != null and jugador.has_method("bloquear"):
		jugador.bloquear()
	var material := _rect_transicion.material as ShaderMaterial
	_rect_transicion.visible = true
	await _animar_transicion(material, 0.0, 1.0, 0.6)
	GameState.cambiar_epoca()  # Mundo.mostrar_epoca está conectado a esta señal
	await get_tree().process_frame
	await get_tree().process_frame
	await _animar_transicion(material, 1.0, 0.0, 0.75)
	_rect_transicion.visible = false
	if jugador != null and jugador.has_method("liberar"):
		jugador.liberar()
	_viajando = false


func _animar_transicion(material: ShaderMaterial, desde: float, hasta: float, segundos: float) -> void:
	var t := create_tween().set_parallel(true)
	t.tween_method(func(v: float) -> void: material.set_shader_parameter("fuerza", v), desde, hasta, segundos)
	# el destello sube más rápido y baja con suavidad
	t.tween_method(func(v: float) -> void: material.set_shader_parameter("destello", v * v), desde, hasta, segundos)
	await t.finished


# --- Portales, Guía y criaturas ---

## Crea (solo en el juego, no en el editor) el portal del hub y las grietas de cada zona en las dos
## épocas, la Guía junto al portal en las dos épocas, y las 7 criaturas en el Pasado.
func colocar_entidades() -> void:
	if Engine.is_editor_hint():
		return
	var filas := _leer_mapa()
	if filas.is_empty():
		return
	for epoca in ["Pasado", "Presente"]:
		var objetos := get_node_or_null("%s/Objetos" % epoca)
		if objetos == null:
			continue
		for viejo in objetos.get_children():
			if viejo.is_in_group("entidades_mundo"):
				viejo.free()
		# Portal principal en el hub
		_poner_portal(objetos, "Portal_Hub", posicion_zona("Hub"), false)
		# Una grieta en la entrada de cada zona
		for zona in ZONAS_EMOCION:
			_poner_portal(objetos, "Grieta_%s" % zona, _entrada_de_zona(zona, filas), true)
		# La Puerta del Reflejo, arriba del mapa, en las dos épocas
		_poner_entidad(objetos, PUERTA_REFLEJO.instantiate() as Node2D, "PuertaReflejo", posicion_zona("Final"))
		# Los bloqueos del Presente: uno por zona, sobre el camino hacia su centro
		if epoca == "Presente":
			for id in GameState.ids_emociones():
				var zona := id.capitalize()
				var centro := posicion_zona(zona)
				var pos_bloqueo := _posicion_bloqueo(zona, filas)
				var bloqueo := BLOQUEO.instantiate() as BloqueoPresente
				bloqueo.datos = GameState.obtener_datos(id)
				bloqueo.direccion = (centro - pos_bloqueo).normalized()
				_poner_entidad(objetos, bloqueo, "Bloqueo_%s" % zona, pos_bloqueo)
		# La Guía, cerca del portal
		var guia := GUIA.instantiate() as Node2D
		_poner_entidad(objetos, guia, "Guia", posicion_zona("Hub") + Vector2(-72, -8))
		# Las criaturas viven en el Pasado
		if epoca == "Pasado":
			for id in GameState.ids_emociones():
				var ruta := "res://Scenes/Emociones/%s.tscn" % id.capitalize()
				if not ResourceLoader.exists(ruta):
					push_warning("Mundo: no existe la escena de la emoción '%s'." % id)
					continue
				var criatura := (load(ruta) as PackedScene).instantiate() as Node2D
				_poner_entidad(objetos, criatura, id.capitalize(), posicion_zona(id.capitalize()))


func _poner_portal(objetos: Node, nombre: String, pos: Vector2, es_grieta: bool) -> void:
	var portal := PORTAL.instantiate() as Portal
	portal.es_grieta = es_grieta
	portal.escala = 0.5 if es_grieta else 1.0
	portal.viaje_pedido.connect(viajar)
	_poner_entidad(objetos, portal, nombre, pos)


func _poner_entidad(objetos: Node, nodo: Node2D, nombre: String, pos: Vector2) -> void:
	nodo.name = nombre
	nodo.position = pos
	nodo.add_to_group("entidades_mundo")
	objetos.add_child(nodo)


## Punto de la entrada de una zona: a unos 110 px de su centro, en dirección al hub, sobre suelo libre.
func _entrada_de_zona(zona: String, filas: PackedStringArray) -> Vector2:
	var centro := posicion_zona(zona)
	var direccion := (posicion_zona("Hub") - centro).normalized()
	# La grieta queda antes (más lejos del centro) que el bloqueo del Presente, para no saltárselo
	for distancia in [170.0, 190.0, 150.0, 210.0, 130.0, 110.0, 90.0]:
		for lado in [0.0, 24.0, -24.0]:
			var pos: Vector2 = centro + direccion * distancia + direccion.orthogonal() * lado
			var celda := Vector2i((pos / TAMANO_TILE).floor())
			if celda.x < 0 or celda.y < 0 or celda.x >= TILES.x or celda.y >= TILES.y:
				continue
			if not OCUPADAS.contains(filas[celda.y][celda.x]) and not _toca(filas, celda.x, celda.y, "CMRXTwPqQ"):
				return pos
	return centro + direccion * 170.0


## Dónde va el bloqueo del Presente de una zona: sobre una casilla de camino a unos 110 px del
## centro, del lado del hub (así queda entre la entrada y el centro).
func _posicion_bloqueo(zona: String, filas: PackedStringArray) -> Vector2:
	var centro := posicion_zona(zona)
	var hacia_hub := (posicion_zona("Hub") - centro).normalized()
	var mejor := centro + hacia_hub * 110.0
	var mejor_puntos := INF
	var celda_centro := Vector2i((centro / TAMANO_TILE).floor())
	for dy in range(-6, 7):
		for dx in range(-6, 7):
			var celda := celda_centro + Vector2i(dx, dy)
			if celda.x < 0 or celda.y < 0 or celda.x >= TILES.x or celda.y >= TILES.y or filas[celda.y][celda.x] != "c":
				continue
			var pos := (Vector2(celda) + Vector2(0.5, 0.5)) * TAMANO_TILE
			var distancia := pos.distance_to(centro)
			if distancia < 80.0 or distancia > 150.0:
				continue
			var puntos := absf(distancia - 110.0) + (60.0 if (pos - centro).normalized().dot(hacia_hub) < 0.0 else 0.0)
			if puntos < mejor_puntos:
				mejor_puntos = puntos
				mejor = pos
	return mejor


# --- Color y partículas de cada época ---

## Luciérnagas doradas en el Pasado y ceniza gris que cae en el Presente (siguen al jugador, ver _process).
func _crear_particulas() -> void:
	if Engine.is_editor_hint():
		return
	var punto := Image.create(2, 2, false, Image.FORMAT_RGBA8)
	punto.fill(Color.WHITE)
	var textura := ImageTexture.create_from_image(punto)
	for epoca in ["Pasado", "Presente"]:
		var nodo := get_node_or_null(epoca)
		if nodo == null:
			continue
		var viejas := nodo.get_node_or_null("Particulas")
		if viejas != null:
			viejas.free()
		var p := CPUParticles2D.new()
		p.name = "Particulas"
		p.texture = textura
		p.z_index = 40
		p.local_coords = false
		p.position = posicion_zona("Hub")
		var degradado := Gradient.new()
		if epoca == "Pasado":
			# Luciérnagas: aparecen, brillan y se apagan flotando despacio
			p.amount = 60
			p.lifetime = 6.0
			p.preprocess = 6.0
			p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
			p.emission_rect_extents = Vector2(330, 190)
			p.direction = Vector2(0, -1)
			p.spread = 180.0
			p.gravity = Vector2(0, -2)
			p.initial_velocity_min = 3.0
			p.initial_velocity_max = 9.0
			p.scale_amount_min = 1.0
			p.scale_amount_max = 2.0
			degradado.offsets = PackedFloat32Array([0.0, 0.2, 0.5, 0.75, 1.0])
			degradado.colors = PackedColorArray([
				Color(1.0, 0.88, 0.45, 0.0), Color(1.0, 0.88, 0.45, 0.95), Color(1.0, 0.8, 0.35, 0.25),
				Color(1.0, 0.9, 0.5, 0.9), Color(1.0, 0.88, 0.45, 0.0)])
			var suma := CanvasItemMaterial.new()
			suma.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
			p.material = suma
		else:
			# Ceniza y polvo gris que cae despacio desde arriba de la pantalla
			p.amount = 90
			p.lifetime = 9.0
			p.preprocess = 9.0
			p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
			p.emission_rect_extents = Vector2(340, 8)
			p.direction = Vector2(0.25, 1)
			p.spread = 18.0
			p.gravity = Vector2(3, 8)
			p.initial_velocity_min = 8.0
			p.initial_velocity_max = 18.0
			p.scale_amount_min = 1.0
			p.scale_amount_max = 2.0
			degradado.offsets = PackedFloat32Array([0.0, 0.15, 0.85, 1.0])
			degradado.colors = PackedColorArray([
				Color(0.74, 0.76, 0.84, 0.0), Color(0.74, 0.76, 0.84, 0.55), Color(0.62, 0.64, 0.74, 0.45),
				Color(0.62, 0.64, 0.74, 0.0)])
		p.color_ramp = degradado
		nodo.add_child(p)


# --- Color del Presente según lo que integres ---

## Pone el shader de saturación al Presente (y a todo lo que cuelga de él).
func _preparar_saturacion() -> void:
	var presente := get_node_or_null("Presente") as CanvasItem
	if presente == null:
		return
	_material_presente.shader = SATURACION
	_material_presente.set_shader_parameter("saturacion", _saturacion)
	presente.material = _material_presente
	_heredar_material(presente)


## Los hijos usan el material del padre. Se salta al jugador y a lo que ya tiene material propio (partículas).
func _heredar_material(nodo: Node) -> void:
	for hijo in nodo.get_children():
		if hijo.is_in_group("player"):
			continue
		if hijo is CanvasItem and hijo.material == null:
			hijo.use_parent_material = true
		_heredar_material(hijo)


## Calcula la saturación (0.25 sin integradas, 1.0 con todas) y la anima suavemente.
func _actualizar_saturacion(con_animacion: bool) -> void:
	var total := float(maxi(1, GameState.ids_emociones().size()))
	var destino := SATURACION_MINIMA + (1.0 - SATURACION_MINIMA) * float(GameState.cantidad_integradas()) / total
	if _tween_saturacion != null and _tween_saturacion.is_valid():
		_tween_saturacion.kill()
	if not con_animacion:
		_poner_saturacion(destino)
		return
	_tween_saturacion = create_tween()
	_tween_saturacion.tween_method(_poner_saturacion, _saturacion, destino, 1.6).set_trans(Tween.TRANS_SINE)


func _poner_saturacion(valor: float) -> void:
	_saturacion = valor
	_material_presente.set_shader_parameter("saturacion", valor)
	_aplicar_ambiente(_epoca_actual == "pasado", false)
