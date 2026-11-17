class_name SantuarioSuelo
extends Node2D
## Las flores del santuario, a ras de suelo (va entre el suelo y los objetos, así el jugador siempre se
## dibuja por encima), con un halo suave del color de la emoción bajo el altar. ARTE TEMPORAL: se dibujan
## por código con una semilla fija (siempre iguales).

const CANTIDAD := 34

var datos: EmocionData
var direccion := Vector2.UP    # desde el acceso hacia el centro
var _flores: Array[Dictionary] = []


func _ready() -> void:
	var azar := RandomNumberGenerator.new()
	azar.seed = hash(datos.id)
	var hacia_acceso := (-direccion).angle()
	var colores := [datos.color.lightened(0.25), datos.color.lightened(0.55), Color("fff4dc"), datos.color.darkened(0.1)]
	var intentos := 0
	while _flores.size() < CANTIDAD and intentos < 400:
		intentos += 1
		var punto := Vector2.from_angle(azar.randf() * TAU) * azar.randf_range(26.0, 92.0)
		# Sin flores en el pasillo del acceso ni donde está el cofre
		var diferencia := absf(angle_difference(punto.angle(), hacia_acceso))
		if diferencia < deg_to_rad(28.0) and punto.length() > 50.0:
			continue
		if punto.distance_to(direccion * 54.0) < 22.0:
			continue
		_flores.append({"pos": punto.round(), "color": colores[azar.randi() % colores.size()], "alto": azar.randi_range(3, 5)})
	queue_redraw()


func _draw() -> void:
	if datos == null:
		return
	# Halo del color de la emoción bajo el altar y el cofre
	draw_circle(Vector2.ZERO, 40.0, Color(datos.color, 0.08))
	draw_circle(Vector2.ZERO, 24.0, Color(datos.color, 0.1))
	for f in _flores:
		var p: Vector2 = f["pos"]
		draw_rect(Rect2(p + Vector2(0, -f["alto"]), Vector2(1, f["alto"])), Color("4f7a3f"))      # tallo
		draw_rect(Rect2(p + Vector2(-1, -f["alto"] - 2), Vector2(3, 3)), f["color"])             # pétalos
		draw_rect(Rect2(p + Vector2(0, -f["alto"] - 1), Vector2(1, 1)), Color("ffe9a8"))          # centro
