extends Node
## Memoria global del juego: época, estado de cada emoción, habilidades y diario.
## Las emociones se leen de Resources/Emociones/*.tres, así que añadir una nueva
## no requiere tocar este script.

signal epoca_cambiada(epoca: String)
signal emocion_resuelta(id: String, resultado: String)
signal habilidad_desbloqueada(habilidad_id: String)
## Se recogió un fragmento de memoria (id = el de la emoción a la que pertenece, ej. "rabia").
signal fragmento_recogido(id: String)
## Se emiten al reiniciar la partida y al cargar una guardada (las habilidades y el HUD se actualizan).
signal partida_reiniciada
signal partida_cargada

const CARPETA_EMOCIONES := "res://Resources/Emociones"
const RUTA_GUARDADO := "user://ecos_save.json"
## Los recuerdos de los fragmentos de memoria (se editan sin tocar código).
const RUTA_RECUERDOS := "res://Resources/Recuerdos.tres"
const RESULTADOS := ["pendiente", "atacada", "ignorada", "integrada"]
## Con cuántas emociones atacadas o ignoradas el final es "difícil".
const MINIMO_FINAL_DIFICIL := 4

## "pasado" o "presente"
var epoca: String = "pasado"
## id de emoción -> "pendiente" | "atacada" | "ignorada" | "integrada"
var estado: Dictionary = {}
## ids de habilidades ya desbloqueadas (ej. "impulso")
var habilidades: Array[String] = []
## id de la habilidad elegida en el HUD ("" = ninguna). Se guarda con la partida.
var habilidad_seleccionada: String = ""
## ids de los fragmentos de memoria ya recogidos (uno por emoción). Se guardan con la partida.
var fragmentos: Array[String] = []
## true cuando se recogieron todos los fragmentos (se usará en el final).
var recuerdos_completos: bool = false
var respuestas_inicio: Array[int] = []
var respuestas_final: Array[int] = []
## Mensajes capturados: [{"id": "rabia", "texto": "..."}]
var diario: Array[Dictionary] = []
## true cuando la Guía ya explicó lo básico en el mundo (así solo lo hace la primera vez).
var guia_conocida: bool = false

## id de emoción -> EmocionData
var _datos: Dictionary = {}


func _ready() -> void:
	_cargar_emociones()
	nueva_partida()


## Lee todos los .tres de la carpeta de emociones.
func _cargar_emociones() -> void:
	_datos.clear()
	var cargadas: Array[EmocionData] = []
	var archivos := DirAccess.get_files_at(CARPETA_EMOCIONES)
	archivos.sort()
	for archivo in archivos:
		# En un juego exportado los archivos terminan en ".remap"
		var nombre := archivo.trim_suffix(".remap")
		if not nombre.ends_with(".tres"):
			continue
		var recurso := load(CARPETA_EMOCIONES.path_join(nombre))
		if recurso is SpriteFrames:
			continue  # las animaciones (frames_*.tres) viven en la misma carpeta pero no son emociones
		if recurso is EmocionData and recurso.id != "":
			cargadas.append(recurso)
		else:
			push_warning("GameState: '%s' no es una EmocionData válida." % nombre)
	# Se guardan ordenadas por el campo "orden" (y por id si empatan)
	cargadas.sort_custom(func(a: EmocionData, b: EmocionData) -> bool:
		return a.orden < b.orden if a.orden != b.orden else a.id < b.id)
	for recurso in cargadas:
		_datos[recurso.id] = recurso


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


## true si ya se resolvió cada emoción (integrada, atacada o ignorada; ninguna pendiente).
func todas_resueltas() -> bool:
	return not _datos.is_empty() and cantidad_pendientes() == 0


func cantidad_pendientes() -> int:
	var total := 0
	for id in _datos:
		if estado.get(id, "pendiente") == "pendiente":
			total += 1
	return total


## Los datos de un recuerdo (título y líneas), o null si no existe.
func obtener_recuerdo(id: String) -> RecuerdoData:
	if not ResourceLoader.exists(RUTA_RECUERDOS):
		return null
	var coleccion := load(RUTA_RECUERDOS) as ColeccionRecuerdos
	if coleccion == null:
		return null
	for recuerdo in coleccion.recuerdos:
		if recuerdo != null and recuerdo.id == id:
			return recuerdo
	return null


func tiene_fragmento(id: String) -> bool:
	return fragmentos.has(id)


func cantidad_fragmentos() -> int:
	return fragmentos.size()


## Registra un fragmento de memoria y guarda su recuerdo en el diario. Devuelve false si ya estaba
## recogido (o no existe esa emoción). Si con este se completan todos, recuerdos_completos pasa a true.
func recoger_fragmento(id: String) -> bool:
	if not _datos.has(id) or fragmentos.has(id):
		return false
	fragmentos.append(id)
	var recuerdo := obtener_recuerdo(id)
	if recuerdo != null:
		_guardar_en_diario("recuerdo_" + id, "%s. %s" % [recuerdo.titulo, " ".join(recuerdo.lineas)])
	_actualizar_recuerdos_completos()
	fragmento_recogido.emit(id)
	return true


func _actualizar_recuerdos_completos() -> void:
	recuerdos_completos = not _datos.is_empty() and fragmentos.size() >= _datos.size()


func marcar_guia_conocida() -> void:
	guia_conocida = true


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
	habilidad_seleccionada = ""
	fragmentos.clear()
	recuerdos_completos = false
	respuestas_inicio.clear()
	respuestas_final.clear()
	diario.clear()
	guia_conocida = false
	partida_reiniciada.emit()


func guardar() -> void:
	var contenido := {
		"epoca": epoca,
		"estado": estado,
		"habilidades": habilidades,
		"habilidad_seleccionada": habilidad_seleccionada,
		"fragmentos": fragmentos,
		"recuerdos_completos": recuerdos_completos,
		"respuestas_inicio": respuestas_inicio,
		"respuestas_final": respuestas_final,
		"diario": diario,
		"guia_conocida": guia_conocida,
	}
	var archivo := FileAccess.open(RUTA_GUARDADO, FileAccess.WRITE)
	if archivo == null:
		push_error("GameState: no se pudo guardar (error %d)." % FileAccess.get_open_error())
		return
	archivo.store_string(JSON.stringify(contenido, "\t"))


## true si existe un archivo de guardado (no carga nada; sirve para mostrar "Continuar").
func hay_partida_guardada() -> bool:
	return FileAccess.file_exists(RUTA_GUARDADO)


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
	habilidad_seleccionada = str(lectura.get("habilidad_seleccionada", ""))
	# Solo se aceptan fragmentos de emociones que existen, sin repetir
	for f in lectura.get("fragmentos", []):
		if _datos.has(str(f)) and not fragmentos.has(str(f)):
			fragmentos.append(str(f))
	_actualizar_recuerdos_completos()
	# JSON devuelve los números como float, se pasan a int
	for r in lectura.get("respuestas_inicio", []):
		respuestas_inicio.append(int(r))
	for r in lectura.get("respuestas_final", []):
		respuestas_final.append(int(r))
	for entrada in lectura.get("diario", []):
		if typeof(entrada) == TYPE_DICTIONARY and entrada.has("id") and entrada.has("texto"):
			diario.append({"id": str(entrada["id"]), "texto": str(entrada["texto"])})

	guia_conocida = bool(lectura.get("guia_conocida", false))

	epoca_cambiada.emit(epoca)
	partida_cargada.emit()
	return true
