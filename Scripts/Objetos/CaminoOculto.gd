class_name CaminoOculto
extends Node2D
## Puente escondido sobre un abismo o ravina (acertijo de Revelar). Grupo "oculto": interfaz
## revelar(segundos). Su estado inicial se ve fantasmal (el sprite ya es semitransparente) y NO se
## puede pisar. Mientras dura el efecto de Revelar se ve sólido con un destello dorado y se puede
## caminar; después vuelve a ser fantasma (salvo que `permanente` sea true).
## Es también un "soporte" del abismo (sostiene(punto)).
## Origen del nodo: el borde de arriba del puente (el jugador se dibuja por encima al cruzar).

signal revelado
signal ocultado

## Tamaño del sitio que se pisa (px): el ancho de la ravina y 2 casillas de alto.
@export var ancho_soporte := 96.0
@export var alto_soporte := 64.0
## Si es true, una vez revelado se queda para siempre.
@export var permanente := false

@onready var _sprite: AnimatedSprite2D = $Sprite

## true mientras se puede pisar.
var funcional := false

var _version := 0
var _tween: Tween


func _ready() -> void:
	add_to_group("oculto")
	add_to_group("soporte")
	_sprite.animation = &"inicial"


## Interfaz del grupo "oculto": Revelar lo llama con la duración en segundos.
func revelar(segundos: float = 6.0) -> void:
	_version += 1
	var esta := _version
	funcional = true
	Sonido.efecto("puente_aparece")
	_sprite.animation = &"resuelto"
	revelado.emit()
	if _tween != null:
		_tween.kill()
	# Destello dorado que se apaga
	_sprite.modulate = Color(2.2, 1.9, 1.2, 1.0)
	_tween = create_tween()
	_tween.tween_property(_sprite, "modulate", Color.WHITE, 0.5)
	if permanente:
		return
	await get_tree().create_timer(segundos, false).timeout
	if esta != _version or not is_inside_tree():
		return  # se volvió a revelar mientras tanto
	funcional = false
	_sprite.animation = &"inicial"
	ocultado.emit()


## ¿Sostiene este punto (global)? Solo mientras está revelado.
func sostiene(punto: Vector2) -> bool:
	return funcional and Rect2(global_position + Vector2(-ancho_soporte / 2.0, 0.0), Vector2(ancho_soporte, alto_soporte)).has_point(punto)
