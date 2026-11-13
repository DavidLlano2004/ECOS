class_name EfectosHabilidades
extends RefCounted
## Efectos visuales compartidos por las habilidades. Todo se hace por código (tweens, partículas):
## no hace falta ninguna imagen nueva. Los efectos cuelgan del jugador con `top_level`, así que
## se quedan en el mundo donde nacieron aunque el jugador se mueva.


## Temblor corto de la cámara del jugador.
static func temblor_camara(jugador: Player, fuerza: float, segundos: float) -> void:
	var camara := jugador.camara
	var t := jugador.create_tween()
	t.tween_method(func(restante: float) -> void:
		camara.offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * fuerza * restante,
		1.0, 0.0, segundos)
	t.tween_callback(func() -> void: camara.offset = Vector2.ZERO)


## Imagen fantasma del sprite del jugador que se desvanece (la estela del Impulso).
## Se dibuja detrás del jugador.
static func fantasma(jugador: Player, color: Color) -> void:
	var sprite := jugador.sprite
	var textura := sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame)
	if textura == null:
		return
	var imagen := Sprite2D.new()
	imagen.texture = textura
	imagen.top_level = true
	imagen.show_behind_parent = true
	jugador.add_child(imagen)
	imagen.global_position = sprite.global_position + sprite.offset
	imagen.scale = sprite.scale
	imagen.modulate = Color(color.lerp(Color.WHITE, 0.35), 0.6)
	var t := imagen.create_tween()
	t.tween_property(imagen, "modulate:a", 0.0, 0.3)
	t.tween_callback(imagen.queue_free)


## Nubecita de polvo en `posicion` (global), detrás del jugador.
static func polvo(jugador: Player, posicion: Vector2, cantidad: int = 6) -> void:
	var p := CPUParticles2D.new()
	p.top_level = true
	p.show_behind_parent = true
	p.amount = cantidad
	p.one_shot = true
	p.explosiveness = 1.0
	p.lifetime = 0.45
	p.direction = Vector2.UP
	p.spread = 180.0
	p.gravity = Vector2.ZERO
	p.initial_velocity_min = 10.0
	p.initial_velocity_max = 36.0
	p.scale_amount_min = 1.5
	p.scale_amount_max = 3.0
	var degradado := Gradient.new()
	degradado.set_color(0, Color(0.88, 0.8, 0.68, 0.75))
	degradado.set_color(1, Color(0.88, 0.8, 0.68, 0.0))
	p.color_ramp = degradado
	jugador.add_child(p)
	p.global_position = posicion
	p.emitting = true
	jugador.get_tree().create_timer(p.lifetime + 0.2).timeout.connect(p.queue_free)
