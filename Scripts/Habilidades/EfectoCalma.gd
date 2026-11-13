class_name EfectoCalma
extends Node2D
## Anillo azul suave que se expande desde el jugador, con gotitas. Se dibuja con _draw
## (sin imágenes) y se borra solo al terminar. Lo crea HabilidadCalma.

const AZUL_SUAVE := Color("9fc7ff")
const CANTIDAD_GOTAS := 16

var radio := 90.0
var segundos := 0.6
var color := Color("9fc7ff")
## 0 a 1: cuánto ha avanzado la expansión.
var progreso := 0.0:
	set(valor):
		progreso = valor
		queue_redraw()

var _azul: Color
var _angulos: Array[float] = []
var _alcances: Array[float] = []


func _ready() -> void:
	_azul = color.lerp(AZUL_SUAVE, 0.6)
	# Gotitas en posiciones fijas repartidas por el anillo
	for i in CANTIDAD_GOTAS:
		_angulos.append(TAU * i / CANTIDAD_GOTAS + randf_range(-0.15, 0.15))
		_alcances.append(randf_range(0.55, 1.0))
	var t := create_tween()
	t.tween_property(self, "progreso", 1.0, segundos).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_callback(queue_free)


func _draw() -> void:
	var r := radio * progreso
	var desvanecer := 1.0 - progreso * progreso
	# Relleno muy suave
	draw_circle(Vector2.ZERO, r, Color(_azul, 0.12 * desvanecer))
	# Anillo principal y un segundo anillo fino detrás
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 64, Color(_azul, 0.85 * desvanecer), 3.0, true)
	draw_arc(Vector2.ZERO, r * 0.82, 0.0, TAU, 48, Color(_azul, 0.4 * desvanecer), 1.5, true)
	# Gotitas que caen un poco mientras el anillo avanza
	for i in _angulos.size():
		var posicion := Vector2.from_angle(_angulos[i]) * r * _alcances[i] + Vector2(0.0, progreso * 14.0)
		var alfa := desvanecer * 0.9
		draw_circle(posicion + Vector2(0, 1), 1.8, Color(_azul, alfa))
		draw_colored_polygon(PackedVector2Array([
			posicion + Vector2(0, -4.5), posicion + Vector2(-1.7, 0), posicion + Vector2(1.7, 0)]),
			Color(_azul, alfa))
