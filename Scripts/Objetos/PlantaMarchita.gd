class_name PlantaMarchita
extends StaticBody2D
## Planta seca que cierra la entrada de un jardín (acertijo de Calma). Grupo "calmable":
## interfaz calmar(). Seca es un obstáculo sólido; al calmarla florece, deja una pequeña luz y su
## colisión desaparece para siempre. Se ponen varias juntas para cerrar todo el hueco.
## Origen del nodo: la base de la planta.

signal florecio

@export var radio_colision := 17.0

@onready var _sprite: AnimatedSprite2D = $Sprite
@onready var _forma: CollisionShape2D = $Forma

var florecida := false
var _luz: PointLight2D


func _ready() -> void:
	add_to_group("calmable")
	collision_layer = 1
	var circulo := CircleShape2D.new()
	circulo.radius = radio_colision
	_forma.shape = circulo
	_forma.position = Vector2(0, -8)


## Interfaz del grupo "calmable": el anillo de Calma la alcanza.
func calmar() -> void:
	if florecida:
		return
	florecida = true
	remove_from_group("calmable")
	Colisiones.apagar(_forma, true)
	_sprite.animation = &"resuelto"
	Sonido.efecto("planta_florece")
	# Pequeña luz rosada que se queda encendida
	_luz = PointLight2D.new()
	_luz.texture = Atmosfera.crear_textura_luz(128)
	_luz.texture_scale = 0.7
	_luz.color = Color("ff9ec4")
	_luz.energy = 0.0
	_luz.position = Vector2(0, -18)
	add_child(_luz)
	create_tween().tween_property(_luz, "energy", 0.7, 0.8)
	# Un brinco suave y pétalos
	var t := create_tween()
	t.tween_property(_sprite, "scale", _sprite.scale * 1.12, 0.15)
	t.tween_property(_sprite, "scale", _sprite.scale, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_lanzar_petalos()
	florecio.emit()


func _lanzar_petalos() -> void:
	var p := CPUParticles2D.new()
	p.position = Vector2(0, -22)
	p.amount = 12
	p.one_shot = true
	p.explosiveness = 0.9
	p.lifetime = 1.0
	p.direction = Vector2.UP
	p.spread = 60.0
	p.gravity = Vector2(0, 14)
	p.initial_velocity_min = 14.0
	p.initial_velocity_max = 36.0
	p.scale_amount_min = 1.5
	p.scale_amount_max = 2.5
	var degradado := Gradient.new()
	degradado.set_color(0, Color("ff7aa8"))
	degradado.set_color(1, Color(1.0, 0.8, 0.9, 0.0))
	p.color_ramp = degradado
	add_child(p)
	p.emitting = true
	get_tree().create_timer(1.3).timeout.connect(p.queue_free)
