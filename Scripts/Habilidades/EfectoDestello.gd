class_name EfectoDestello
extends Node2D
## Destello suave de una estrella de cuatro puntas que crece y se desvanece. Sirve para resaltar
## objetos (lo interactuable cercano al usar Revelar). Se borra solo.

const SEGUNDOS := 0.9

var color := Color("f4c77b")
var tamano := 12.0
var _progreso := 0.0:
	set(valor):
		_progreso = valor
		queue_redraw()


## Crea un destello en `posicion` (global) colgado de `padre`, que empieza tras `espera` segundos.
static func crear(padre: Node2D, posicion: Vector2, p_color: Color, espera: float = 0.0) -> void:
	var destello := EfectoDestello.new()
	destello.color = p_color
	destello.top_level = true
	destello.visible = false
	padre.add_child(destello)
	destello.global_position = posicion
	destello._empezar(espera)


func _empezar(espera: float) -> void:
	await get_tree().create_timer(espera, false).timeout
	visible = true
	var t := create_tween()
	t.tween_property(self, "_progreso", 1.0, SEGUNDOS).set_trans(Tween.TRANS_SINE)
	t.tween_callback(queue_free)


func _draw() -> void:
	var alfa := sin(_progreso * PI)  # sube y baja
	var largo := tamano * (0.5 + _progreso)
	draw_circle(Vector2.ZERO, largo * 0.35, Color(color, 0.35 * alfa))
	draw_line(Vector2(-largo, 0), Vector2(largo, 0), Color(color, 0.9 * alfa), 1.5, true)
	draw_line(Vector2(0, -largo), Vector2(0, largo), Color(color, 0.9 * alfa), 1.5, true)
	draw_line(Vector2(-largo, -largo) * 0.5, Vector2(largo, largo) * 0.5, Color(color, 0.5 * alfa), 1.0, true)
	draw_line(Vector2(-largo, largo) * 0.5, Vector2(largo, -largo) * 0.5, Color(color, 0.5 * alfa), 1.0, true)
