extends StaticBody2D
## Objeto de PRUEBA: una reja sólida que se abre mientras las dos placas dobles están ocupadas
## (una por el jugador y otra por el compañero). La arena PruebaHabilidades la conecta por señales.

@export var tamano := Vector2(90, 14)

var abierta := false

var _forma: CollisionShape2D
var _tween: Tween


func _ready() -> void:
	collision_layer = 1
	_forma = CollisionShape2D.new()
	var rectangulo := RectangleShape2D.new()
	rectangulo.size = tamano
	_forma.shape = rectangulo
	add_child(_forma)


func abrir() -> void:
	_poner(true)


func cerrar() -> void:
	_poner(false)


func _poner(valor: bool) -> void:
	if valor == abierta:
		return
	abierta = valor
	_forma.set_deferred("disabled", valor)
	if _tween != null:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "modulate:a", 0.2 if valor else 1.0, 0.3)


func _draw() -> void:
	var rect := Rect2(-tamano / 2.0, tamano)
	draw_rect(rect, Color(0.25, 0.22, 0.34))
	for i in 7:
		var x := rect.position.x + (i + 0.5) * tamano.x / 7.0
		draw_line(Vector2(x, rect.position.y - 8.0), Vector2(x, rect.end.y + 2.0), Color("c9bfe0"), 2.0)
