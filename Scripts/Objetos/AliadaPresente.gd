class_name AliadaPresente
extends Node2D
## La forma ALIADA de una emoción integrada, en el Presente: la criatura en calma, flotando, con una
## luz suave de su color. Al interactuar dice su mensaje (mensaje_presente_aliada).
## La crea BloqueoPresente, que le pasa los datos con preparar().

const APOYO := Vector2(32, 60)

const VELOCIDAD := 15.0
## La aliada nunca se aleja más de esto del bloqueo abierto, ni se acerca más de DIST_JUGADOR al jugador.
const RADIO_PASEO := 100.0
const DIST_JUGADOR := 50.0
const DIST_PORTAL := 64.0
const TITULO_DESPUES := "aliada_despues"
const FRASES_DESPUES := 4

var datos: EmocionData
## Frase del diálogo "aliada_despues" (la lee el .dialogue).
var frase_despues := 0
var _ultima_frase := -1
var _ya_hablo := false
var _sprite: AnimatedSprite2D
var _luz: PointLight2D
var _zona: Area2D
var _tiempo := 0.0
var _ocupada := false
var _centro := Vector2.ZERO          # el bloqueo abierto (posición global)
var _destino := Vector2.ZERO
var _espera := 0.0
var _forma_consulta := CircleShape2D.new()


func preparar(emocion: EmocionData) -> void:
	datos = emocion
	_forma_consulta.radius = 10.0
	_centro = get_parent().global_position
	_destino = global_position
	_espera = randf_range(0.5, 2.0)
	# Criatura en calma (animación "calma" de los frames de la emoción)
	_sprite = AnimatedSprite2D.new()
	_sprite.sprite_frames = datos.frames
	_sprite.centered = false
	_sprite.offset = -APOYO
	add_child(_sprite)
	if datos.frames != null and datos.frames.has_animation(&"calma"):
		_sprite.play(&"calma")
	elif datos.frames != null and datos.frames.has_animation(&"idle"):
		_sprite.play(&"idle")

	# Luz suave del color de la emoción
	_luz = PointLight2D.new()
	_luz.texture = load("res://Resources/Mundo/luz_calida.tres")
	_luz.color = datos.color
	_luz.energy = 0.7
	_luz.texture_scale = 0.9
	_luz.position = Vector2(0, -28)
	add_child(_luz)

	# Zona de interacción (capa 2)
	_zona = Area2D.new()
	_zona.collision_layer = 2
	_zona.collision_mask = 0
	_zona.monitoring = false
	var forma := CollisionShape2D.new()
	var circulo := CircleShape2D.new()
	circulo.radius = 24.0
	forma.shape = circulo
	forma.position = Vector2(0, -26)
	_zona.add_child(forma)
	add_child(_zona)

	# Flota suavemente
	var flote := create_tween().set_loops()
	flote.tween_property(_sprite, "position:y", -4.0, 1.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	flote.tween_property(_sprite, "position:y", 0.0, 1.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _process(delta: float) -> void:
	_tiempo += delta
	if _luz != null:
		_luz.energy = 0.7 + sin(_tiempo * 2.2) * 0.12


## Deambula despacio dentro de unos 100 px de su bloqueo, sin atravesar muros, ni pegarse al jugador
## o a un portal, ni quedarse quieta como un personaje congelado.
func _physics_process(delta: float) -> void:
	if datos == null or _ocupada:
		return
	var jugador := get_tree().get_first_node_in_group("player") as Node2D
	# Si el jugador se acerca demasiado, se aparta un poco
	if jugador != null and global_position.distance_to(jugador.global_position) < DIST_JUGADOR - 8.0:
		_dar_paso((global_position - jugador.global_position).normalized(), delta)
		return
	_espera -= delta
	if global_position.distance_to(_destino) < 3.0 or _espera <= 0.0:
		if _espera <= 0.0:
			_elegir_destino()
		return
	_dar_paso((_destino - global_position).normalized(), delta)


func _elegir_destino() -> void:
	_espera = randf_range(2.5, 5.0)
	_destino = global_position
	for _i in 10:
		var candidato := _centro + Vector2.from_angle(randf() * TAU) * randf_range(35.0, RADIO_PASEO)
		if _es_libre(candidato) and _es_libre(global_position.lerp(candidato, 0.5)):
			_destino = candidato
			return


func _dar_paso(direccion: Vector2, delta: float) -> void:
	var siguiente := global_position + direccion * VELOCIDAD * delta
	if _es_libre(siguiente):
		global_position = siguiente
	else:
		_destino = global_position  # chocaría: se queda y elige otro sitio la próxima vez
		_espera = minf(_espera, 0.4)


## ¿Se puede estar ahí? Sin muros ni obstáculos (capa 1), dentro del radio, y lejos del jugador y de los portales.
func _es_libre(p: Vector2) -> bool:
	if p.distance_to(_centro) > RADIO_PASEO:
		return false
	var consulta := PhysicsShapeQueryParameters2D.new()
	consulta.shape = _forma_consulta
	consulta.transform = Transform2D(0.0, p)
	consulta.collision_mask = 1
	if not get_world_2d().direct_space_state.intersect_shape(consulta, 1).is_empty():
		return false
	var jugador := get_tree().get_first_node_in_group("player") as Node2D
	if jugador != null and p.distance_to(jugador.global_position) < DIST_JUGADOR:
		return false
	for portal in get_tree().get_nodes_in_group("portales"):
		if portal is Node2D and portal.can_process() and p.distance_to(portal.global_position) < DIST_PORTAL:
			return false
	return true


func puede_interactuar() -> bool:
	return not _ocupada and not Dialogo.hay_dialogo()


## La primera vez dice su mensaje de aliada; después, frases cortas distintas cada vez (sin repetir la anterior).
func interactuar() -> void:
	if not puede_interactuar():
		return
	_ocupada = true
	var resultado := -1
	var ruta := "res://Dialogos/%s.dialogue" % datos.id
	if _ya_hablo and ResourceLoader.exists(ruta):
		var nueva := randi() % FRASES_DESPUES
		while nueva == _ultima_frase:
			nueva = randi() % FRASES_DESPUES
		_ultima_frase = nueva
		frase_despues = nueva
		resultado = await Dialogo.mostrar(load(ruta), TITULO_DESPUES, [self])
	else:
		resultado = await Dialogo.mostrar_texto(datos.nombre, [datos.mensaje_presente_aliada])
	_ya_hablo = true
	if resultado == Dialogo.CANCELADO:
		GloboCierre.mostrar(self, datos.frase_cierre, -84.0)
	_ocupada = false
