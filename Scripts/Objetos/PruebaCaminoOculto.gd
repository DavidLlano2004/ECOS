extends Node2D
## Objeto de PRUEBA del grupo "oculto" (interfaz revelar(segundos)). Un puente escondido sobre un
## abismo: invisible y sin función hasta que Revelar lo muestra. Pasado el tiempo se desvanece,
## salvo que `permanente` sea true. También es un "soporte" del abismo (sostiene(punto)).

signal revelado
signal ocultado

@export var tamano := Vector2(88, 40)
## Si es true, una vez revelado se queda para siempre.
@export var permanente := false

## true mientras es visible y funcional.
var funcional := false

var _tween: Tween
var _version := 0


func _ready() -> void:
	add_to_group("oculto")
	add_to_group("soporte")
	modulate.a = 0.0


## Interfaz del grupo "oculto": Revelar lo llama con la duración en segundos.
func revelar(segundos: float = 6.0) -> void:
	_version += 1
	var esta := _version
	funcional = true
	revelado.emit()
	if _tween != null:
		_tween.kill()
	# Aparece con un destello dorado
	modulate = Color(2.2, 1.9, 1.2, 1.0)
	_tween = create_tween()
	_tween.tween_property(self, "modulate", Color.WHITE, 0.5)
	if permanente:
		return
	await get_tree().create_timer(segundos, false).timeout
	if esta != _version or not is_inside_tree():
		return  # se volvió a revelar mientras tanto
	funcional = false
	ocultado.emit()
	if _tween != null:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "modulate:a", 0.0, 0.8)


## ¿Sostiene este punto (global)? Solo mientras está revelado.
func sostiene(punto: Vector2) -> bool:
	return funcional and Rect2(global_position - tamano / 2.0, tamano).has_point(punto)


func _draw() -> void:
	var rect := Rect2(-tamano / 2.0, tamano)
	draw_rect(rect, Color("b99a6b"))
	draw_rect(rect, Color("f4c77b"), false, 2.0)
	for i in 5:  # tablas
		var x := rect.position.x + (i + 1) * tamano.x / 6.0
		draw_line(Vector2(x, rect.position.y), Vector2(x, rect.end.y), Color("7a5f3a"), 1.0)
