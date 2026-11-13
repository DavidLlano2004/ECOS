extends Node2D
## Objeto de PRUEBA del grupo "reparable" (interfaz reparar()). Una vasija partida en dos que se
## une al repararla con la habilidad Reparar. Solo para la arena PruebaHabilidades.

signal reparado

## Radio del anillo de progreso del efecto de Reparar (propiedad opcional del grupo "reparable").
var radio_reparar := 22.0

## Cuánto separa la grieta las dos mitades (px). 0 = reparada.
var separacion := 5.0:
	set(valor):
		separacion = valor
		queue_redraw()

var _reparado := false


func _ready() -> void:
	add_to_group("reparable")


## Interfaz del grupo "reparable": se llama cuando termina de llenarse el anillo de Reparar.
func reparar() -> void:
	if _reparado:
		return
	_reparado = true
	remove_from_group("reparable")  # ya no hay nada que reparar aquí
	reparado.emit()
	create_tween().tween_property(self, "separacion", 0.0, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _draw() -> void:
	var color := Color("f4c77b") if _reparado else Color("7d7690")
	var oscuro := color.darkened(0.3)
	# Mitad izquierda y derecha de una vasija
	var izquierda := PackedVector2Array([Vector2(-1, -26), Vector2(-9, -26), Vector2(-13, -14), Vector2(-9, 0), Vector2(-1, 0)])
	var derecha := PackedVector2Array([Vector2(1, -26), Vector2(9, -26), Vector2(13, -14), Vector2(9, 0), Vector2(1, 0)])
	var s := separacion
	draw_colored_polygon(_mover(izquierda, Vector2(-s, 0)), color)
	draw_colored_polygon(_mover(derecha, Vector2(s, s * 0.4)), oscuro)
	if not _reparado:
		# Grieta en zigzag
		draw_polyline(PackedVector2Array([Vector2(0, -26), Vector2(-2, -18), Vector2(2, -10), Vector2(-1, -4), Vector2(0, 0)]), Color("2b2438"), 1.5)


func _mover(puntos: PackedVector2Array, desplazamiento: Vector2) -> PackedVector2Array:
	var resultado := PackedVector2Array()
	for p in puntos:
		resultado.append(p + desplazamiento)
	return resultado
