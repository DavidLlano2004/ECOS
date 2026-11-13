class_name PlacaDoble
extends Node2D
## Placa de presión de un mecanismo doble (acertijo de Vínculo). Grupo "placa_doble": detecta tanto
## al jugador (grupo "player") como a la luciérnaga compañera (grupo "companero") a menos de `radio`.
## Una puerta (PuertaPlacas) con el mismo `id_mecanismo` exige que TODAS sus placas estén ocupadas a
## la vez: con dos placas, una la pisa el jugador y la otra el compañero.
## Origen del nodo: el borde de arriba de la placa (así el jugador se dibuja por encima al pisarla).

signal ocupacion_cambiada

@export var radio := 22.0
## Une las placas con su puerta (la pone Mundo; por ejemplo "soledad").
@export var id_mecanismo := ""

@onready var _sprite: AnimatedSprite2D = $Sprite

var con_jugador := false
var con_companero := false

## true si hay alguien encima (el jugador, el compañero o los dos).
var ocupada: bool:
	get:
		return con_jugador or con_companero


func _ready() -> void:
	add_to_group("placa_doble")
	# La placa mide ~40x32 px: su centro está unos 10 px debajo del origen
	_sprite.animation = &"inicial"


func _physics_process(_delta: float) -> void:
	var centro := global_position + Vector2(0, 10)
	var jugador := get_tree().get_first_node_in_group("player") as Node2D
	var hay_jugador := jugador != null and jugador.global_position.distance_to(centro) <= radio
	var hay_companero := false
	for c in get_tree().get_nodes_in_group("companero"):
		if c is Node2D and c.global_position.distance_to(centro) <= radio:
			hay_companero = true
			break
	if hay_jugador != con_jugador or hay_companero != con_companero:
		if (hay_jugador or hay_companero) and not ocupada:
			Sonido.efecto("placa_activa")   # acaba de pisarse
		con_jugador = hay_jugador
		con_companero = hay_companero
		_sprite.animation = &"resuelto" if ocupada else &"inicial"  # se enciende el aro
		ocupacion_cambiada.emit()
