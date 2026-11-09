extends Node
## Memoria global del juego: época, estado de cada emoción, habilidades y diario.
## Las emociones se leen de Resources/Emociones/*.tres, así que añadir una nueva
## no requiere tocar este script.

signal epoca_cambiada(epoca: String)
signal emocion_resuelta(id: String, resultado: String)
signal habilidad_desbloqueada(habilidad_id: String)

const CARPETA_EMOCIONES := "res://Resources/Emociones"
const RUTA_GUARDADO := "user://ecos_save.json"
const RESULTADOS := ["pendiente", "atacada", "ignorada", "integrada"]
## Con cuántas emociones atacadas o ignoradas el final es "difícil".
const MINIMO_FINAL_DIFICIL := 3

## "pasado" o "presente"
var epoca: String = "pasado"
## id de emoción -> "pendiente" | "atacada" | "ignorada" | "integrada"
var estado: Dictionary = {}
## ids de habilidades ya desbloqueadas (ej. "impulso")
var habilidades: Array[String] = []
var respuestas_inicio: Array[int] = []
var respuestas_final: Array[int] = []
## Mensajes capturados: [{"id": "rabia", "texto": "..."}]
var diario: Array[Dictionary] = []

## id de emoción -> EmocionData
var _datos: Dictionary = {}


func _ready() -> void:
	_cargar_emociones()
	nueva_partida()


## Lee todos los .tres de la carpeta de emociones.
func _cargar_emociones() -> void:
	_datos.clear()
	var archivos := DirAccess.get_files_at(CARPETA_EMOCIONES)
	archivos.sort()
	for archivo in archivos:
		# En un juego exportado los archivos terminan en ".remap"
		var nombre := archivo.trim_suffix(".remap")
		if not nombre.ends_with(".tres"):
			continue
		var recurso := load(CARPETA_EMOCIONES.path_join(nombre))
		if recurso is EmocionData and recurso.id != "":
			_datos[recurso.id] = recurso
		else:
			push_warning("GameState: '%s' no es una EmocionData válida." % nombre)


## Devuelve los datos de una emoción, o null si no existe.
func obtener_datos(id: String) -> EmocionData:
	return _datos.get(id, null)


## Lista de los ids de todas las emociones cargadas.
func ids_emociones() -> Array[String]:
	var ids: Array[String] = []
	for id in _datos:
		ids.append(id)
	return ids


func cambiar_epoca() -> void:
	epoca = "presente" if epoca == "pasado" else "pasado"
	epoca_cambiada.emit(epoca)


## resultado: "integrada", "atacada" o "ignorada" (también "pendiente" para reiniciar)
func resolver(id: String, resultado: String) -> void:
	if not _datos.has(id):
		push_warning("GameState: la emoción '%s' no existe." % id)
		return
	if not RESULTADOS.has(resultado):
		push_warning("GameState: resultado '%s' no válido." % resultado)
		return

	estado[id] = resultado

	if resultado == "integrada":
		var datos: EmocionData = _datos[id]
		_guardar_en_diario(id, datos.mensaje_integracion)
		if datos.habilidad_id != "" and not habilidades.has(datos.habilidad_id):
			habilidades.append(datos.habilidad_id)
			habilidad_desbloqueada.emit(datos.habilidad_id)

	emocion_resuelta.emit(id, resultado)


func _guardar_en_diario(id: String, texto: String) -> void:
	# Evita repetir el mismo mensaje si se integra otra vez
	for entrada in diario:
		if entrada["id"] == id:
			return
	diario.append({"id": id, "texto": texto})


func tiene_habilidad(habilidad_id: String) -> bool:
	return habilidades.has(habilidad_id)


func cantidad_integradas() -> int:
	var total := 0
	for id in estado:
		if estado[id] == "integrada":
			total += 1
	return total


## Devuelve "bueno", "neutro" o "dificil".
func calcular_final() -> String:
	if not _datos.is_empty() and cantidad_integradas() == _datos.size():
		return "bueno"
	var malas := 0
	for id in estado:
		if estado[id] == "atacada" or estado[id] == "ignorada":
			malas += 1
	if malas >= MINIMO_FINAL_DIFICIL:
		return "dificil"
	return "neutro"


## Reinicia todo el progreso.
func nueva_partida() -> void:
	epoca = "pasado"
	estado.clear()
	for id in _datos:
		estado[id] = "pendiente"
	habilidades.clear()
	respuestas_inicio.clear()
	respuestas_final.clear()
	diario.clear()


func guardar() -> void:
	var contenido := {
		"epoca": epoca,
		"estado": estado,
		"habilidades": habilidades,
		"respuestas_inicio": respuestas_inicio,
		"respuestas_final": respuestas_final,
		"diario": diario,
	}
	var archivo := FileAccess.open(RUTA_GUARDADO, FileAccess.WRITE)
	if archivo == null:
		push_error("GameState: no se pudo guardar (error %d)." % FileAccess.get_open_error())
		return
	archivo.store_string(JSON.stringify(contenido, "\t"))


## Devuelve true si se cargó una partida guardada.
func cargar() -> bool:
	if not FileAccess.file_exists(RUTA_GUARDADO):
		return false
	var lectura = JSON.parse_string(FileAccess.get_file_as_string(RUTA_GUARDADO))
	if typeof(lectura) != TYPE_DICTIONARY:
		push_warning("GameState: el archivo de guardado está dañado.")
		return false

	nueva_partida()
	epoca = "presente" if lectura.get("epoca", "pasado") == "presente" else "pasado"

	# Solo se aceptan emociones y estados que existen
	var estado_guardado: Dictionary = lectura.get("estado", {})
	for id in estado_guardado:
		if _datos.has(id) and RESULTADOS.has(estado_guardado[id]):
			estado[id] = estado_guardado[id]

	for h in lectura.get("habilidades", []):
		habilidades.append(str(h))
	# JSON devuelve los números como float, se pasan a int
	for r in lectura.get("respuestas_inicio", []):
		respuestas_inicio.append(int(r))
	for r in lectura.get("respuestas_final", []):
		respuestas_final.append(int(r))
	for entrada in lectura.get("diario", []):
		if typeof(entrada) == TYPE_DICTIONARY and entrada.has("id") and entrada.has("texto"):
			diario.append({"id": str(entrada["id"]), "texto": str(entrada["texto"])})

	epoca_cambiada.emit(epoca)
	return true
