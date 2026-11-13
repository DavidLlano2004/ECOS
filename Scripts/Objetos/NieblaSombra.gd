class_name NieblaSombra
extends StaticBody2D
## Niebla oscura que llena la entrada de una cueva o un bosquecillo (acertijo de Visión). Grupo
## "sombra": interfaz visionar(activa). Con niebla es un muro sólido; con la Visión se disipa
## (quedan solo unos jirones lila y una luz cálida) y su colisión se apaga.
##
## Con `permanente` (lo normal en el mapa) la niebla, una vez disipada, ya no vuelve: así nadie
## queda encerrado dentro si apaga la Visión. Con `permanente = false` vuelve al apagarla y entonces
## usa contiene_punto() para que la Visión empuje al jugador fuera de la zona.
## Origen del nodo: el centro del hueco, a la altura de su base.

signal visionada(activa: bool)

## Ancho de la colisión (px). Debe cubrir todo el hueco que tapa.
@export var ancho_colision := 96.0
@export var permanente := true
## Alcance extra de la Visión sobre esta niebla (px): se suma a los 140 px normales.
var radio_sombra := 60.0

const ESPESOR := 40.0

@onready var _sprite: AnimatedSprite2D = $Sprite
@onready var _forma: CollisionShape2D = $Forma

var disipada := false
var _luz: PointLight2D
var _tween: Tween


func _ready() -> void:
	add_to_group("sombra")
	collision_layer = 1
	var rectangulo := RectangleShape2D.new()
	rectangulo.size = Vector2(ancho_colision, ESPESOR)
	_forma.shape = rectangulo
	_forma.position = Vector2(0, -ESPESOR / 2.0 + 8.0)
	# Luz cálida para el brillo de los jirones disueltos (apagada hasta que se disipa)
	_luz = PointLight2D.new()
	_luz.texture = Atmosfera.crear_textura_luz(128)
	_luz.texture_scale = 1.1
	_luz.color = Color("ffcf8a")
	_luz.energy = 0.0
	_luz.position = Vector2(0, -28)
	add_child(_luz)


## Interfaz del grupo "sombra": la Visión la abre (true) o la cierra (false).
func visionar(activa: bool) -> void:
	if activa == disipada:
		return
	if not activa and permanente:
		return  # una vez disipada se queda así
	disipada = activa
	Colisiones.apagar(_forma, activa)
	if _tween != null:
		_tween.kill()
	_tween = create_tween().set_parallel(true)
	if activa:
		# Los jirones lila se quedan, más tenues, con una luz cálida
		Sonido.efecto("niebla_disipa")
		_sprite.animation = &"resuelto"
		_sprite.modulate.a = 0.0
		_tween.tween_property(_sprite, "modulate:a", 0.9, 0.7)
		_tween.tween_property(_luz, "energy", 0.8, 0.7)
	else:
		_sprite.animation = &"inicial"
		_sprite.modulate.a = 0.0
		_tween.tween_property(_sprite, "modulate:a", 1.0, 0.5)
		_tween.tween_property(_luz, "energy", 0.0, 0.5)
	visionada.emit(activa)


## ¿Está el punto (global) dentro de la zona de la niebla, con un margen extra?
func contiene_punto(punto: Vector2, margen: float = 0.0) -> bool:
	if permanente and disipada:
		return false  # ya no volverá: no hay que sacar a nadie de aquí
	var rect := Rect2(global_position + Vector2(-ancho_colision / 2.0, -ESPESOR + 8.0), Vector2(ancho_colision, ESPESOR))
	return rect.grow(margen).has_point(punto)


## true si la colisión está activa ahora mismo (para las pruebas).
func bloquea() -> bool:
	return not disipada
