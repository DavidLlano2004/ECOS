class_name CodigoResultados
extends RefCounted
## El código de resultados: una línea de texto que el jugador puede copiar y pegar en un formulario de Google
## (sin servidor). Nunca se escribe en ningún archivo: solo se muestra en pantalla y el jugador decide si lo comparte.
##
## Formato:  "ECOS1:" + base64 seguro para URL de (JSON compacto comprimido con DEFLATE) + CRC32 (8 hex)
## El CRC32 va al final y se calcula sobre el texto base64 (sin el prefijo): detecta códigos cortados o mal copiados.
## Para decodificar fuera del juego: tools/decodificar_codigos.py (zlib + base64 + zlib.crc32).
##
## Contenido (claves cortas para que el código mida menos de 600 caracteres):
##   v versión del formato · id participante · f fecha · g versión del juego · fin final (b, n, d) ·
##   i, a, ig, p integradas, atacadas, ignoradas y pendientes · d duración en minutos ·
##   pre y post: puntajes [trivia, situaciones, escala] · rp y rq: respuestas del pre y del post, una cifra por
##   pregunta en el orden del banco (índice ORIGINAL elegido; en escala, el valor 1 a 5; "-" si no hay) ·
##   val: la valoración numérica (u: u1..u6, n: nota, fr: frecuencia 0-2, s: SUS, sp: puntaje SUS), si existe.
## Los comentarios libres NO van en el código (el jugador los escribe en el formulario).

const PREFIJO := "ECOS1:"
const VERSION_FORMATO := 1
const RUTA_CONFIG := "res://Resources/config_formulario.json"
const FINALES := {"bueno": "b", "neutro": "n", "dificil": "d"}
const FRECUENCIAS := ["Nunca", "A veces", "Seguido"]

static var _tabla_crc: PackedInt64Array = PackedInt64Array()


## Los datos de la partida actual, en forma compacta.
static func datos_actuales() -> Dictionary:
	var comparacion := Evaluacion.comparar()
	var contar := {"integrada": 0, "atacada": 0, "ignorada": 0, "pendiente": 0}
	for id in GameState.ids_emociones():
		contar[GameState.estado.get(id, "pendiente")] += 1
	var d := {
		"v": VERSION_FORMATO,
		"id": Evaluacion.participante_id,
		"f": Time.get_datetime_string_from_system(false).substr(0, 16),
		"g": str(ProjectSettings.get_setting("application/config/version", "0")),
		"fin": FINALES.get(GameState.calcular_final(), "n"),
		"i": contar["integrada"], "a": contar["atacada"], "ig": contar["ignorada"], "p": contar["pendiente"],
		"d": snappedf(float(comparacion["duracion_segundos"]) / 60.0, 0.1),
		"pre": _puntajes("pre"),
		"post": _puntajes("post"),
		"rp": _respuestas("pre"),
		"rq": _respuestas("post"),
	}
	var v: Dictionary = Evaluacion.valoracion
	if not v.is_empty():
		var u := ""
		var respuestas_v: Dictionary = v.get("respuestas", {})
		for k in ["u1", "u2", "u3", "u4", "u5", "u6"]:
			u += str(int(respuestas_v.get(k, 0)))
		var s := ""
		var sus: Dictionary = v.get("sus", {})
		if sus.size() == 10:
			for i in range(1, 11):
				s += str(int(sus["s%d" % i]) - 1)   # 0 a 4 (una cifra)
		d["val"] = {
			"u": u, "n": int(v.get("nota", 0)),
			"fr": maxi(FRECUENCIAS.find(str(v.get("frecuencia", ""))), -1),
			"s": s, "sp": snappedf(float(v.get("sus_puntaje", -1.0)), 0.1),
		}
	return d


static func _puntajes(fase: String) -> Array:
	var p: Dictionary = Evaluacion._fase(fase).get("puntajes", {})
	return [int(p.get("trivia", 0)), int(p.get("situaciones", 0)), int(p.get("escala", 0))]


## Una cifra por pregunta del banco (trivia, situaciones, escala): el índice original elegido ("-" si no hay).
static func _respuestas(fase: String) -> String:
	var respuestas: Dictionary = Evaluacion._fase(fase)["respuestas"]
	var s := ""
	for bloque in Evaluacion.BLOQUES:
		for p in Evaluacion.banco.get(bloque, []):
			s += str(int(respuestas[p["id"]])) if respuestas.has(p["id"]) else "-"
	return s


## El código de la partida actual.
static func generar() -> String:
	return codificar(datos_actuales())


static func codificar(datos: Dictionary) -> String:
	var json := JSON.stringify(datos, "", false)   # compacto, sin espacios
	var crudo := json.to_utf8_buffer()
	var comprimido := crudo.compress(FileAccess.COMPRESSION_DEFLATE)
	var b64 := Marshalls.raw_to_base64(comprimido).replace("+", "-").replace("/", "_").replace("=", "")
	return PREFIJO + b64 + crc32_hex(b64.to_ascii_buffer())


## Decodifica un código. Devuelve {ok, error, datos}. Falla (ok = false) si el prefijo, el CRC o el contenido no cuadran.
static func decodificar(codigo: String) -> Dictionary:
	var texto := codigo.strip_edges()
	if not texto.begins_with(PREFIJO):
		return {"ok": false, "error": "Falta el prefijo ECOS1:", "datos": {}}
	var cuerpo := texto.substr(PREFIJO.length())
	if cuerpo.length() <= 8:
		return {"ok": false, "error": "El código está cortado", "datos": {}}
	var b64 := cuerpo.substr(0, cuerpo.length() - 8)
	var crc := cuerpo.substr(cuerpo.length() - 8).to_lower()
	if crc32_hex(b64.to_ascii_buffer()) != crc:
		return {"ok": false, "error": "El control de errores (CRC) no coincide: el código está cortado o mal copiado", "datos": {}}
	var relleno := (4 - b64.length() % 4) % 4
	var estandar := b64.replace("-", "+").replace("_", "/") + "=".repeat(relleno)
	var comprimido := Marshalls.base64_to_raw(estandar)
	var crudo := comprimido.decompress_dynamic(65536, FileAccess.COMPRESSION_DEFLATE)
	if crudo.is_empty():
		return {"ok": false, "error": "No se pudo descomprimir", "datos": {}}
	var datos: Variant = JSON.parse_string(crudo.get_string_from_utf8())
	if typeof(datos) != TYPE_DICTIONARY or int(datos.get("v", 0)) != VERSION_FORMATO:
		return {"ok": false, "error": "El contenido no es un código de ECOS válido", "datos": {}}
	return {"ok": true, "error": "", "datos": datos}


## CRC32 (el mismo de zlib.crc32 de Python) en 8 caracteres hexadecimales en minúsculas.
static func crc32_hex(bytes: PackedByteArray) -> String:
	if _tabla_crc.is_empty():
		_tabla_crc.resize(256)
		for n in 256:
			var c := n
			for _k in 8:
				c = (0xEDB88320 ^ (c >> 1)) if (c & 1) == 1 else (c >> 1)
			_tabla_crc[n] = c
	var crc := 0xFFFFFFFF
	for b in bytes:
		crc = _tabla_crc[(crc ^ b) & 0xFF] ^ (crc >> 8)
	crc = crc ^ 0xFFFFFFFF
	return "%08x" % (crc & 0xFFFFFFFF)


## La URL del formulario (Resources/config_formulario.json, campo "url"); "" si no está puesta.
static func url_formulario() -> String:
	if not FileAccess.file_exists(RUTA_CONFIG):
		return ""
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(RUTA_CONFIG))
	return str(d.get("url", "")).strip_edges() if typeof(d) == TYPE_DICTIONARY else ""
