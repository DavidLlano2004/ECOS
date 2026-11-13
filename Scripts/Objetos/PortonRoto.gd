class_name PortonRoto
extends StaticBody2D
## Portón roto que cierra un recinto (acertijo de Reparar). Grupo "reparable": interfaz reparar().
## Roto es sólido; al repararlo se ve entero con su lazo dorado, se abre y su colisión desaparece
## para siempre. Origen del nodo: la base del portón.

signal reparado

## Ancho de la colisión (px). Debe cubrir todo el hueco que cierra.
@export var ancho_colision := 64.0
## Tamaño del anillo de progreso de Reparar (propiedad opcional del grupo "reparable").
var radio_reparar := 26.0

@onready var _sprite: AnimatedSprite2D = $Sprite
@onready var _forma: CollisionShape2D = $Forma

var _reparado := false


func _ready() -> void:
	add_to_group("reparable")
	collision_layer = 1
	var rectangulo := RectangleShape2D.new()
	rectangulo.size = Vector2(ancho_colision, 24.0)
	_forma.shape = rectangulo
	_forma.position = Vector2(0, -2)


## Interfaz del grupo "reparable": Reparar la llama al completar el anillo.
func reparar() -> void:
	if _reparado:
		return
	_reparado = true
	remove_from_group("reparable")  # ya no hay nada que reparar aquí
	Colisiones.apagar(_forma, true)
	_sprite.animation = &"resuelto"   # entero, con el lazo dorado
	Sonido.efecto("porton_repara")
	reparado.emit()
	# Se ve entero un momento y luego sus hojas se abren
	var t := create_tween()
	t.tween_property(_sprite, "modulate", Color(1.8, 1.5, 1.0), 0.15)
	t.tween_property(_sprite, "modulate", Color.WHITE, 0.4)
	t.tween_interval(0.5)
	t.tween_property(_sprite, "scale:x", 0.08, 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	t.parallel().tween_property(_sprite, "modulate:a", 0.0, 0.6)
