class_name Decorador
extends RefCounted
## Decide dónde va cada objeto decorativo (Prop) del mundo.
##
## Junta dos cosas: los marcadores de decoración que ya hay en Mundo.tscn (grupos arboles, rocas,
## faroles, bancos) y objetos extra repartidos según el tema de cada zona. Todo es determinista
## (misma semilla = mismo resultado) y se descarta cualquier sitio que moleste: caminos, agua,
## muros, la entrada de cada zona o el sitio de otro objeto.

const TAMANO_TILE := 32
## Suelos donde se puede poner un objeto (hierba, flores, pasto, tierra, volcánico, bosque, ruinas, adoquines).
const SUELOS := "fdrvbua."
## Casillas que un objeto grande no puede tocar ni de lado (agua, puentes, muros, rocas, bloqueos).
const PROHIBIDAS := "wPqQRCMXT"
## Distancia mínima (px) entre objetos y a las entradas de las zonas (donde irán portal y bloqueos).
const SEPARACION := 34.0
const LIBRE_ZONA := 215.0
const LIBRE_HUB := 110.0
## Entre dos faroles debe haber al menos este espacio (si no, quedan amontonados).
const SEPARACION_FAROLES := 190.0
## Medio ancho aproximado (px) de cada objeto, para que los anchos (rocas, bancos) no se pisen con otros.
const MEDIO_ANCHO := {
	"arbol_dorado": 34.0, "cerezo": 30.0, "arbol_redondo": 24.0, "arbusto_flores": 14.0,
	"roca": 22.0, "farol_poste": 10.0, "tocon": 14.0, "banco": 22.0,
}

## Tema de cada zona: tipo -> cuántos extra se reparten, en un anillo [mínimo, máximo] px alrededor del centro.
const TEMAS := {
	"Hub": {"cerezo": 5, "banco": 3, "anillo": Vector2(130, 330)},
	"Soledad": {"cerezo": 7, "banco": 3, "anillo": Vector2(150, 330)},
	"Tristeza": {"arbol_dorado": 6, "arbusto_flores": 2, "anillo": Vector2(170, 360)},
	"Verguenza": {"arbol_dorado": 6, "arbusto_flores": 2, "anillo": Vector2(170, 360)},
	"Rabia": {"roca": 10, "anillo": Vector2(170, 400)},
	"Miedo": {"tocon": 9, "arbol_redondo": 3, "anillo": Vector2(170, 380)},
	"Culpa": {"tocon": 6, "arbol_redondo": 2, "anillo": Vector2(170, 380)},
	"Ansiedad": {"arbusto_flores": 5, "arbol_redondo": 3, "anillo": Vector2(170, 360)},
	"Final": {"arbusto_flores": 4, "cerezo": 2, "anillo": Vector2(170, 330)},
}

## Qué árbol lleva cada zona cuando un marcador de "arboles" cae cerca de ella.
const ARBOLES_DE_ZONA := {
	"Hub": ["cerezo"], "Soledad": ["cerezo"],
	"Tristeza": ["arbol_dorado"], "Verguenza": ["arbol_dorado"],
	"Rabia": ["roca", "arbol_redondo"], "Miedo": ["tocon", "tocon", "arbol_redondo"],
	"Culpa": ["tocon", "arbol_redondo"], "Ansiedad": ["arbol_redondo", "arbusto_flores"],
	"Final": ["arbol_redondo", "cerezo"],
}

const TIPO_DE_GRUPO := {"rocas": "roca", "faroles": "farol_poste", "bancos": "banco"}

var _filas: PackedStringArray
var _zonas: Dictionary  # nombre -> posición (px)
var _puestos: Array[Dictionary] = []  # {"tipo": String, "pos": Vector2}
var _azar := RandomNumberGenerator.new()


## Devuelve la lista de objetos: [{"tipo": String, "pos": Vector2}, ...].
## `marcadores` relaciona un grupo ("arboles", "rocas", "faroles", "bancos") con las posiciones de sus Marker2D.
static func generar(filas: PackedStringArray, zonas: Dictionary, marcadores: Dictionary) -> Array[Dictionary]:
	var d := Decorador.new()
	d._filas = filas
	d._zonas = zonas
	d._azar.seed = 4242
	d._poner_franja_de_arboles()
	d._poner_marcadores(marcadores)
	d._poner_temas()
	d._poner_faroles_de_camino()
	d._poner_arboledas()
	return d._puestos


func _poner_marcadores(marcadores: Dictionary) -> void:
	for grupo in marcadores:
		for pos: Vector2 in marcadores[grupo]:
			var tipo: String
			if grupo == "arboles":
				var opciones: Array = ARBOLES_DE_ZONA[_zona_mas_cercana(pos)]
				tipo = opciones[_azar.randi() % opciones.size()]
			elif TIPO_DE_GRUPO.has(grupo):
				tipo = TIPO_DE_GRUPO[grupo]
			else:
				continue  # arcos y espejos no tienen sprite todavía
			_intentar(tipo, pos)


## Franja densa de árboles en el límite del mapa: una casilla de cada dos de las 'T', con un pequeño desplazamiento.
## Son decoración (la casilla 'T' ya es sólida), por eso no llevan colisión propia. Nunca llevan árboles
## dorados (que tienen luces) para no llenar el borde de luces.
func _poner_franja_de_arboles() -> void:
	for y in _filas.size():
		for x in _filas[y].length():
			if _filas[y][x] != "T" or (x + (y % 2)) % 2 != 0:
				continue
			var pos := _centro_de(Vector2i(x, y)) + Vector2(_azar.randf_range(-9, 9), _azar.randf_range(-5, 12))
			var tipo := "arbol_redondo"
			var tirada := _azar.randf()
			if tirada < 0.18:
				tipo = "arbusto_flores"
			elif tirada < 0.40 and _zona_mas_cercana(pos) in ["Hub", "Soledad", "Final", "Verguenza", "Tristeza"]:
				tipo = "cerezo"
			_puestos.append({"tipo": tipo, "pos": pos, "borde": true})


## Arboledas: grupos de árboles en los claros, repartidos con ruido para que formen manchas y no puntos sueltos.
func _poner_arboledas() -> void:
	var ruido := FastNoiseLite.new()
	ruido.seed = 31
	ruido.frequency = 0.05
	var puestos := 0
	for _i in 3000:
		var pos := _centrar(Vector2(_azar.randf_range(80, _filas[0].length() * TAMANO_TILE - 80), _azar.randf_range(80, _filas.size() * TAMANO_TILE - 80)))
		if ruido.get_noise_2d(pos.x / TAMANO_TILE, pos.y / TAMANO_TILE) < 0.22:
			continue
		var opciones: Array = ARBOLES_DE_ZONA[_zona_mas_cercana(pos)]
		var tipo: String = opciones[_azar.randi() % opciones.size()]
		if _intentar(tipo, pos + Vector2(_azar.randf_range(-8, 8), _azar.randf_range(-6, 6))):
			puestos += 1
			if puestos >= 90:
				return


## Reparte los objetos extra de cada zona, según su tema.
func _poner_temas() -> void:
	for zona in TEMAS:
		var tema: Dictionary = TEMAS[zona]
		var anillo: Vector2 = tema["anillo"]
		for tipo in tema:
			if tipo == "anillo":
				continue
			var faltan: int = tema[tipo]
			var intentos := 0
			while faltan > 0 and intentos < 200:
				intentos += 1
				var angulo := _azar.randf() * TAU
				var distancia := _azar.randf_range(anillo.x, anillo.y)
				var pos: Vector2 = _zonas[zona] + Vector2.RIGHT.rotated(angulo) * distancia
				if _intentar(tipo, _centrar(pos)):
					faltan -= 1


## Faroles junto a los caminos: uno cada cierto tramo, siempre al lado del camino (no encima).
func _poner_faroles_de_camino() -> void:
	var lado := 1
	for y in range(2, _filas.size() - 2):
		for x in range(2, _filas[y].length() - 2):
			if _filas[y][x] != "c" or (x * 7 + y * 13) % 11 != 0:
				continue
			lado = -lado
			for vecino in [Vector2i(lado, 0), Vector2i(-lado, 0), Vector2i(0, lado), Vector2i(0, -lado)]:
				var celda: Vector2i = Vector2i(x, y) + vecino
				if "fdrvbua.".contains(_filas[celda.y][celda.x]):
					if _intentar("farol_poste", _centro_de(celda)):
						break


## Pone el objeto si el sitio es válido. Devuelve si se puso.
func _intentar(tipo: String, pos: Vector2) -> bool:
	if not _es_valido(tipo, pos):
		return false
	_puestos.append({"tipo": tipo, "pos": pos})
	return true


func _es_valido(tipo: String, pos: Vector2) -> bool:
	var celda: Vector2i = Vector2i((pos / TAMANO_TILE).floor())
	if celda.x < 2 or celda.y < 2 or celda.x >= _filas[0].length() - 2 or celda.y >= _filas.size() - 2:
		return false
	if not SUELOS.contains(_filas[celda.y][celda.x]):
		return false
	# Nada alrededor que estorbe; los caminos solo se dejan libres si el objeto no es un farol
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var letra := _filas[celda.y + dy][celda.x + dx]
			if PROHIBIDAS.contains(letra):
				return false
			if letra == "c" and tipo != "farol_poste":
				return false
	# Entradas de las zonas (portal y bloqueos) y sitio de otros objetos
	for zona in _zonas:
		var libre := LIBRE_HUB if zona == "Hub" else LIBRE_ZONA
		if pos.distance_to(_zonas[zona]) < libre:
			return false
	for puesto in _puestos:
		if puesto.get("borde", false):
			continue
		var minima := maxf(SEPARACION, MEDIO_ANCHO[tipo] + MEDIO_ANCHO[puesto["tipo"]])
		if tipo == "farol_poste" and puesto["tipo"] == "farol_poste":
			minima = SEPARACION_FAROLES
		if pos.distance_to(puesto["pos"]) < minima:
			return false
	return true


func _zona_mas_cercana(pos: Vector2) -> String:
	var mejor := "Hub"
	var mejor_distancia := INF
	for zona in _zonas:
		var d := pos.distance_to(_zonas[zona])
		if d < mejor_distancia:
			mejor_distancia = d
			mejor = zona
	return mejor


func _centro_de(celda: Vector2i) -> Vector2:
	return (Vector2(celda) + Vector2(0.5, 0.5)) * TAMANO_TILE


## Lleva una posición al centro de su casilla.
func _centrar(pos: Vector2) -> Vector2:
	return _centro_de(Vector2i((pos / TAMANO_TILE).floor()))
