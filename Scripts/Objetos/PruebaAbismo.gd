extends Node2D
## Objeto de PRUEBA: un abismo que solo se cruza pisando un "soporte" (la plataforma móvil o el
## camino oculto revelado). No hace daño ni hay game over: si el jugador entra sin apoyo, vuelve
## despacio al último punto seguro con un aviso. Solo para la arena PruebaHabilidades.

signal salvado

## Zona del abismo en coordenadas globales.
@export var zona := Rect2(812, 300, 388, 80)

var _ultimo_seguro := Vector2.INF
var _bloqueo_aviso := 0.0


func _physics_process(delta: float) -> void:
	_bloqueo_aviso = maxf(0.0, _bloqueo_aviso - delta)
	var jugador: Player = get_tree().get_first_node_in_group("player")
	if jugador == null:
		return
	var punto := jugador.global_position
	if not zona.has_point(punto):
		_ultimo_seguro = punto
		return
	# Dentro del abismo: se puede estar solo sobre un soporte
	for soporte in get_tree().get_nodes_in_group("soporte"):
		if soporte.has_method("sostiene") and soporte.sostiene(punto):
			return
	if _ultimo_seguro != Vector2.INF:
		jugador.global_position = _ultimo_seguro
		jugador.velocity = Vector2.ZERO
		salvado.emit()
		if _bloqueo_aviso <= 0.0:
			_bloqueo_aviso = 2.0
			if not Dialogo.hay_dialogo():
				Dialogo.mostrar_texto("Guía", "Mejor no pisar el vacío.", [], null, true)


func _draw() -> void:
	var local := Rect2(zona.position - global_position, zona.size)
	draw_rect(local, Color(0.02, 0.0, 0.05))
	for i in 5:  # profundidad
		draw_rect(local.grow(-i * 5.0), Color(0.07 + i * 0.01, 0.02, 0.12 + i * 0.015), false, 1.0)
