extends SceneTree
## Construye los TileSet de las dos épocas a partir de los atlas y de tools/tileset_info.json.
##
## Uso (después de generar los PNG con tools/generar_tileset.py e importarlos):
##   godot --headless --path . --import
##   godot --headless --path . --script res://tools/construir_tileset.gd
##
## Salida: Resources/Mundo/tileset_pasado.tres y tileset_presente.tres (idénticos salvo la textura)
## y detalles_pasado.tres / detalles_presente.tres (matas, flores, piedritas y hojas de 16x16).

const TAMANO := 32
const RUTA_INFO := "res://tools/tileset_info.json"
const RUTA_INFO_DETALLES := "res://tools/detalles_info.json"

## Tiles con colisión de cuadrado completo: acantilados, muros, rocas y los bloques invisibles.
const SOLIDOS := [
	"roca", "acantilado_cara_0", "acantilado_cara_1", "acantilado_cima_0", "acantilado_cima_1",
	"muro_piedra_0", "muro_piedra_1", "muro_cuerpo_0", "muro_cuerpo_1", "colision", "colision_agua_profunda",
]

## Origen de ordenado en Y (en píxeles). Medido en Godot 4.7: una pieza se ordena por la base de su
## casilla MÁS 16 px, así que -16 deja la base exacta (el jugador se dibuja delante si sus pies
## están más abajo que la base de la pieza). La roca se ordena por la base de su dibujo (-22).
## Los puentes van siempre por debajo del jugador.
const ORIGEN_Y := {
	"roca": -22,
	"acantilado_cara_0": -16, "acantilado_cara_1": -16, "acantilado_cima_0": -16, "acantilado_cima_1": -16,
	"muro_piedra_0": -16, "muro_piedra_1": -16, "muro_cuerpo_0": -16, "muro_cuerpo_1": -16,
	"puente_h": -200, "puente_roto_izq": -200, "puente_roto_der": -200,
}

## Un conjunto de terrenos por autotile (0 camino, 1 arena, 2 agua).
const TERRENOS := {
	"camino": {"conjunto": 0, "color": Color("c5945f")},
	"arena": {"conjunto": 1, "color": Color("ead6a8")},
	"agua": {"conjunto": 2, "color": Color("5a80b3")},
}

const VECINOS := {
	"N": TileSet.CELL_NEIGHBOR_TOP_SIDE, "NE": TileSet.CELL_NEIGHBOR_TOP_RIGHT_CORNER,
	"E": TileSet.CELL_NEIGHBOR_RIGHT_SIDE, "SE": TileSet.CELL_NEIGHBOR_BOTTOM_RIGHT_CORNER,
	"S": TileSet.CELL_NEIGHBOR_BOTTOM_SIDE, "SO": TileSet.CELL_NEIGHBOR_BOTTOM_LEFT_CORNER,
	"O": TileSet.CELL_NEIGHBOR_LEFT_SIDE, "NO": TileSet.CELL_NEIGHBOR_TOP_LEFT_CORNER,
}


func _init() -> void:
	var info: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(RUTA_INFO))
	for epoca in ["pasado", "presente"]:
		var tileset := _crear_tileset(info, "res://Assets/Mundo/tileset_%s.png" % epoca)
		var ruta := "res://Resources/Mundo/tileset_%s.tres" % epoca
		var error := ResourceSaver.save(tileset, ruta)
		print("%s: %s (error=%d)" % [ruta, "guardado" if error == OK else "FALLÓ", error])
		var detalles := _crear_tileset_detalles("res://Assets/Mundo/detalles_%s.png" % epoca)
		var ruta_d := "res://Resources/Mundo/detalles_%s.tres" % epoca
		var error_d := ResourceSaver.save(detalles, ruta_d)
		print("%s: %s (error=%d)" % [ruta_d, "guardado" if error_d == OK else "FALLÓ", error_d])
	quit()


## TileSet de la decoración suelta (cuadros de 16x16). Cada tile guarda su grupo
## ("matas", "flores", "piedras" o "hojas") en el dato personalizado "grupo".
func _crear_tileset_detalles(ruta_textura: String) -> TileSet:
	var info: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(RUTA_INFO_DETALLES))
	var tamano: int = int(info["tamano"])
	var tileset := TileSet.new()
	tileset.tile_size = Vector2i(tamano, tamano)
	tileset.add_custom_data_layer()
	tileset.set_custom_data_layer_name(0, "grupo")
	tileset.set_custom_data_layer_type(0, TYPE_STRING)
	var fuente := TileSetAtlasSource.new()
	fuente.texture = load(ruta_textura)
	fuente.texture_region_size = Vector2i(tamano, tamano)
	tileset.add_source(fuente, 0)
	var grupos: Dictionary = info["grupos"]
	for grupo in grupos:
		for celda in grupos[grupo]:
			var coords := Vector2i(int(celda[0]), int(celda[1]))
			fuente.create_tile(coords)
			fuente.get_tile_data(coords, 0).set_custom_data("grupo", grupo)
	return tileset


func _crear_tileset(info: Dictionary, ruta_textura: String) -> TileSet:
	var tileset := TileSet.new()
	tileset.tile_size = Vector2i(TAMANO, TAMANO)

	# Física: capa 1 ("mundo"); los tiles sólidos bloquean al jugador y a las criaturas
	tileset.add_physics_layer()
	tileset.set_physics_layer_collision_layer(0, 1)
	tileset.set_physics_layer_collision_mask(0, 0)

	# Dato personalizado: nombre del tile (así el mapa los busca sin depender de coordenadas)
	tileset.add_custom_data_layer()
	tileset.set_custom_data_layer_name(0, "nombre")
	tileset.set_custom_data_layer_type(0, TYPE_STRING)

	# Terrenos (autotiles de esquinas y lados)
	for nombre in TERRENOS:
		var conjunto: int = TERRENOS[nombre]["conjunto"]
		tileset.add_terrain_set()
		tileset.set_terrain_set_mode(conjunto, TileSet.TERRAIN_MODE_MATCH_CORNERS_AND_SIDES)
		tileset.add_terrain(conjunto)
		tileset.set_terrain_name(conjunto, 0, nombre)
		tileset.set_terrain_color(conjunto, 0, TERRENOS[nombre]["color"])

	var fuente := TileSetAtlasSource.new()
	fuente.texture = load(ruta_textura)
	fuente.texture_region_size = Vector2i(TAMANO, TAMANO)
	tileset.add_source(fuente, 0)

	# Tiles sueltos
	var base: Dictionary = info["base"]
	for nombre in base:
		var coords := Vector2i(int(base[nombre][0]), int(base[nombre][1]))
		fuente.create_tile(coords)
		var datos := fuente.get_tile_data(coords, 0)
		datos.set_custom_data("nombre", nombre)
		datos.y_sort_origin = ORIGEN_Y.get(nombre, 0)
		if SOLIDOS.has(nombre):
			_agregar_colision_completa(datos)

	# Autotiles de 47 piezas (el agua tiene 4 cuadros de animación)
	var autotiles: Dictionary = info["autotiles"]
	for nombre in autotiles:
		var conjunto: int = TERRENOS[nombre]["conjunto"]
		var cuadros: int = int(autotiles[nombre]["cuadros"])
		for pieza in autotiles[nombre]["tiles"]:
			var coords := Vector2i(int(pieza["coords"][0]), int(pieza["coords"][1]))
			fuente.create_tile(coords)
			if cuadros > 1:
				fuente.set_tile_animation_columns(coords, 0)  # los cuadros van en una fila hacia la derecha
				fuente.set_tile_animation_frames_count(coords, cuadros)
				for i in cuadros:
					fuente.set_tile_animation_frame_duration(coords, i, 0.35)
			var datos := fuente.get_tile_data(coords, 0)
			datos.terrain_set = conjunto
			datos.terrain = 0
			for lado in VECINOS:
				datos.set_terrain_peering_bit(VECINOS[lado], 0 if pieza["bits"][lado] else -1)
	return tileset


func _agregar_colision_completa(datos: TileData) -> void:
	var m := TAMANO / 2.0
	datos.add_collision_polygon(0)
	datos.set_collision_polygon_points(0, 0, PackedVector2Array([Vector2(-m, -m), Vector2(m, -m), Vector2(m, m), Vector2(-m, m)]))
