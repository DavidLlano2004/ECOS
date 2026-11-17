class_name CofreMemoria
extends StaticBody2D
## Cofre de memoria del santuario de una emoción (solo en el Presente, detrás de su bloqueo).
## Cerrado: una luz violeta tenue respira sobre la gema. Al interactuar (solo con la emoción integrada,
## o sea, con el bloqueo abierto) se abre: animación "abriendo" (~0.4 s), destello del color de la
## emoción y una luz dorada que se desvanece. Se entrega UNA sola vez:
##   a) la MEJORA de la habilidad de esa emoción (nivel 2), con un aviso de Notificacion;
##   b) un REGALO, un objeto de memoria con nombre y texto (se guarda en GameState.regalos y sale en la
##      sección "Regalos" del diario).
## Después, la forma aliada dice una frase de agradecimiento. El estado vive en GameState.cofres.
## Origen del nodo: la base del cofre. La colisión cubre solo su parte inferior.

signal abierto

## id de la emoción a la que pertenece (rabia, miedo...).
@export var emocion_id := ""

@onready var _sprite: AnimatedSprite2D = $Sprite
@onready var _luz_gema: PointLight2D = $LuzGema
@onready var _luz_dorada: PointLight2D = $LuzDorada

var esta_abierto := false
var _tiempo := 0.0
var _ocupado := false


func _ready() -> void:
	add_to_group("cofres")
	_sprite.play(&"cerrado")
	GameState.partida_reiniciada.connect(_leer_estado)
	GameState.partida_cargada.connect(_leer_estado)
	_leer_estado()


## Deja el cofre como dice GameState (cerrado o ya abierto, sin animación).
func _leer_estado() -> void:
	if GameState.cofre_esta_abierto(emocion_id):
		_dejar_abierto(false)
	else:
		esta_abierto = false
		_sprite.play(&"cerrado")
		_luz_dorada.energy = 0.0


func _process(delta: float) -> void:
	if esta_abierto:
		return
	_tiempo += delta
	# La luz violeta respira despacio
	_luz_gema.energy = 0.35 + sin(_tiempo * 2.4) * 0.12


## Solo se puede abrir con la emoción integrada (o sea, con el bloqueo abierto) y una sola vez.
func puede_interactuar() -> bool:
	return not esta_abierto and not _ocupado and not Dialogo.hay_dialogo() \
		and GameState.estado.get(emocion_id, "pendiente") == "integrada"


## INTERACTUAR: abre el cofre y entrega la mejora y el regalo.
func interactuar() -> void:
	if not puede_interactuar():
		return
	_ocupado = true
	if not GameState.abrir_cofre(emocion_id):
		_ocupado = false
		return
	_dejar_abierto(true)
	var datos := GameState.obtener_datos(emocion_id)
	await get_tree().create_timer(0.9).timeout   # la tarjeta de la mejora sale a la vez que suena mejora_habilidad
	if datos != null:
		Notificacion.mostrar("Mejora: %s" % datos.habilidad_nombre + " II", datos.mejora_descripcion)
		Notificacion.mostrar("Regalo: %s" % datos.regalo_nombre, datos.regalo_texto)
	await get_tree().create_timer(0.6).timeout
	await _agradecer()
	_ocupado = false


## Abre el cofre (con efecto solo si se acaba de abrir ahora).
func _dejar_abierto(con_efecto: bool) -> void:
	esta_abierto = true
	_luz_gema.energy = 0.0
	if not con_efecto:
		_sprite.play(&"abierto")
		_luz_dorada.energy = 0.0
		return
	Sonido.efecto("cofre_abre")
	_sprite.play(&"abriendo")
	_luz_dorada.energy = 1.4
	var datos := GameState.obtener_datos(emocion_id)
	if datos != null:
		_luz_dorada.color = datos.color.lerp(Color(1.0, 0.82, 0.4), 0.5)
		_destello(datos.color)
	var t := create_tween()
	t.tween_interval(0.4)
	t.tween_callback(func() -> void: _sprite.play(&"abierto"))
	t.tween_property(_luz_dorada, "energy", 0.0, 1.6).set_ease(Tween.EASE_OUT)
	abierto.emit()


## Destello y chispas del color de la emoción.
func _destello(color: Color) -> void:
	var p := CPUParticles2D.new()
	p.position = Vector2(0, -26)
	p.amount = 44
	p.one_shot = true
	p.explosiveness = 1.0
	p.lifetime = 1.1
	p.spread = 180.0
	p.direction = Vector2.UP
	p.gravity = Vector2(0, -20)
	p.initial_velocity_min = 30.0
	p.initial_velocity_max = 90.0
	p.scale_amount_min = 2.0
	p.scale_amount_max = 3.5
	var degradado := Gradient.new()
	degradado.set_color(0, Color(color.lightened(0.45), 1.0))
	degradado.set_color(1, Color(color, 0.0))
	p.color_ramp = degradado
	add_child(p)
	p.emitting = true
	get_tree().create_timer(1.5).timeout.connect(p.queue_free)
	# Un fogonazo del color de la emoción
	var luz := PointLight2D.new()
	luz.texture = load("res://Resources/Mundo/luz_calida.tres")
	luz.texture_scale = 1.4
	luz.color = color.lightened(0.3)
	luz.energy = 2.0
	luz.position = Vector2(0, -24)
	add_child(luz)
	var t := create_tween()
	t.tween_property(luz, "energy", 0.0, 0.9)
	t.tween_callback(luz.queue_free)


## La forma aliada de esta emoción dice su agradecimiento.
func _agradecer() -> void:
	for nodo in get_tree().get_nodes_in_group("aliadas_presente"):
		if nodo.has_method("agradecer") and nodo.is_visible_in_tree() and nodo.datos != null and nodo.datos.id == emocion_id:
			await nodo.agradecer()
			return
