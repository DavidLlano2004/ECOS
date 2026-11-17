class_name CofreMemoria
extends StaticBody2D
## Cofre de memoria. Cerrado: una luz violeta tenue respira sobre la gema. Al abrirse (abrir())
## se reproduce "abriendo" (~0.4 s), queda "abierto" y una luz dorada más fuerte se desvanece.
## Origen del nodo: la base del cofre. La colisión cubre solo su parte inferior.

signal abierto

@onready var _sprite: AnimatedSprite2D = $Sprite
@onready var _luz_gema: PointLight2D = $LuzGema
@onready var _luz_dorada: PointLight2D = $LuzDorada

var esta_abierto := false
var _tiempo := 0.0


func _ready() -> void:
	_sprite.play(&"cerrado")


func _process(delta: float) -> void:
	if esta_abierto:
		return
	_tiempo += delta
	# La luz violeta respira despacio
	_luz_gema.energy = 0.35 + sin(_tiempo * 2.4) * 0.12


## Abre el cofre: animación, luz dorada que se desvanece. Se puede llamar varias veces.
func abrir() -> void:
	if esta_abierto:
		return
	esta_abierto = true
	_luz_gema.energy = 0.0
	_sprite.play(&"abriendo")
	_luz_dorada.energy = 1.4
	var t := create_tween()
	t.tween_interval(0.4)
	t.tween_callback(func() -> void: _sprite.play(&"abierto"))
	t.tween_property(_luz_dorada, "energy", 0.0, 1.6).set_ease(Tween.EASE_OUT)
	abierto.emit()
