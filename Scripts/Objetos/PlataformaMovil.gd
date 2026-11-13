class_name PlataformaMovil
extends Node2D
## Plataforma que va de lado a lado sobre un abismo (acertijo de Pausa). Grupo "tiempo": multiplica su
## delta por Habilidades.factor_tiempo. El abismo no se puede cruzar a pie: solo subido a ella.
## Con su velocidad normal es demasiado rápida para subirse; con Pausa se ralentiza lo bastante
## (por debajo de VELOCIDAD_ABORDAJE) y se puede subir. Una vez a bordo, lleva al jugador hasta que
## sale de ella (aunque la Pausa termine mientras cruza).
##
## La "colisión" (el sitio donde se pisa) está solo en la parte de arriba del sprite, el disco, a lo
## largo de toda la franja del abismo; la niebla que se ve debajo del disco no tiene colisión.
## Es también un "soporte" del abismo (sostiene(punto)).
## Origen del nodo: el borde de arriba de la franja del abismo / del disco (así el jugador, cuyo
## origen son los pies, siempre se dibuja por encima).

## Límites del recorrido del CENTRO de la plataforma en x (px globales) y velocidad (px/s).
@export var x_min := 0.0
@export var x_max := 0.0
@export var velocidad := 150.0
## Tamaño del sitio donde se pisa (px). El alto es el de la franja del abismo.
@export var ancho_soporte := 94.0
@export var alto_soporte := 64.0

## Por encima de esta velocidad (px/s) no se puede subir.
const VELOCIDAD_ABORDAJE := 90.0

var _recorrido := 0.0
var _a_bordo := false


func _ready() -> void:
	add_to_group("tiempo")
	add_to_group("soporte")
	if x_max > x_min:
		_recorrido = 0.5 * (x_max - x_min)
		global_position.x = x_min + pingpong(_recorrido, x_max - x_min)


## Velocidad real ahora mismo (px/s), con el factor de tiempo de Pausa.
func velocidad_actual() -> float:
	return velocidad * Habilidades.factor_tiempo


func _physics_process(delta: float) -> void:
	if x_max <= x_min:
		return
	var jugador := get_tree().get_first_node_in_group("player") as Player
	var lleva_al_jugador := jugador != null and sostiene(jugador.global_position)
	var antes := global_position.x
	_recorrido += velocidad * delta * Habilidades.factor_tiempo   # el tiempo del mundo, no el del jugador
	global_position.x = x_min + pingpong(_recorrido, x_max - x_min)
	if lleva_al_jugador:
		jugador.move_and_collide(Vector2(global_position.x - antes, 0.0))


## ¿Puede el punto (global) estar sobre la plataforma? Entrar solo se puede si va despacio.
func sostiene(punto: Vector2) -> bool:
	var rect := Rect2(global_position + Vector2(-ancho_soporte / 2.0, -3.0), Vector2(ancho_soporte, alto_soporte + 6.0))
	if not rect.has_point(punto):
		_a_bordo = false
		return false
	if _a_bordo:
		return true
	if velocidad_actual() <= VELOCIDAD_ABORDAJE:
		_a_bordo = true
		return true
	return false  # demasiado rápida para subirse
