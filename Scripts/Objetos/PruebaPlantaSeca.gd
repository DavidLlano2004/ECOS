extends Node2D
## Objeto de PRUEBA del grupo "calmable" (interfaz calmar()). Una planta seca que revive con el
## pulso de Calma. Solo para la arena PruebaHabilidades; dibujada con marcadores simples.

signal calmada

const SECA := Color("8a6a3c")
const VIVA := Color("5fae5a")

## 0 = seca y caída, 1 = viva y erguida.
var vida := 0.0:
	set(valor):
		vida = valor
		queue_redraw()

var _tween: Tween


func _ready() -> void:
	add_to_group("calmable")


## Interfaz del grupo "calmable": se llama cuando el anillo de Calma la alcanza.
func calmar() -> void:
	if vida >= 1.0 or (_tween != null and _tween.is_running()):
		return
	calmada.emit()
	_tween = create_tween()
	_tween.tween_property(self, "vida", 1.0, 0.9).set_trans(Tween.TRANS_SINE)


func _draw() -> void:
	var color := SECA.lerp(VIVA, vida)
	# Maceta
	draw_colored_polygon(PackedVector2Array([Vector2(-8, 0), Vector2(8, 0), Vector2(6, -10), Vector2(-6, -10)]), Color("a05a3a"))
	# Hojas: caídas cuando está seca, erguidas cuando está viva
	for i in 5:
		var lado := -1.0 if i % 2 == 0 else 1.0
		var apertura := lerpf(1.35, 0.35 + 0.18 * i, vida)  # radianes desde la vertical
		var largo := lerpf(10.0, 17.0, vida)
		var base := Vector2(0, -10)
		var direccion := Vector2(sin(apertura * lado), -cos(apertura))
		draw_line(base, base + direccion * largo, color, 2.0)
		draw_circle(base + direccion * largo, 1.8, color)
