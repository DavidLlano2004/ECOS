class_name OclusionProps
extends Node
## Transparencia automática de los props altos (árboles y postes de luz): si el jugador, el Guía, una emoción o un objeto
## interactivo queda DETRÁS de su copa o su cuerpo (dentro del rectángulo visible del sprite y con una posición Y menor
## que la del prop), el prop baja al 45 % de opacidad con un fundido de 0.15 s, y vuelve a la normalidad cuando ya no
## tapa nada. Lo crea Mundo. Mira solo lo visible (la época oculta no cuenta).

const INTERVALO := 0.1
## Grupos de lo que no debe quedar tapado. Se toma un punto a media altura del cuerpo (unos 20 px sobre los pies).
const GRUPOS := ["player", "guia", "calmable", "aliadas_presente", "portales", "compuerta", "puerta_reflejo", "bloqueos_presente", "fragmentos", "cofres"]

var _tiempo := 0.0


func _process(delta: float) -> void:
	_tiempo += delta
	if _tiempo < INTERVALO:
		return
	_tiempo = 0.0
	actualizar()


## Recalcula qué props altos tapan algo y les pone o quita la transparencia.
func actualizar() -> void:
	var puntos: Array[Vector2] = []
	var pies: Array[float] = []
	for grupo in GRUPOS:
		for nodo in get_tree().get_nodes_in_group(grupo):
			if nodo is Node2D and nodo.is_visible_in_tree():
				puntos.append(nodo.global_position + Vector2(0, -20))
				pies.append(nodo.global_position.y)
	for prop in get_tree().get_nodes_in_group("props_altos"):
		if not (prop is Prop) or not prop.is_visible_in_tree():
			continue
		var rect: Rect2 = prop.rect_visible()
		var tapa := false
		for i in puntos.size():
			# "Detrás": sus pies están más arriba que la base del prop (Y menor)
			if pies[i] < prop.global_position.y and rect.has_point(puntos[i]):
				tapa = true
				break
		prop.poner_tapando(tapa)
