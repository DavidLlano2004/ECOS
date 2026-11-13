extends Node2D
## Objeto de PRUEBA del grupo "tiempo": una plataforma que va de lado a lado sobre un abismo.
## Multiplica su delta por Habilidades.factor_tiempo, así que con Pausa se mueve más despacio.
## Lleva encima al jugador. Es también un "soporte" del abismo (sostiene(punto)).

@export var tamano := Vector2(44, 84)
## Límites del recorrido en x (coordenadas globales) y velocidad en px/s.
@export var x_min := 850.0
@export var x_max := 1160.0
@export var velocidad := 150.0

var _recorrido := 0.0


func _ready() -> void:
	add_to_group("tiempo")
	add_to_group("soporte")
	_recorrido = randf() * (x_max - x_min)


func _physics_process(delta: float) -> void:
	var jugador: Player = get_tree().get_first_node_in_group("player")
	var lleva_al_jugador := jugador != null and sostiene(jugador.global_position)
	var antes := global_position.x
	_recorrido += velocidad * delta * Habilidades.factor_tiempo   # el tiempo del mundo
	global_position.x = x_min + pingpong(_recorrido, x_max - x_min)
	if lleva_al_jugador:
		jugador.move_and_collide(Vector2(global_position.x - antes, 0.0))
	queue_redraw()


## ¿Hay suelo de plataforma en este punto (global)?
func sostiene(punto: Vector2) -> bool:
	return Rect2(global_position - tamano / 2.0, tamano).grow(3.0).has_point(punto)


func _draw() -> void:
	var rect := Rect2(-tamano / 2.0, tamano)
	draw_rect(rect, Color("8d6e4a"))
	draw_rect(rect, Color("c9a26a"), false, 2.0)
	for i in 4:  # tablones
		var y := rect.position.y + (i + 1) * tamano.y / 5.0
		draw_line(Vector2(rect.position.x, y), Vector2(rect.end.x, y), Color("5e4630"), 1.0)
