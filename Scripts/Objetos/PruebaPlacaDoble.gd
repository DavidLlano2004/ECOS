extends Node2D
## Objeto de PRUEBA del grupo "placa_doble": una placa de presión que detecta tanto al jugador
## (grupo "player") como a la luciérnaga compañera (grupo "companero") cuando están a menos de
## `radio` px. Sirve para los mecanismos dobles: dos placas, una para cada uno.

signal ocupacion_cambiada

@export var radio := 22.0

var con_jugador := false
var con_companero := false

## true si hay alguien encima (el jugador, el compañero o los dos).
var ocupada: bool:
	get:
		return con_jugador or con_companero


func _ready() -> void:
	add_to_group("placa_doble")


func _physics_process(_delta: float) -> void:
	var jugador := get_tree().get_first_node_in_group("player") as Node2D
	var hay_jugador := jugador != null and jugador.global_position.distance_to(global_position) <= radio
	var hay_companero := false
	for c in get_tree().get_nodes_in_group("companero"):
		if c is Node2D and c.global_position.distance_to(global_position) <= radio:
			hay_companero = true
			break
	if hay_jugador != con_jugador or hay_companero != con_companero:
		con_jugador = hay_jugador
		con_companero = hay_companero
		ocupacion_cambiada.emit()
		queue_redraw()


func _draw() -> void:
	var color := Color("f4c77b") if ocupada else Color("6a6485")
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.5))
	draw_circle(Vector2.ZERO, radio, Color(color, 0.25))
	draw_arc(Vector2.ZERO, radio, 0.0, TAU, 32, color, 2.0, true)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# Dos puntos: izquierda = jugador, derecha = compañero
	draw_circle(Vector2(-6, -2), 2.5, Color("fff4dc") if con_jugador else Color("3b3650"))
	draw_circle(Vector2(6, -2), 2.5, Color("ffe08a") if con_companero else Color("3b3650"))
