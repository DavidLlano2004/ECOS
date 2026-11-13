class_name Abismo
extends Node2D
## Un abismo o ravina que solo se cruza pisando un "soporte" (la PlataformaMovil o el CaminoOculto
## revelado). No hace daño ni hay game over: si el jugador entra sin apoyo, vuelve al último punto
## seguro con un aviso breve. Se dibuja por código (ARTE TEMPORAL: no hay arte del vacío todavía).
## Cada abismo cruza todo su recinto de pared a pared, así que no se puede rodear.
##
## Un soporte es cualquier nodo del grupo "soporte" con el método sostiene(punto_global) -> bool.

signal salvado

## Zona del abismo en coordenadas globales (px).
@export var zona := Rect2()

const AVISO := "Mejor no pisar el vacío."

var _ultimo_seguro := Vector2.INF
var _espera_aviso := 0.0


func _physics_process(delta: float) -> void:
	_espera_aviso = maxf(0.0, _espera_aviso - delta)
	var jugador := get_tree().get_first_node_in_group("player") as Player
	if jugador == null:
		return
	var punto := jugador.global_position
	if not zona.has_point(punto):
		_ultimo_seguro = punto
		return
	for soporte in get_tree().get_nodes_in_group("soporte"):
		if soporte.has_method("sostiene") and soporte.sostiene(punto):
			return
	# Sin apoyo: vuelve despacio al último punto seguro
	if _ultimo_seguro != Vector2.INF:
		jugador.terminar_impulso()  # si iba en pleno Impulso, se detiene
		jugador.global_position = _ultimo_seguro
		jugador.velocity = Vector2.ZERO
		salvado.emit()
		if _espera_aviso <= 0.0:
			_espera_aviso = 2.5
			if not Dialogo.hay_dialogo():
				Dialogo.mostrar_texto("Guía", AVISO, [], null, true)   # el mismo balloon que todo el juego


## ¿Está este punto (global) dentro del abismo?
func contiene(punto: Vector2) -> bool:
	return zona.has_point(punto)


func _draw() -> void:
	var local := Rect2(zona.position - global_position, zona.size)
	draw_rect(local, Color(0.03, 0.0, 0.07))
	for i in 5:  # profundidad: marcos cada vez más claros hacia los bordes
		draw_rect(local.grow(-i * 4.0), Color(0.07 + i * 0.012, 0.02, 0.12 + i * 0.02), false, 2.0)
	draw_rect(local, Color(0.4, 0.3, 0.55, 0.5), false, 2.0)
