class_name EspejoFinal
extends Node2D
## El gran espejo de la secuencia final: un marco ornamentado dibujado por código, con el mismo fondo oscuro y
## el brillo dorado de la interfaz. Origen: el centro del espejo. `brillo` (0 a 1) es cuánta luz tiene el cristal.

const ANCHO := 136.0
const ALTO := 170.0
const DORADO := Color("f4c77b")
const DORADO_OSCURO := Color("a8793a")
const CRISTAL := Color("14102a")

var brillo := 0.35:
	set(valor):
		brillo = valor
		queue_redraw()
var _tiempo := 0.0


func _process(delta: float) -> void:
	_tiempo += delta
	queue_redraw()


func _draw() -> void:
	var mitad := Vector2(ANCHO, ALTO) / 2.0
	# Resplandor dorado alrededor
	for i in 5:
		draw_rect(Rect2(-mitad - Vector2(1, 1) * (4 + i * 5), Vector2(ANCHO, ALTO) + Vector2(2, 2) * (4 + i * 5)), Color(DORADO, 0.05 * brillo))
	# Marco: capas de oro y sombra
	draw_rect(Rect2(-mitad - Vector2(10, 10), Vector2(ANCHO, ALTO) + Vector2(20, 20)), DORADO_OSCURO)
	draw_rect(Rect2(-mitad - Vector2(8, 8), Vector2(ANCHO, ALTO) + Vector2(16, 16)), DORADO)
	draw_rect(Rect2(-mitad - Vector2(5, 5), Vector2(ANCHO, ALTO) + Vector2(10, 10)), DORADO_OSCURO.darkened(0.3))
	draw_rect(Rect2(-mitad - Vector2(3, 3), Vector2(ANCHO, ALTO) + Vector2(6, 6)), DORADO.lightened(0.2))
	# Cristal: oscuro, con un degradado y un brillo que respira
	draw_rect(Rect2(-mitad, Vector2(ANCHO, ALTO)), CRISTAL)
	var respiro := 0.5 + 0.5 * sin(_tiempo * 1.5)
	for i in 8:
		var f := float(i) / 8.0
		draw_rect(Rect2(-mitad + Vector2(1, 1) * f * 18.0, Vector2(ANCHO, ALTO) - Vector2(2, 2) * f * 18.0), Color(0.5, 0.45, 0.9, (0.05 + 0.05 * respiro) * brillo * (1.0 - f)), false, 2.0)
	# Reflejos diagonales
	draw_colored_polygon(PackedVector2Array([Vector2(-mitad.x, -mitad.y + 40), Vector2(-mitad.x + 30, -mitad.y), Vector2(-mitad.x + 46, -mitad.y), Vector2(-mitad.x, -mitad.y + 62)]), Color(1, 1, 1, 0.07 + 0.05 * brillo))
	draw_colored_polygon(PackedVector2Array([Vector2(mitad.x - 50, mitad.y), Vector2(mitad.x, mitad.y - 50), Vector2(mitad.x, mitad.y - 36), Vector2(mitad.x - 36, mitad.y)]), Color(1, 1, 1, 0.05 + 0.04 * brillo))
	# Adornos: remates en las cuatro esquinas y una corona arriba
	for esquina in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
		var p: Vector2 = esquina * (mitad + Vector2(9, 9))
		draw_circle(p, 8.0, DORADO_OSCURO)
		draw_circle(p, 6.0, DORADO)
		draw_circle(p, 2.5, Color("fff4dc", 0.9))
	var corona := Vector2(0, -mitad.y - 12)
	draw_colored_polygon(PackedVector2Array([corona + Vector2(-22, 6), corona + Vector2(-12, -8), corona + Vector2(0, 4), corona + Vector2(12, -8), corona + Vector2(22, 6)]), DORADO)
	draw_circle(corona + Vector2(0, -6), 4.0, Color("fff4dc", 0.6 + 0.4 * respiro))
