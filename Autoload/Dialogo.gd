extends Node
## Punto único para mostrar diálogos en ECOS (usa Dialogue Manager por debajo).
##
##   await Dialogo.mostrar(load("res://Dialogos/rabia.dialogue"), "start")
##   var elegida: int = await Dialogo.mostrar_texto("Rabia", "¿Qué haces?", ["Opción A", "Opción B"])
##
## Una escena puede pasarse a sí misma como estado extra para que el .dialogue llame a sus funciones:
##   await Dialogo.mostrar(recurso, "start", [self])   # y en el .dialogue:  $> mostrar_emocion("rabia")

## Lo que devuelve mostrar() si el jugador canceló la conversación ("Ahora no" o ESC).
## Cancelar NO es una decisión del juego: el que llama no debe cambiar ningún estado.
const CANCELADO := -2

## Se emite cuando se abre el primer diálogo (el jugador se bloquea).
signal dialogo_abierto
## Se emite cuando se cierra el último diálogo abierto (el jugador se libera).
signal dialogo_cerrado
## Un personaje empieza a "hablar": se está escribiendo su línea ("" si es el narrador).
signal linea_escribiendo(personaje: String)
## Terminó de escribirse la línea (ahora se espera al jugador).
signal linea_terminada
## Se escribió una letra (la usa el audio para los "blips"): quién habla ("" = narrador) y la letra.
signal letra_escrita(personaje: String, letra: String)
## Aparecieron las opciones de respuesta, el jugador eligió una, o canceló la conversación.
signal opciones_mostradas
signal respuesta_elegida
signal cancelado_por_jugador

const BALLOON := preload("res://Scenes/UI/DialogoBalloon.tscn")

## Segundos que tarda en escribirse cada letra: UNA sola velocidad para todo el juego (el balloon la usa).
const SEGUNDOS_POR_LETRA := 0.03

## true si la última conversación terminó porque el jugador canceló (ESC o "Ahora no"). Se actualiza en mostrar().
var cancelada := false

## SOLO PARA PRUEBAS automáticas: si no es -99, mostrar_texto() no abre nada y devuelve al instante esa opción
## (limitada a las que haya; -1 si no hay opciones). Nunca se toca en el juego.
var respuesta_de_prueba := -99

## Retratos opcionales por nombre de personaje, para que el balloon los muestre a la izquierda.
## Ejemplo: Dialogo.retratos["Guía"] = textura. (Quien lo registre debe quitarlo al terminar.)
var retratos: Dictionary = {}

## Cuántos diálogos hay abiertos ahora mismo.
var _abiertos := 0
## Cuántos de los abiertos NO se pueden cancelar (el cuestionario de entrada y el de salida).
var _sin_cancelar := 0


## true mientras haya algún diálogo en pantalla.
func hay_dialogo() -> bool:
	return _abiertos > 0


## false mientras haya un diálogo que no se puede cancelar (cuestionarios). El menú de pausa
## (cuando exista) debe consultar esto antes de abrirse.
func pausa_permitida() -> bool:
	return _sin_cancelar == 0


## Abre un archivo .dialogue con el balloon propio y espera a que termine.
## estados_extra: objetos cuyas funciones y propiedades puede usar el .dialogue.
## cancelable: si es true (lo normal) el jugador puede salir con "Ahora no" o con ESC; entonces
## devuelve Dialogo.CANCELADO. Los cuestionarios (onboarding y final) deben pasar false.
## Devuelve la posición (0, 1, 2...) de la última respuesta elegida, -1 si no hubo, o CANCELADO.
func mostrar(recurso_dialogo: DialogueResource, titulo: String = "start", estados_extra: Array = [], cancelable: bool = true) -> int:
	if recurso_dialogo == null:
		push_error("Dialogo.mostrar: el recurso de diálogo es nulo.")
		return -1
	# Un .dialogue vacío (o sin ese título) haría fallar al addon: se avisa y se sigue
	if not recurso_dialogo.get_cues().has(titulo):
		push_warning("Dialogo.mostrar: '%s' no tiene el título '%s' (¿archivo vacío?)." % [recurso_dialogo.resource_path, titulo])
		return -1
	var balloon: DialogoBalloon = BALLOON.instantiate()
	add_child(balloon)
	balloon.escribiendo_iniciado.connect(linea_escribiendo.emit)
	balloon.escribiendo_terminado.connect(linea_terminada.emit)
	balloon.cancelable = cancelable
	if not cancelable:
		_sin_cancelar += 1
	_abiertos += 1
	if _abiertos == 1:
		dialogo_abierto.emit()
	balloon.start(recurso_dialogo, titulo, estados_extra)
	var elegida: int = await balloon.terminado
	cancelada = elegida == CANCELADO
	if not cancelable:
		_sin_cancelar -= 1
	_abiertos -= 1
	if _abiertos == 0:
		dialogo_cerrado.emit()
	return elegida


## Muestra un texto con el mismo balloon que todo el juego (misma velocidad de escritura, mismo blip por
## letra, misma etiqueta de nombre y mismo aviso "Mantén ESC para salir"). Es la forma de mostrar cualquier
## mensaje que no venga de un archivo .dialogue.
##
##   await Dialogo.mostrar_texto("Rabia", "Hola.")                          un texto
##   await Dialogo.mostrar_texto("Guía", ["Primera.", "Segunda."])          varias páginas seguidas
##   var i := await Dialogo.mostrar_texto("Rabia", "¿Y ahora?", ["Otro", "Gracias"])   con opciones
##
## nombre: lo que sale en la etiqueta ("" = narrador, sin etiqueta). texto: un String o una lista de páginas.
## opciones: botones de respuesta (aparecen tras el último texto). retrato: imagen opcional a la izquierda.
## automatico: el texto se cierra solo tras leerse (para despedidas y pistas breves; no con opciones).
## Devuelve el índice de la opción elegida (0, 1...) o -1 si no se eligió nada o se canceló (ESC o "Ahora no").
## Para distinguir cancelar de terminar, mira Dialogo.cancelada justo después de esperar.
func mostrar_texto(nombre: String, texto: Variant, opciones: Array = [], retrato: Texture2D = null, automatico: bool = false) -> int:
	if respuesta_de_prueba != -99:
		await get_tree().process_frame
		return mini(respuesta_de_prueba, opciones.size() - 1) if not opciones.is_empty() else -1
	var paginas: Array = texto if texto is Array else [texto]
	var guion := "~ start\n"
	for pagina in paginas:
		var linea := _limpiar(str(pagina))
		if nombre != "":
			linea = "%s: %s" % [nombre, linea]
		if automatico and opciones.is_empty():
			linea += " [next=auto]"
		guion += linea + "\n"
	for opcion in opciones:
		guion += "- %s\n" % _limpiar(str(opcion))
	var recurso: DialogueResource = DialogueManager.create_resource_from_text(guion)
	if recurso == null:
		push_error("Dialogo.mostrar_texto: no se pudo crear el diálogo con ese texto.")
		return -1
	var puso_retrato := retrato != null and nombre != ""
	if puso_retrato:
		retratos[nombre] = retrato
	var elegida := await mostrar(recurso, "start")
	if puso_retrato:
		retratos.erase(nombre)
	return elegida if elegida >= 0 else -1


## Escribe un texto en una etiqueta letra por letra, con la misma velocidad (SEGUNDOS_POR_LETRA) y el mismo blip que el
## balloon. Lo usan las pantallas con texto escrito a mano (cuestionarios, valoración).
func escribir_etiqueta(etiqueta: Label, texto: String) -> void:
	etiqueta.text = texto
	etiqueta.visible_characters = 0
	for i in texto.length():
		if not is_instance_valid(etiqueta):
			return
		etiqueta.visible_characters = i + 1
		letra_escrita.emit("", texto[i])
		await get_tree().create_timer(SEGUNDOS_POR_LETRA, true, false, true).timeout
	if is_instance_valid(etiqueta):
		etiqueta.visible_characters = -1
	linea_terminada.emit()


## Despedida breve (frase_cierre) cuando el jugador cancela una conversación: el mismo balloon, que se cierra solo.
func despedida(nombre: String, frase: String) -> void:
	if frase != "":
		await mostrar_texto(nombre, frase, [], null, true)


## Quita lo que Dialogue Manager entendería como sintaxis: [ ], {{ }} y los saltos de línea.
func _limpiar(texto: String) -> String:
	return texto.replace("{{", "{").replace("}}", "}").replace("[", "(").replace("]", ")").replace("\n", " ").strip_edges()
