class_name AliadaPresente
extends Node2D
## La forma ALIADA de una emoción integrada, en el Presente: la criatura en calma, flotando, con una
## luz suave de su color. Al interactuar dice su mensaje (mensaje_presente_aliada).
## La crea BloqueoPresente, que le pasa los datos con preparar().

const APOYO := Vector2(32, 60)

var datos: EmocionData
var _sprite: AnimatedSprite2D
var _luz: PointLight2D
var _zona: Area2D
var _tiempo := 0.0
var _ocupada := false


func preparar(emocion: EmocionData) -> void:
	datos = emocion
	# Criatura en calma (animación "calma" de los frames de la emoción)
	_sprite = AnimatedSprite2D.new()
	_sprite.sprite_frames = datos.frames
	_sprite.centered = false
	_sprite.offset = -APOYO
	add_child(_sprite)
	if datos.frames != null and datos.frames.has_animation(&"calma"):
		_sprite.play(&"calma")
	elif datos.frames != null and datos.frames.has_animation(&"idle"):
		_sprite.play(&"idle")

	# Luz suave del color de la emoción
	_luz = PointLight2D.new()
	_luz.texture = load("res://Resources/Mundo/luz_calida.tres")
	_luz.color = datos.color
	_luz.energy = 0.7
	_luz.texture_scale = 0.9
	_luz.position = Vector2(0, -28)
	add_child(_luz)

	# Zona de interacción (capa 2)
	_zona = Area2D.new()
	_zona.collision_layer = 2
	_zona.collision_mask = 0
	_zona.monitoring = false
	var forma := CollisionShape2D.new()
	var circulo := CircleShape2D.new()
	circulo.radius = 24.0
	forma.shape = circulo
	forma.position = Vector2(0, -26)
	_zona.add_child(forma)
	add_child(_zona)

	# Flota suavemente
	var flote := create_tween().set_loops()
	flote.tween_property(_sprite, "position:y", -4.0, 1.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	flote.tween_property(_sprite, "position:y", 0.0, 1.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _process(delta: float) -> void:
	_tiempo += delta
	if _luz != null:
		_luz.energy = 0.7 + sin(_tiempo * 2.2) * 0.12


func puede_interactuar() -> bool:
	return not _ocupada and not Dialogo.hay_dialogo()


func interactuar() -> void:
	if not puede_interactuar():
		return
	_ocupada = true
	await Dialogo.mostrar_texto(datos.nombre, [datos.mensaje_presente_aliada])
	_ocupada = false
