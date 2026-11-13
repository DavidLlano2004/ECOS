extends StaticBody2D
## Objeto de PRUEBA del grupo "sombra" (interfaz visionar(activa)). Una zona cubierta de niebla
## oscura que bloquea el paso. Con la Visión se disipa y su colisión se desactiva.
## Opcional pero necesario para la salida suave de Visión: contiene_punto(punto, margen) y radio_sombra.

signal visionada(activa: bool)

## Tamaño de la zona (px), centrada en el origen del nodo.
@export var tamano := Vector2(60, 80)
## Alcance extra de la Visión sobre esta zona (px): se suma a los 140 px normales.
var radio_sombra := 50.0

var _forma: CollisionShape2D
var _niebla: Control
var _tween: Tween


func _ready() -> void:
	add_to_group("sombra")
	collision_layer = 1
	_forma = CollisionShape2D.new()
	var rectangulo := RectangleShape2D.new()
	rectangulo.size = tamano
	_forma.shape = rectangulo
	add_child(_forma)
	# Niebla: un velo oscuro con la textura de niebla del juego por encima
	_niebla = Control.new()
	_niebla.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_niebla.z_index = 4
	var velo := ColorRect.new()
	velo.color = Color(0.05, 0.02, 0.1, 0.88)
	velo.size = tamano
	velo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_niebla.add_child(velo)
	_niebla.add_child(Atmosfera.crear_niebla(Vector2.ZERO, tamano, 0.8, 0.1))
	_niebla.position = -tamano / 2.0
	add_child(_niebla)


## Interfaz del grupo "sombra": la Visión la abre (true) o la cierra (false).
func visionar(activa: bool) -> void:
	_forma.set_deferred("disabled", activa)
	if _tween != null:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(_niebla, "modulate:a", 0.12 if activa else 1.0, 0.45)
	visionada.emit(activa)


## ¿Está el punto (global) dentro de la zona, con un margen extra? La Visión lo usa para no
## cerrar la zona con el jugador dentro y para buscar el punto libre más cercano.
func contiene_punto(punto: Vector2, margen: float = 0.0) -> bool:
	return Rect2(global_position - tamano / 2.0, tamano).grow(margen).has_point(punto)


## true si la colisión está activa ahora mismo.
func bloquea() -> bool:
	return not _forma.disabled
