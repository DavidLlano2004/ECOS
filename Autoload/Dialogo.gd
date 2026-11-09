extends Node
## Punto único para mostrar diálogos en ECOS (usa Dialogue Manager por debajo).
##
##   await Dialogo.mostrar(load("res://Dialogos/rabia.dialogue"), "start")
##   var elegida: int = await Dialogo.preguntar("¿Qué haces?", ["Opción A", "Opción B"])
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

const BALLOON := preload("res://Scenes/UI/DialogoBalloon.tscn")

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
	if not cancelable:
		_sin_cancelar -= 1
	_abiertos -= 1
	if _abiertos == 0:
		dialogo_cerrado.emit()
	return elegida


## Muestra unas líneas de texto sin archivo .dialogue y espera a que el jugador las lea.
## personaje: quién habla ("" = narrador). Evita ":" en las líneas del narrador y [ ], {{ }} en cualquiera.
## Devuelve Dialogo.CANCELADO si el jugador salió con ESC.
func mostrar_texto(personaje: String, lineas: Array) -> int:
	var guion := "~ start\n"
	for linea in lineas:
		guion += ("%s: %s\n" % [personaje, linea]) if personaje != "" else "%s\n" % linea
	var recurso: DialogueResource = DialogueManager.create_resource_from_text(guion)
	if recurso == null:
		push_error("Dialogo.mostrar_texto: no se pudo crear el diálogo con ese texto.")
		return -1
	return await mostrar(recurso, "start")


## Pregunta rápida sin archivo .dialogue: muestra un texto y botones.
## Devuelve el índice de la opción elegida (0, 1, 2...).
## Evita usar [ ], {{ }} o empezar con "-" o "=>" en los textos (son sintaxis de Dialogue Manager).
func preguntar(mensaje: String, opciones: Array) -> int:
	var guion := "~ start\n%s\n" % mensaje
	for opcion in opciones:
		guion += "- %s\n" % str(opcion)
	var recurso: DialogueResource = DialogueManager.create_resource_from_text(guion)
	if recurso == null:
		push_error("Dialogo.preguntar: no se pudo crear el diálogo con ese texto.")
		return -1
	return await mostrar(recurso, "start")
