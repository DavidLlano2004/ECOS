extends StaticBody2D
## Objeto de PRUEBA del grupo "rompible" (interfaz romper()). Una roca sólida que bloquea el paso
## hasta que el Impulso la rompe. Solo para la arena PruebaHabilidades; dibujada con marcadores simples.

signal rota

var _rota := false


func _ready() -> void:
	add_to_group("rompible")
	collision_layer = 1  # mundo: bloquea al jugador
	var forma := CollisionShape2D.new()
	var circulo := CircleShape2D.new()
	circulo.radius = 13.0
	forma.shape = circulo
	forma.position = Vector2(0, -10)
	add_child(forma)


## Interfaz del grupo "rompible": se llama cuando el Impulso la toca.
func romper() -> void:
	if _rota:
		return
	_rota = true
	rota.emit()
	for hijo in get_children():
		if hijo is CollisionShape2D:
			hijo.set_deferred("disabled", true)
	_lanzar_pedazos()
	var t := create_tween()
	t.tween_property(self, "modulate:a", 0.0, 0.15)
	t.tween_callback(queue_free)


func _lanzar_pedazos() -> void:
	var p := CPUParticles2D.new()
	p.top_level = true
	p.global_position = global_position + Vector2(0, -10)
	p.amount = 14
	p.one_shot = true
	p.explosiveness = 1.0
	p.lifetime = 0.7
	p.spread = 180.0
	p.direction = Vector2.UP
	p.gravity = Vector2(0, 120)
	p.initial_velocity_min = 40.0
	p.initial_velocity_max = 110.0
	p.scale_amount_min = 2.0
	p.scale_amount_max = 4.0
	p.color = Color("8d8a99")
	get_parent().add_child(p)
	p.global_position = global_position + Vector2(0, -10)
	p.emitting = true
	get_tree().create_timer(1.0).timeout.connect(p.queue_free)


func _draw() -> void:
	var cuerpo := PackedVector2Array([
		Vector2(-14, 0), Vector2(-16, -12), Vector2(-8, -22), Vector2(6, -23), Vector2(15, -13), Vector2(14, 0)])
	draw_colored_polygon(cuerpo, Color("8d8a99"))
	draw_colored_polygon(PackedVector2Array([Vector2(-8, -22), Vector2(6, -23), Vector2(2, -14), Vector2(-10, -12)]), Color("a9a6b8"))
	draw_polyline(PackedVector2Array([Vector2(-14, 0), Vector2(14, 0)]), Color("5d5a6b"), 2.0)
