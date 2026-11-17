extends Node
## Evaluación inicial ("pre") y final ("post") de ECOS: el banco de preguntas, el barajado, el registro de
## respuestas, los puntajes y la comparación antes/después.
##
## Las preguntas están en Resources/Cuestionario/preguntas.json (editable sin tocar código): 7 de trivia
## (una por emoción, la opción 0 es la correcta), 7 de situaciones (la opción 0 es la más sana) y 2 de
## escala (1 a 5). Cada fase se hace con 16 preguntas en este orden: 7 trivia, 7 situaciones, 2 escala.
##
## Las respuestas se guardan por id con el índice ORIGINAL de la opción (el del archivo), no su posición en
## pantalla: las opciones de trivia y situaciones se barajan con una semilla distinta por fase. En las
## escalas, el "índice" es el valor elegido (1 a 5).
##
## PRIVACIDAD: el código del participante es aleatorio (6 caracteres) y no lleva datos personales. Si el
## jugador no acepta guardar (consentimiento_guardar = false), las respuestas solo viven en memoria: no se
## escribe nada en el archivo de guardado (solo si el "pre" ya está hecho, para no repetirlo).

signal fase_terminada(fase: String)

const RUTA_PREGUNTAS := "res://Resources/Cuestionario/preguntas.json"
const FASES := ["pre", "post"]
const BLOQUES := ["trivia", "situaciones", "escala"]
const ALFABETO := "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"

## Banco: bloque -> lista de preguntas (diccionarios del JSON). Vacío si el archivo no es válido.
var banco: Dictionary = {}
## Errores de validación del banco (vacío = válido).
var errores: Array[String] = []
var valido := false

var participante_id := ""
## true cuando el jugador ya vio la pantalla de consentimiento (en esta partida).
var consentimiento_dado := false
var consentimiento_guardar := false
## Cada fase: {"respuestas": {id: índice original}, "puntajes": {...}, "marca": segundos unix, "completa": bool}
var pre: Dictionary = {}
var post: Dictionary = {}
## Cuándo empezó a jugar (al terminar el "pre"), en segundos unix. Sirve para calcular la duración.
var momento_inicio_juego := 0.0
## true mientras hay un cuestionario en pantalla (el diario, la pausa y las habilidades no se abren).
var cuestionario_activo := false

## La valoración del jugador sobre el juego (ver Valoracion): {id_participante, fecha_iso, version_juego, respuestas,
## nota, frecuencia, sus, sus_puntaje, gusto, mejorar, error}. Vacía si no la envió.
var valoracion: Dictionary = {}
var _semillas: Dictionary = {}
## true cuando la fila de esta partida ya se agregó al CSV (así no se repite).
var _exportado := false


func _ready() -> void:
	cargar_banco()
	reiniciar()
	GameState.partida_reiniciada.connect(reiniciar)
	fase_terminada.connect(_on_fase_terminada)


# --- Banco ---

## Lee y valida preguntas.json. Devuelve true si es válido.
func cargar_banco() -> bool:
	banco.clear()
	errores.clear()
	valido = false
	var lectura: Variant = JSON.parse_string(FileAccess.get_file_as_string(RUTA_PREGUNTAS))
	if typeof(lectura) != TYPE_DICTIONARY:
		errores.append("preguntas.json no se pudo leer.")
		return false
	var ids := {}
	for bloque in BLOQUES:
		var lista: Variant = lectura.get(bloque, null)
		if typeof(lista) != TYPE_ARRAY:
			errores.append("Falta el bloque '%s'." % bloque)
			continue
		for pregunta in lista:
			_validar_pregunta(bloque, pregunta, ids)
		banco[bloque] = lista
	valido = errores.is_empty()
	if not valido:
		push_warning("Evaluacion: el banco de preguntas tiene errores: %s" % "; ".join(errores))
	return valido


func _validar_pregunta(bloque: String, p: Variant, ids: Dictionary) -> void:
	if typeof(p) != TYPE_DICTIONARY or typeof(p.get("id", null)) != TYPE_STRING or str(p["id"]) == "":
		errores.append("Una pregunta de '%s' no tiene id." % bloque)
		return
	var id: String = p["id"]
	if ids.has(id):
		errores.append("El id '%s' está repetido." % id)
	ids[id] = true
	if typeof(p.get("texto", null)) != TYPE_STRING or str(p["texto"]) == "":
		errores.append("'%s' no tiene texto." % id)
	if bloque == "escala":
		if int(p.get("valores", 0)) < 2:
			errores.append("'%s' necesita 'valores' (al menos 2)." % id)
		return
	var opciones: Variant = p.get("opciones", null)
	if typeof(opciones) != TYPE_ARRAY or opciones.size() < 2:
		errores.append("'%s' necesita al menos 2 opciones." % id)
		return
	var correcta: Variant = p.get("correcta", null)
	if typeof(correcta) not in [TYPE_INT, TYPE_FLOAT] or int(correcta) < 0 or int(correcta) >= opciones.size():
		errores.append("'%s' tiene un índice 'correcta' fuera de rango." % id)
	if bloque == "trivia" and str(p.get("explicacion", "")) == "":
		errores.append("'%s' (trivia) no tiene explicación." % id)


## La pregunta del banco por id ({} si no existe).
func pregunta(id: String) -> Dictionary:
	for bloque in BLOQUES:
		for p in banco.get(bloque, []):
			if p["id"] == id:
				return p
	return {}


func bloque_de(id: String) -> String:
	for bloque in BLOQUES:
		for p in banco.get(bloque, []):
			if p["id"] == id:
				return bloque
	return ""


# --- Estado ---

## Borra todo y genera un participante nuevo (nueva partida).
func reiniciar() -> void:
	participante_id = _codigo_nuevo()
	consentimiento_dado = false
	consentimiento_guardar = false
	pre = _fase_vacia()
	post = _fase_vacia()
	momento_inicio_juego = 0.0
	cuestionario_activo = false
	_semillas.clear()
	_exportado = false
	valoracion = {}


func _fase_vacia() -> Dictionary:
	return {"respuestas": {}, "puntajes": {}, "marca": 0.0, "completa": false}


func _codigo_nuevo() -> String:
	var azar := RandomNumberGenerator.new()
	azar.randomize()
	var codigo := ""
	for i in 6:
		codigo += ALFABETO[azar.randi() % ALFABETO.length()]
	return codigo


func _fase(fase: String) -> Dictionary:
	return pre if fase == "pre" else post


## true si el "pre" ya está hecho (así el onboarding no lo repite al cargar una partida).
func pre_completo() -> bool:
	return bool(pre.get("completa", false))


func post_completo() -> bool:
	return bool(post.get("completa", false))


## Empieza una fase ("pre" o "post"): borra sus respuestas anteriores y fija la semilla del barajado.
func iniciar_fase(fase: String) -> void:
	if not FASES.has(fase):
		push_warning("Evaluacion: fase '%s' no válida." % fase)
		return
	var vacia := _fase_vacia()
	if fase == "post":
		_exportado = false
	if fase == "pre":
		pre = vacia
	else:
		post = vacia
	# Una semilla distinta por fase (y por participante)
	_semillas[fase] = hash("%s|%s" % [participante_id, fase])


## Al terminar el "post" se exporta la fila al CSV (solo con consentimiento; ver Exportacion).
func _on_fase_terminada(fase: String) -> void:
	if fase == "post" and post_completo() and not _exportado:
		_exportado = true
		Exportacion.agregar_fila()


## true si el jugador ya envió su opinión sobre el juego.
func valoracion_enviada() -> bool:
	return not valoracion.is_empty()


## Guarda la valoración. Con consentimiento entra también en el CSV y en el JSON de sesión (si el "post" ya está
## hecho; si no, se exporta junto con su fila). Sin consentimiento NO se escribe nada.
func guardar_valoracion(datos: Dictionary) -> void:
	valoracion = datos
	if consentimiento_guardar and post_completo():
		Exportacion.actualizar_con_valoracion()


# --- Preguntas ---

## Las 16 preguntas de la fase, en orden: 7 trivia, 7 situaciones, 2 escala. Cada una:
## {id, bloque, emocion, texto, opciones: [{texto, indice_original}], explicacion}. En trivia y situaciones las
## opciones se barajan con la semilla de la fase; en las escalas van de 1 a 5 (indice_original = el valor).
func orden_para(fase: String) -> Array[Dictionary]:
	if not _semillas.has(fase):
		iniciar_fase(fase)
	var resultado: Array[Dictionary] = []
	for bloque in BLOQUES:
		for p in banco.get(bloque, []):
			var opciones: Array[Dictionary] = []
			if bloque == "escala":
				for valor in range(1, int(p["valores"]) + 1):
					opciones.append({"texto": str(valor), "indice_original": valor})
			else:
				for i in p["opciones"].size():
					opciones.append({"texto": str(p["opciones"][i]), "indice_original": i})
				var azar := RandomNumberGenerator.new()
				azar.seed = hash("%s|%s" % [_semillas[fase], p["id"]])
				for i in range(opciones.size() - 1, 0, -1):
					var j := azar.randi_range(0, i)
					var temporal := opciones[i]
					opciones[i] = opciones[j]
					opciones[j] = temporal
			resultado.append({
				"id": p["id"], "bloque": bloque, "emocion": str(p.get("emocion", "")), "texto": p["texto"],
				"opciones": opciones, "explicacion": str(p.get("explicacion", "")),
				"minimo": str(p.get("minimo", "")), "maximo": str(p.get("maximo", "")),
			})
	return resultado


## Anota una respuesta (el índice ORIGINAL de la opción; en escalas, el valor 1 a 5).
func registrar(fase: String, id: String, indice_original: int) -> void:
	_fase(fase)["respuestas"][id] = indice_original


# --- Puntajes ---

## Calcula los puntajes de la fase (trivia 0 a 7, situaciones 0 a 7, total 0 a 14, escala 2 a 10), pone la marca
## de tiempo y la da por completa si están todas las respuestas. Devuelve los puntajes.
func calcular(fase: String) -> Dictionary:
	var f := _fase(fase)
	var respuestas: Dictionary = f["respuestas"]
	var trivia := 0
	var situaciones := 0
	var escala := 0
	var contestadas := 0
	var total_preguntas := 0
	for bloque in BLOQUES:
		for p in banco.get(bloque, []):
			total_preguntas += 1
			if not respuestas.has(p["id"]):
				continue
			contestadas += 1
			var r := int(respuestas[p["id"]])
			if bloque == "trivia" and r == int(p["correcta"]):
				trivia += 1
			elif bloque == "situaciones" and r == int(p["correcta"]):
				situaciones += 1
			elif bloque == "escala":
				escala += r
	f["puntajes"] = {"trivia": trivia, "situaciones": situaciones, "total": trivia + situaciones, "escala": escala}
	f["marca"] = Time.get_unix_time_from_system()
	f["completa"] = total_preguntas > 0 and contestadas == total_preguntas
	if fase == "pre" and f["completa"] and momento_inicio_juego <= 0.0:
		momento_inicio_juego = f["marca"]
	return f["puntajes"]


## Puntaje de una pregunta concreta de la fase (1 si es sana o correcta; en escalas, el valor; -1 sin respuesta).
func puntaje_de(fase: String, id: String) -> int:
	var respuestas: Dictionary = _fase(fase)["respuestas"]
	if not respuestas.has(id):
		return -1
	var p := pregunta(id)
	if p.is_empty():
		return -1
	if bloque_de(id) == "escala":
		return int(respuestas[id])
	return 1 if int(respuestas[id]) == int(p["correcta"]) else 0


## Compara el "pre" con el "post": diferencias por bloque y por emoción, y la duración del juego.
## {por_bloque: {bloque: {pre, post, dif}}, por_emocion: {id: {trivia_pre, trivia_post, situacion_pre,
## situacion_post, dif}}, duracion_segundos, hay_pre, hay_post}
func comparar() -> Dictionary:
	var hay_pre := pre_completo()
	var hay_post := post_completo()
	var a: Dictionary = pre.get("puntajes", {})
	var b: Dictionary = post.get("puntajes", {})
	var por_bloque := {}
	for clave in ["trivia", "situaciones", "total", "escala"]:
		var antes := int(a.get(clave, 0))
		var despues := int(b.get(clave, 0))
		por_bloque[clave] = {"pre": antes, "post": despues, "dif": despues - antes}
	var por_emocion := {}
	for id in GameState.ids_emociones():
		var t_pre := maxi(puntaje_de("pre", "t_" + id), 0)
		var t_post := maxi(puntaje_de("post", "t_" + id), 0)
		var s_pre := maxi(puntaje_de("pre", "s_" + id), 0)
		var s_post := maxi(puntaje_de("post", "s_" + id), 0)
		por_emocion[id] = {"trivia_pre": t_pre, "trivia_post": t_post, "situacion_pre": s_pre, "situacion_post": s_post,
			"dif": (t_post + s_post) - (t_pre + s_pre)}
	var duracion := 0.0
	if momento_inicio_juego > 0.0 and float(post.get("marca", 0.0)) > 0.0:
		duracion = float(post["marca"]) - momento_inicio_juego
	return {"por_bloque": por_bloque, "por_emocion": por_emocion, "duracion_segundos": duracion,
		"hay_pre": hay_pre, "hay_post": hay_post}


# --- Guardado (dentro del guardado de GameState) ---

## Lo que va al archivo de guardado. Sin consentimiento NO se escriben respuestas ni puntajes.
func a_diccionario() -> Dictionary:
	var d := {
		"participante_id": participante_id,
		"consentimiento_dado": consentimiento_dado,
		"consentimiento_guardar": consentimiento_guardar,
		"pre_completo": pre_completo(),
	}
	if consentimiento_guardar:
		d["pre"] = pre
		d["post"] = post
		d["momento_inicio_juego"] = momento_inicio_juego
		if not valoracion.is_empty():
			d["valoracion"] = valoracion
	return d


## Restaura lo guardado, comprobando cada dato (un archivo dañado no rompe nada).
func desde_diccionario(d: Variant) -> void:
	if typeof(d) != TYPE_DICTIONARY:
		return
	var codigo := str(d.get("participante_id", ""))
	if codigo.length() == 6:
		participante_id = codigo
	consentimiento_dado = typeof(d.get("consentimiento_dado", false)) == TYPE_BOOL and d["consentimiento_dado"]
	consentimiento_guardar = typeof(d.get("consentimiento_guardar", false)) == TYPE_BOOL and d["consentimiento_guardar"]
	if consentimiento_guardar:
		pre = _fase_limpia(d.get("pre", null))
		post = _fase_limpia(d.get("post", null))
		momento_inicio_juego = float(d.get("momento_inicio_juego", 0.0)) if typeof(d.get("momento_inicio_juego", 0.0)) in [TYPE_INT, TYPE_FLOAT] else 0.0
		if typeof(d.get("valoracion", null)) == TYPE_DICTIONARY:
			valoracion = d["valoracion"]
	elif typeof(d.get("pre_completo", false)) == TYPE_BOOL and d["pre_completo"]:
		# Sin consentimiento no hay respuestas guardadas, pero se recuerda que el "pre" ya se hizo
		pre = _fase_vacia()
		pre["completa"] = true


func _fase_limpia(origen: Variant) -> Dictionary:
	var f := _fase_vacia()
	if typeof(origen) != TYPE_DICTIONARY:
		return f
	var respuestas: Variant = origen.get("respuestas", {})
	if typeof(respuestas) == TYPE_DICTIONARY:
		for id in respuestas:
			if not pregunta(str(id)).is_empty() and typeof(respuestas[id]) in [TYPE_INT, TYPE_FLOAT]:
				f["respuestas"][str(id)] = int(respuestas[id])
	f["marca"] = float(origen.get("marca", 0.0)) if typeof(origen.get("marca", 0.0)) in [TYPE_INT, TYPE_FLOAT] else 0.0
	f["completa"] = typeof(origen.get("completa", false)) == TYPE_BOOL and origen["completa"]
	f["puntajes"] = {}
	if not f["respuestas"].is_empty():
		var guardado_completa: bool = f["completa"]
		var guardada_marca: float = f["marca"]
		var sin_marca := guardada_marca
		# Los puntajes se recalculan desde las respuestas (así nunca quedan incoherentes)
		var temporal := _fase_vacia()
		temporal["respuestas"] = f["respuestas"]
		f["puntajes"] = _puntajes_de(temporal["respuestas"])
		f["completa"] = guardado_completa
		f["marca"] = sin_marca
	return f


func _puntajes_de(respuestas: Dictionary) -> Dictionary:
	var trivia := 0
	var situaciones := 0
	var escala := 0
	for bloque in BLOQUES:
		for p in banco.get(bloque, []):
			if not respuestas.has(p["id"]):
				continue
			var r := int(respuestas[p["id"]])
			if bloque == "trivia" and r == int(p["correcta"]):
				trivia += 1
			elif bloque == "situaciones" and r == int(p["correcta"]):
				situaciones += 1
			elif bloque == "escala":
				escala += r
	return {"trivia": trivia, "situaciones": situaciones, "total": trivia + situaciones, "escala": escala}
