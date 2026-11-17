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
## Una compuerta de habilidad se abrió (vale para las dos épocas).
signal compuerta_abierta(id: String)
## Llegó una pista nueva (para el diario).
signal pista_registrada(id: String)
## Se abrió el cofre de memoria de una emoción (mejora su habilidad y da un regalo). Una vez por emoción.
signal cofre_abierto(id: String)
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
## Consejos de las emociones que el jugador ya vio: id de emoción -> índices (de su lista en Resources/Consejos/).
## Se guardan con la partida para que el diario pueda listarlos.
var consejos_vistos: Dictionary = {}
## ids de los fragmentos de memoria ya recogidos (uno por emoción). Se guardan con la partida.
var fragmentos: Array[String] = []
## true cuando se recogieron todos los fragmentos (se usará en el final).
var recuerdos_completos: bool = false
## Dónde estaba el jugador al guardar (lo rellena el autoload Guardado; ver Mundo).
var posicion_jugador: Vector2 = Vector2.ZERO
var tiene_posicion: bool = false
## true justo después de cargar una partida con posición: Mundo coloca al jugador ahí y lo apaga.
var restaurar_posicion: bool = false
## id de emoción -> true si ya se abrió su cofre de memoria. Se guarda con la partida.
var cofres: Dictionary = {}
## ids de las emociones cuyo regalo ya se tiene (uno por cofre). Se guardan.
var regalos: Array[String] = []
## true cuando se tienen los 7 regalos (lo usa el final).
var regalos_completos: bool = false
## id de compuerta -> true si está abierta. UN solo estado para las dos épocas. Se guarda con la partida.
var compuertas: Dictionary = {}
## ids de las compuertas que el jugador ya vio (el diario muestra "???" hasta entonces). Se guardan.
var compuertas_vistas: Array[String] = []
## Pistas recibidas: [{"id", "titulo", "texto"}]. Se guardan para el diario.
var pistas: Array[Dictionary] = []
## id de compuerta -> cuántas veces se pidió su pista (sube el nivel de la pista, de 1 a 3). Se guarda.
var pista_niveles: Dictionary = {}
## Último paso sugerido por la Guía ("¿Qué hago ahora?"): lo usa la brújula (G). No se guarda.
var paso_guia: Dictionary = {}
## (Las respuestas de la evaluación inicial y final viven ahora en el autoload Evaluacion.)
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


## true si el cofre de memoria de esa emoción ya se abrió.
func cofre_esta_abierto(id: String) -> bool:
	return bool(cofres.get(id, false))


## Abre el cofre de una emoción para siempre: mejora su habilidad (nivel 2) y guarda su regalo. Solo si la
## emoción está integrada y solo una vez; devuelve false si no se pudo (o ya estaba abierto).
func abrir_cofre(id: String) -> bool:
	if not _datos.has(id) or cofre_esta_abierto(id) or estado.get(id, "pendiente") != "integrada":
		return false
	cofres[id] = true
	if not regalos.has(id):
		regalos.append(id)
	_actualizar_regalos_completos()
	cofre_abierto.emit(id)
	return true


func tiene_regalo(id: String) -> bool:
	return regalos.has(id)


func _actualizar_regalos_completos() -> void:
	regalos_completos = not _datos.is_empty() and regalos.size() >= _datos.size()


## true si la compuerta está abierta (en las dos épocas a la vez).
func compuerta_esta_abierta(id: String) -> bool:
	return bool(compuertas.get(id, false))


## Abre una compuerta para siempre. Devuelve false si ya estaba abierta.
func abrir_compuerta(id: String) -> bool:
	if compuerta_esta_abierta(id):
		return false
	compuertas[id] = true
	compuerta_abierta.emit(id)
	return true


## Anota que el jugador vio una compuerta (así sus conexiones dejan de ser "???" en el diario).
func marcar_compuerta_vista(id: String) -> void:
	if not compuertas_vistas.has(id):
		compuertas_vistas.append(id)


func compuerta_vista(id: String) -> bool:
	return compuertas_vistas.has(id)


## Guarda una pista en el diario (sin repetir el mismo id).
func registrar_pista(id: String, titulo: String, texto: String) -> void:
	for p in pistas:
		if p["id"] == id:
			return
	pistas.append({"id": id, "titulo": titulo, "texto": texto})
	pista_registrada.emit(id)


## La pista de una compuerta: sube de nivel cada vez que se pide (insinúa, nombra, dice dónde) y se anota.
func pista_de_compuerta(id: String) -> String:
	var nivel := int(pista_niveles.get(id, 0)) + 1
	pista_niveles[id] = mini(nivel, 3)
	var c := Progresion.compuerta(id)
	var texto := Progresion.texto_pista(id, nivel)
	var con_habilidad := tiene_habilidad(str(c.get("habilidad_requerida", "")))
	registrar_pista("%s|%s" % [id, "con" if con_habilidad else str(mini(nivel, 3))], str(c.get("nombre", "")), texto)
	return texto


## El texto de "¿Qué hago ahora?" de la Guía (y recuerda el paso para la brújula).
func texto_siguiente_paso() -> String:
	paso_guia = Progresion.siguiente_paso()
	return str(paso_guia["texto"])


## La Guía dio su pista: se anota en el diario.
func registrar_pista_guia() -> void:
	if paso_guia.is_empty():
		paso_guia = Progresion.siguiente_paso()
	Sonido.pista()   # la respuesta de "¿Qué hago ahora?"
	registrar_pista("guia|" + str(paso_guia["texto"]).sha1_text().substr(0, 8), "La Guía", str(paso_guia["texto"]))


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


## Anota que el jugador vio ese consejo de la emoción (sin repetir).
func marcar_consejo_visto(id: String, indice: int) -> void:
	if not _datos.has(id) or indice < 0:
		return
	var lista: Array = consejos_vistos.get(id, [])
	if not lista.has(indice):
		lista.append(indice)
		lista.sort()
	consejos_vistos[id] = lista


## Los índices de los consejos ya vistos de una emoción (ordenados).
func consejos_vistos_de(id: String) -> Array:
	return consejos_vistos.get(id, []).duplicate()


func cantidad_consejos_vistos() -> int:
	var total := 0
	for id in consejos_vistos:
		total += consejos_vistos[id].size()
	return total


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
	consejos_vistos.clear()
	recuerdos_completos = false
	tiene_posicion = false
	restaurar_posicion = false
	diario.clear()
	guia_conocida = false
	cofres.clear()
	regalos.clear()
	regalos_completos = false
	compuertas.clear()
	compuertas_vistas.clear()
	pistas.clear()
	pista_niveles.clear()
	paso_guia = {}
	partida_reiniciada.emit()


## Guarda la partida de forma segura: escribe un archivo temporal y lo renombra (así, si algo falla a
## medias, la partida anterior no se estropea). Devuelve true si se pudo guardar.
func guardar() -> bool:
	var contenido := {
		"epoca": epoca,
		"estado": estado,
		"habilidades": habilidades,
		"habilidad_seleccionada": habilidad_seleccionada,
		"fragmentos": fragmentos,
		"consejos_vistos": consejos_vistos,
		"recuerdos_completos": recuerdos_completos,
		"evaluacion": Evaluacion.a_diccionario(),
		"diario": diario,
		"guia_conocida": guia_conocida,
		"compuertas": compuertas,
		"cofres": cofres,
		"regalos": regalos,
		"compuertas_vistas": compuertas_vistas,
		"pistas": pistas,
		"pista_niveles": pista_niveles,
	}
	if tiene_posicion:
		contenido["posicion"] = [posicion_jugador.x, posicion_jugador.y]
	# En la web se escribe directo al archivo final: el almacenamiento del navegador (IndexedDB) se sincroniza al
	# cerrar el archivo, y un renombrado posterior no lo dispararía. En escritorio se usa el archivo temporal.
	var en_web := OS.has_feature("web")
	var temporal := RUTA_GUARDADO if en_web else RUTA_GUARDADO + ".tmp"
	var archivo := FileAccess.open(temporal, FileAccess.WRITE)
	if archivo == null:
		push_error("GameState: no se pudo guardar (error %d)." % FileAccess.get_open_error())
		return false
	archivo.store_string(JSON.stringify(contenido, "	"))
	archivo.close()
	if en_web:
		return true
	var error := DirAccess.rename_absolute(ProjectSettings.globalize_path(temporal), ProjectSettings.globalize_path(RUTA_GUARDADO))
	if error != OK:
		push_error("GameState: no se pudo terminar de guardar (error %d)." % error)
		return false
	return true


## true si existe un archivo de guardado (no carga nada; sirve para mostrar "Continuar").
func hay_partida_guardada() -> bool:
	return FileAccess.file_exists(RUTA_GUARDADO)


## Estado del archivo de guardado: "falta" (no existe), "danada" (no se puede leer) o "ok".
func diagnosticar_partida() -> String:
	if not FileAccess.file_exists(RUTA_GUARDADO):
		return "falta"
	var lectura: Variant = _leer_partida()
	if typeof(lectura) != TYPE_DICTIONARY or typeof(lectura.get("estado", null)) != TYPE_DICTIONARY:
		return "danada"
	return "ok"


## Lee y entiende el JSON del archivo de guardado. Devuelve null si no se puede (sin ensuciar la consola).
func _leer_partida() -> Variant:
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(RUTA_GUARDADO)) != OK:
		return null
	return json.data


## Carga la partida guardada. Devuelve true si se cargó. Si el archivo falta o está dañado no cambia
## nada y devuelve false (quien llama avisa al jugador y le ofrece una partida nueva). Cada dato se
## comprueba: lo que no tenga el tipo esperado se ignora en vez de romper el juego.
func cargar() -> bool:
	if diagnosticar_partida() != "ok":
		if FileAccess.file_exists(RUTA_GUARDADO):
			push_warning("GameState: el archivo de guardado está dañado.")
		return false
	var lectura: Dictionary = _leer_partida()

	nueva_partida()
	var epoca_guardada: Variant = lectura.get("epoca", "pasado")
	epoca = "presente" if typeof(epoca_guardada) == TYPE_STRING and epoca_guardada == "presente" else "pasado"

	# Solo se aceptan emociones y estados que existen
	var estado_guardado: Dictionary = lectura["estado"]
	for id in estado_guardado:
		if _datos.has(id) and RESULTADOS.has(estado_guardado[id]):
			estado[id] = estado_guardado[id]

	for h in _lista(lectura, "habilidades"):
		if not habilidades.has(str(h)):
			habilidades.append(str(h))
	habilidad_seleccionada = str(lectura.get("habilidad_seleccionada", ""))
	# Solo se aceptan fragmentos de emociones que existen, sin repetir
	for f in _lista(lectura, "fragmentos"):
		if _datos.has(str(f)) and not fragmentos.has(str(f)):
			fragmentos.append(str(f))
	_actualizar_recuerdos_completos()
	# Consejos ya vistos: solo emociones que existen e índices enteros no negativos
	var vistos: Variant = lectura.get("consejos_vistos", {})
	if typeof(vistos) == TYPE_DICTIONARY:
		for id in vistos:
			if _datos.has(str(id)) and typeof(vistos[id]) == TYPE_ARRAY:
				for indice in vistos[id]:
					if (typeof(indice) == TYPE_FLOAT or typeof(indice) == TYPE_INT) and int(indice) >= 0:
						marcar_consejo_visto(str(id), int(indice))
	# La evaluación (pre, consentimiento...) vuelve a su sitio; el "pre" ya hecho no se repite
	Evaluacion.desde_diccionario(lectura.get("evaluacion", null))
	for entrada in _lista(lectura, "diario"):
		if typeof(entrada) == TYPE_DICTIONARY and entrada.has("id") and entrada.has("texto"):
			diario.append({"id": str(entrada["id"]), "texto": str(entrada["texto"])})

	# Compuertas: solo las que existen en Progresion.json; pistas con su forma comprobada
	var ids_compuertas: Array[String] = []
	for c in Progresion.compuertas():
		ids_compuertas.append(str(c["id"]))
	var guardadas: Variant = lectura.get("compuertas", {})
	if typeof(guardadas) == TYPE_DICTIONARY:
		for id in guardadas:
			if ids_compuertas.has(str(id)) and typeof(guardadas[id]) == TYPE_BOOL and guardadas[id]:
				compuertas[str(id)] = true
	for id in _lista(lectura, "compuertas_vistas"):
		if ids_compuertas.has(str(id)) and not compuertas_vistas.has(str(id)):
			compuertas_vistas.append(str(id))
	for p in _lista(lectura, "pistas"):
		if typeof(p) == TYPE_DICTIONARY and p.has("id") and p.has("texto"):
			registrar_pista(str(p["id"]), str(p.get("titulo", "")), str(p["texto"]))
	var niveles: Variant = lectura.get("pista_niveles", {})
	if typeof(niveles) == TYPE_DICTIONARY:
		for id in niveles:
			if ids_compuertas.has(str(id)) and (typeof(niveles[id]) == TYPE_FLOAT or typeof(niveles[id]) == TYPE_INT):
				pista_niveles[str(id)] = clampi(int(niveles[id]), 0, 3)

	# Cofres de memoria y regalos: solo emociones que existen, sin repetir
	var cofres_guardados: Variant = lectura.get("cofres", {})
	if typeof(cofres_guardados) == TYPE_DICTIONARY:
		for id in cofres_guardados:
			if _datos.has(str(id)) and typeof(cofres_guardados[id]) == TYPE_BOOL and cofres_guardados[id]:
				cofres[str(id)] = true
	for r in _lista(lectura, "regalos"):
		if _datos.has(str(r)) and not regalos.has(str(r)):
			regalos.append(str(r))
	_actualizar_regalos_completos()

	var conocida: Variant = lectura.get("guia_conocida", false)
	guia_conocida = typeof(conocida) == TYPE_BOOL and conocida

	# Dónde estaba el jugador (Mundo lo coloca ahí al entrar)
	var pos: Variant = lectura.get("posicion", null)
	if typeof(pos) == TYPE_ARRAY and pos.size() == 2 and (typeof(pos[0]) == TYPE_FLOAT or typeof(pos[0]) == TYPE_INT) 			and (typeof(pos[1]) == TYPE_FLOAT or typeof(pos[1]) == TYPE_INT):
		posicion_jugador = Vector2(float(pos[0]), float(pos[1]))
		tiene_posicion = true
		restaurar_posicion = true

	epoca_cambiada.emit(epoca)
	partida_cargada.emit()
	return true


## El valor de `clave` si es una lista; si no, una lista vacía.
func _lista(datos: Dictionary, clave: String) -> Array:
	var valor: Variant = datos.get(clave, [])
	return valor if typeof(valor) == TYPE_ARRAY else []
