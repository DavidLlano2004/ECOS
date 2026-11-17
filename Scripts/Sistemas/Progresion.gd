class_name Progresion
extends RefCounted
## Progresión del mundo: qué compuertas hay, qué emoción da la habilidad que abre cada una, dónde está
## cada zona y qué pista dar. Los datos y los textos están en Resources/Progresion.json (editables sin
## tocar código). Todo son funciones estáticas: no hace falta crear nada.
##
## Regla: las compuertas son TRES y forman un grafo sin ciclos (la emoción que da la habilidad siempre
## está en una zona libre o detrás de una compuerta que se abre con una habilidad anterior):
##   Culpa (libre) -> Reparar -> puente roto -> Rabia -> Impulso -> roca enorme -> Vergüenza
##   Miedo (libre) -> Visión  -> zarzal oscuro -> Ansiedad
## Tristeza, Soledad, Miedo, Culpa y la Puerta del Reflejo están siempre abiertas.

const RUTA := "res://Resources/Progresion.json"

static var _datos: Dictionary = {}


static func datos() -> Dictionary:
	if _datos.is_empty():
		var lectura: Variant = JSON.parse_string(FileAccess.get_file_as_string(RUTA))
		_datos = lectura if typeof(lectura) == TYPE_DICTIONARY else {"compuertas": [], "emociones": {}, "orden_libres": []}
	return _datos


## Todas las compuertas (lista de diccionarios del JSON).
static func compuertas() -> Array:
	return datos().get("compuertas", [])


## Los datos de una compuerta por id ({} si no existe).
static func compuerta(id: String) -> Dictionary:
	for c in compuertas():
		if c["id"] == id:
			return c
	return {}


static func direccion_zona(emocion_id: String) -> String:
	return str(datos().get("emociones", {}).get(emocion_id, {}).get("direccion_zona", ""))


static func _nombre(emocion_id: String) -> String:
	var d := GameState.obtener_datos(emocion_id)
	return d.nombre if d != null else emocion_id.capitalize()


## "Reparar", "Impulso"... a partir del id de habilidad.
static func nombre_habilidad(habilidad_id: String) -> String:
	var info: Dictionary = Habilidades.info(habilidad_id)
	return str(info.get("nombre", habilidad_id))


## El texto de pista de una compuerta cerrada. nivel: 1 insinúa, 2 nombra la emoción, 3 dice dónde está.
## Con la habilidad ya conseguida dice cómo usarla.
static func texto_pista(id: String, nivel: int) -> String:
	var c := compuerta(id)
	if c.is_empty():
		return ""
	if GameState.tiene_habilidad(c["habilidad_requerida"]):
		return str(c["pista_con"]).replace("{n}", str(Habilidades.indice_de(c["habilidad_requerida"]) + 1))
	var lista: Array = c["pistas_sin"]
	var texto: String = lista[clampi(nivel, 1, lista.size()) - 1]
	var estado: String = GameState.estado.get(c["emocion_que_la_da"], "pendiente")
	if nivel >= 2 and (estado == "atacada" or estado == "ignorada"):
		texto += " Todavía puedes volver a hablar con ella."
	return texto


## La siguiente cosa útil que puede hacer el jugador. Devuelve {texto, zona, compuerta, emocion}:
## `zona` es el nombre de la zona del mundo a la que apuntar ("Hub", "Culpa", "Final"...), `compuerta` el id
## de la compuerta (si el paso es abrirla) y `emocion` el id cuyo color se usa en la brújula.
## Prioridad: 1) emociones libres sin integrar; 2) abrir una compuerta con la habilidad que ya se tiene;
## 3) las zonas nuevas ya abiertas; 4) la Puerta del Reflejo.
static func siguiente_paso() -> Dictionary:
	# 1) Emociones libres sin integrar
	for id in datos().get("orden_libres", []):
		if GameState.estado.get(id, "pendiente") != "integrada":
			return _paso_emocion(id)
	# 2) Una compuerta cerrada cuya habilidad ya tenemos
	for c in compuertas():
		if not GameState.compuerta_esta_abierta(c["id"]) and GameState.tiene_habilidad(c["habilidad_requerida"]):
			return {"texto": c["guia_con"], "zona": "", "compuerta": c["id"], "emocion": c["emocion_que_la_da"]}
	# 3) Zonas nuevas ya abiertas
	for c in compuertas():
		var destino: String = c["zona_destino"]
		if GameState.compuerta_esta_abierta(c["id"]) and GameState.estado.get(destino, "pendiente") != "integrada":
			return _paso_emocion(destino, true)
	# 4) Todo hecho
	return {
		"texto": "Ya has recorrido todos los caminos. Cuando quieras, ve a la Puerta del Reflejo, al norte de la plaza. Te está esperando.",
		"zona": "Final", "compuerta": "", "emocion": "",
	}


static func _paso_emocion(id: String, zona_abierta: bool = false) -> Dictionary:
	var nombre := _nombre(id)
	var donde := direccion_zona(id)
	var texto := ""
	var estado: String = GameState.estado.get(id, "pendiente")
	if estado == "atacada" or estado == "ignorada":
		texto = "%s sigue esperando %s. Puedes volver a hablar con ella cuando quieras." % [nombre, donde]
	elif zona_abierta:
		texto = "El camino hacia %s ya está abierto. La encontrarás %s." % [nombre, donde]
	else:
		texto = "Aún no has escuchado a %s. La encontrarás %s." % [nombre, donde]
	return {"texto": texto, "zona": id.capitalize(), "compuerta": "", "emocion": id}
