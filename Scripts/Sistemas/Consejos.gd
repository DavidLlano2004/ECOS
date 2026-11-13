class_name Consejos
extends RefCounted
## Los consejos de las emociones ya integradas. Cuando el jugador le habla de nuevo a una emoción integrada
## (en el Pasado o en su forma aliada del Presente), la emoción le dice una frase de consejo distinta cada
## vez y le ofrece "Otro consejo" o "Gracias". Cancelar (ESC o "Ahora no") también cierra.
##
## Esta charla NO concede la habilidad ni repite el efecto de integración: solo habla.
## Las frases están en Resources/Consejos/<id>.json (12 por emoción, editables sin tocar código).
## Se elige al azar sin repetir las últimas RECIENTES mostradas de esa emoción, y GameState guarda cuáles
## ha visto el jugador (GameState.consejos_vistos) para que el diario las pueda listar.

const RUTA := "res://Resources/Consejos/%s.json"
const RECIENTES := 4
const OPCIONES := ["Otro consejo", "Gracias"]

static var _frases: Dictionary = {}     # id -> Array[String]
static var _recientes: Dictionary = {}  # id -> Array[int] (los últimos mostrados)


## Las frases de una emoción ([] si no existe el archivo).
static func frases(id: String) -> Array[String]:
	if not _frases.has(id):
		var lista: Array[String] = []
		if FileAccess.file_exists(RUTA % id):
			var json := JSON.new()
			if json.parse(FileAccess.get_file_as_string(RUTA % id)) == OK and typeof(json.data) == TYPE_DICTIONARY:
				for f in json.data.get("frases", []):
					lista.append(str(f))
		else:
			push_warning("Consejos: no existe %s" % (RUTA % id))
		_frases[id] = lista
	return _frases[id]


## Cuántos consejos hay en total (de todas las emociones).
static func total() -> int:
	var suma := 0
	for id in GameState.ids_emociones():
		suma += frases(id).size()
	return suma


## Elige el índice de un consejo al azar, sin repetir los últimos RECIENTES de esa emoción (-1 si no hay).
static func elegir(id: String) -> int:
	var cantidad := frases(id).size()
	if cantidad == 0:
		return -1
	var recientes: Array = _recientes.get(id, [])
	var candidatos: Array[int] = []
	for i in cantidad:
		if not recientes.has(i):
			candidatos.append(i)
	if candidatos.is_empty():   # con muy pocas frases: solo se evita repetir la última
		for i in cantidad:
			if recientes.is_empty() or i != recientes.back():
				candidatos.append(i)
	var elegido: int = candidatos[randi() % candidatos.size()]
	recientes.append(elegido)
	while recientes.size() > RECIENTES:
		recientes.pop_front()
	_recientes[id] = recientes
	return elegido


## Una charla de consejos con la emoción: una frase y "Otro consejo" / "Gracias", hasta que el jugador
## agradezca o cancele. Si cancela, la emoción se despide con su frase de cierre.
static func charlar(datos: EmocionData) -> void:
	var lista := frases(datos.id)
	if lista.is_empty():
		return
	while true:
		var indice := elegir(datos.id)
		GameState.marcar_consejo_visto(datos.id, indice)
		var elegida: int = await Dialogo.mostrar_texto(datos.nombre, lista[indice], OPCIONES)
		if elegida == 0:
			continue   # "Otro consejo"
		if Dialogo.cancelada:
			await Dialogo.despedida(datos.nombre, datos.frase_cierre)
		return
