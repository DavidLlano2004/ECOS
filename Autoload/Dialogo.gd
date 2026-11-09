extends Node
## Punto único para mostrar diálogos en ECOS (usa Dialogue Manager por debajo).
##
##   await Dialogo.mostrar(load("res://Dialogos/rabia.dialogue"), "start")
##   var elegida: int = await Dialogo.preguntar("¿Qué haces?", ["Opción A", "Opción B"])

## Se emite cuando se abre el primer diálogo (el jugador se bloquea).
signal dialogo_abierto
## Se emite cuando se cierra el último diálogo abierto (el jugador se libera).
signal dialogo_cerrado

const BALLOON := preload("res://Scenes/UI/DialogoBalloon.tscn")

## Cuántos diálogos hay abiertos ahora mismo.
var _abiertos := 0


## true mientras haya algún diálogo en pantalla.
func hay_dialogo() -> bool:
	return _abiertos > 0


## Abre un archivo .dialogue con el balloon propio y espera a que termine.
## Devuelve la posición (0, 1, 2...) de la última respuesta elegida, o -1 si no hubo.
func mostrar(recurso_dialogo: DialogueResource, titulo: String = "start") -> int:
	if recurso_dialogo == null:
		push_error("Dialogo.mostrar: el recurso de diálogo es nulo.")
		return -1
	# Un .dialogue vacío (o sin ese título) haría fallar al addon: se avisa y se sigue
	if not recurso_dialogo.get_cues().has(titulo):
		push_warning("Dialogo.mostrar: '%s' no tiene el título '%s' (¿archivo vacío?)." % [recurso_dialogo.resource_path, titulo])
		return -1
	var balloon: DialogoBalloon = BALLOON.instantiate()
	add_child(balloon)
	_abiertos += 1
	if _abiertos == 1:
		dialogo_abierto.emit()
	balloon.start(recurso_dialogo, titulo)
	var elegida: int = await balloon.terminado
	_abiertos -= 1
	if _abiertos == 0:
		dialogo_cerrado.emit()
	return elegida


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
