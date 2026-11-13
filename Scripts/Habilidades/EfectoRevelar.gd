class_name EfectoRevelar
extends Node2D
## Onda de luz tipo espejo de la habilidad Revelar: un anillo dorado y blanco que se expande desde
## el jugador (hasta `radio` px) con reflejos diagonales como en un cristal. Se dibuja con _draw
## y se borra solo. Lo crea HabilidadRevelar.

const DORADO := Color("f4c77b")
const BRILLO := Color("fff4dc")
const CANTIDAD_REFLEJOS := 18

var radio := 220.0
var segundos := 0.8
## 0 a 1: cuánto ha avanzado la onda.
var progreso := 0.0:
	set(valor):
		progreso = valor
		queue_redraw()

var _angulos: Array[float] = []
var _profundidades: Array[float] = []


func _ready() -> void:
	for i in CANTIDAD_REFLEJOS:
		_angulos.append(TAU * i / CANTIDAD_REFLEJOS + randf_range(-0.12, 0.12))
		_profundidades.append(randf_range(0.04, 0.22))  # cuánto se quedan detrás del frente
	var t := create_tween()
	t.tween_property(self, "progreso", 1.0, segundos).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.tween_callback(queue_free)


func _draw() -> void:
	var r := radio * progreso
	var desvanecer := 1.0 - progreso * progreso
	# Velo suave de luz dentro de la onda
	draw_circle(Vector2.ZERO, r, Color(DORADO, 0.08 * desvanecer))
	# Frente de la onda: banda dorada con un filo blanco, como el canto de un espejo
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 72, Color(DORADO, 0.8 * desvanecer), 5.0, true)
	draw_arc(Vector2.ZERO, r - 1.5, 0.0, TAU, 72, Color(BRILLO, 0.9 * desvanecer), 1.5, true)
	# Reflejos diagonales detrás del frente
	for i in _angulos.size():
		var distancia := r * (1.0 - _profundidades[i])
		var punto := Vector2.from_angle(_angulos[i]) * distancia
		var destello := Vector2(1, -1).normalized() * (6.0 + 8.0 * _profundidades[i] * 4.0)
		draw_line(punto - destello, punto + destello, Color(BRILLO, 0.75 * desvanecer), 1.5, true)
