class_name HabilidadVinculo
extends HabilidadBase
## Vínculo (Soledad): ESPACIO invoca o despide a una luciérnaga compañera (Companero.tscn).
## - Sin compañero: lo invoca.
## - Con compañero y el jugador cerca (a menos de 60 px) de una "placa_doble": lo envía a posarse
##   sobre ella. Se queda hasta que se vuelva a pulsar ESPACIO lejos de la placa, el jugador se
##   aleje más de 300 px o se cambie de época: entonces vuelve con el jugador.
## - Con compañero siguiendo al jugador y sin placa cerca: lo despide.
## Las placas dobles detectan al jugador y al compañero (grupos "player" y "companero").
## Cooldown de 1 s. La soledad sana es saber acompañarse y pedir compañía.

const ESCENA := preload("res://Scenes/Personajes/Companero.tscn")
const DISTANCIA_PLACA := 60.0

var _companero: Companero


func _init() -> void:
	id = "vinculo"
	cooldown = 1.0
	duracion = 0.0


func ejecutar(player: Player) -> bool:
	if _companero == null or not is_instance_valid(_companero) or _companero.is_queued_for_deletion():
		_invocar(player)
		return true
	var placa := _placa_cercana(player)
	if _companero.posado:
		if placa == null:
			_companero.volver_con_jugador()  # ESPACIO lejos de la placa: vuelve con el jugador
		elif placa != _companero.placa:
			_companero.posarse_en(placa)  # otra placa: se cambia a esa
		else:
			return false  # ya está posada en esta placa: nada que hacer
	elif placa != null:
		_companero.posarse_en(placa)
	else:
		_companero.despedir()
		_companero = null
		activa = false
	return true


func reiniciar() -> void:
	activa = false
	if _companero != null and is_instance_valid(_companero):
		_companero.queue_free()
	_companero = null


## El compañero actual (o null). Sirve para las pruebas.
func companero() -> Companero:
	return _companero if is_instance_valid(_companero) else null


func _invocar(player: Player) -> void:
	_companero = ESCENA.instantiate()
	# Cuelga del mismo nodo que el jugador, así se ordena con él y viaja entre épocas
	player.get_parent().add_child(_companero)
	_companero.iniciar(player)
	activa = true


## La placa doble más cercana al jugador a menos de DISTANCIA_PLACA px, o null.
func _placa_cercana(player: Player) -> Node2D:
	var mejor: Node2D = null
	var mejor_distancia := DISTANCIA_PLACA
	for nodo in player.get_tree().get_nodes_in_group("placa_doble"):
		if not (nodo is Node2D) or not nodo.is_visible_in_tree():
			continue
		var distancia := player.global_position.distance_to(nodo.global_position)
		if distancia <= mejor_distancia:
			mejor_distancia = distancia
			mejor = nodo
	return mejor
