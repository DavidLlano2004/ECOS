class_name RocaRompible
extends StaticBody2D
## Roca que tapa un nicho (acertijo de Impulso). Grupo "rompible": interfaz romper().
## Es sólida (capa 1, mundo) hasta que el Impulso la toca; entonces se rompe en pedazos y el
## paso queda libre para siempre. Origen del nodo: la base de la roca.

signal rota

## Ancho de la colisión (px). Debe cubrir todo el hueco que tapa.
@export var ancho_colision := 64.0

@onready var _sprite: AnimatedSprite2D = $Sprite
@onready var _forma: CollisionShape2D = $Forma

var _rota := false


func _ready() -> void:
	add_to_group("rompible")
	collision_layer = 1
	var rectangulo := RectangleShape2D.new()
	rectangulo.size = Vector2(ancho_colision, 24.0)
	_forma.shape = rectangulo
	_forma.position = Vector2(0, -2)


## Interfaz del grupo "rompible": el Impulso la llama al tocarla.
func romper() -> void:
	if _rota:
		return
	_rota = true
	remove_from_group("rompible")
	Colisiones.apagar(_forma, true)
	_sprite.animation = &"resuelto"  # los pedazos en el suelo
	Sonido.efecto("roca_rompe")
	_lanzar_pedazos()
	var t := create_tween()
	t.tween_property(_sprite, "scale", _sprite.scale * 1.06, 0.06)
	t.tween_property(_sprite, "scale", _sprite.scale, 0.12)
	rota.emit()


func _lanzar_pedazos() -> void:
	var p := CPUParticles2D.new()
	p.position = Vector2(0, -14)
	p.amount = 16
	p.one_shot = true
	p.explosiveness = 1.0
	p.lifetime = 0.7
	p.spread = 180.0
	p.direction = Vector2.UP
	p.gravity = Vector2(0, 140)
	p.initial_velocity_min = 40.0
	p.initial_velocity_max = 120.0
	p.scale_amount_min = 2.0
	p.scale_amount_max = 3.5
	var degradado := Gradient.new()
	degradado.set_color(0, Color("e8a14a"))  # brasas de la roca
	degradado.set_color(1, Color(0.45, 0.4, 0.5, 0.0))
	p.color_ramp = degradado
	add_child(p)
	p.emitting = true
	get_tree().create_timer(1.0).timeout.connect(p.queue_free)
