class_name Guia
extends Node2D
## La Guía del mundo. Flota junto al portal del hub, en las dos épocas (en el Presente es
## semitransparente). Al interactuar abre Dialogos/guia.dialogue, cuyos textos cambian con el progreso.

const DIALOGO := preload("res://Dialogos/guia.dialogue")
## Punto de apoyo del dibujo (64x64, centrado y casi en el borde de abajo).
const APOYO := Vector2(32, 60)
const ALPHA_PRESENTE := 0.7

@onready var _sprite: AnimatedSprite2D = $Sprite
@onready var _luz: PointLight2D = $Luz

var _tiempo := 0.0
var _fase := 0.0
var _base_luz := 0.9


func _ready() -> void:
	add_to_group("guia")
	_fase = randf() * TAU
	_sprite.centered = false
	_sprite.offset = -APOYO
	_sprite.play(&"idle")
	if _epoca() == "presente":
		_sprite.modulate.a = ALPHA_PRESENTE
		_base_luz = 0.45
	Dialogo.dialogo_cerrado.connect(_on_dialogo_cerrado)

	# Flota suavemente arriba y abajo
	var flote := create_tween().set_loops()
	flote.tween_property(_sprite, "position:y", -3.0, 1.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	flote.tween_property(_sprite, "position:y", 0.0, 1.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _process(delta: float) -> void:
	_tiempo += delta
	# La luz de la linterna parpadea
	_luz.energy = _base_luz + sin(_tiempo * 9.0 + _fase) * 0.1 + sin(_tiempo * 23.0) * 0.06


func puede_interactuar() -> bool:
	return not Dialogo.hay_dialogo()


## El jugador pulsó E cerca de la Guía.
func interactuar() -> void:
	if not puede_interactuar():
		return
	_sprite.play(&"hablar")
	await Dialogo.mostrar(DIALOGO, "start", [self])
	_sprite.play(&"idle")


func _on_dialogo_cerrado() -> void:
	if _sprite.animation != &"idle":
		_sprite.play(&"idle")


func _epoca() -> String:
	var nodo := get_parent()
	while nodo != null:
		if nodo.name == &"Presente":
			return "presente"
		if nodo.name == &"Pasado":
			return "pasado"
		nodo = nodo.get_parent()
	return "pasado"
