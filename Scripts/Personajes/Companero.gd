class_name Companero
extends Node2D
## Luciérnaga compañera (habilidad Vínculo). No tiene imagen: se dibuja por código (cuerpo, alas que
## baten y brillo), con una PointLight2D cálida y partículas de chispas. Vuela suave siguiendo al
## jugador a unos 40 px o se posa sobre una "placa_doble".
##
## - NO tiene cuerpo físico: no estorba la colisión del jugador ni la de las emociones. Las placas
##   la detectan por el grupo "companero" y su posición.
## - Persiste al viajar entre épocas: se pasa al nodo donde está el jugador y vuelve con él.
## - El origen del nodo está en el suelo (para el y-sort); el cuerpo vuela `altura` px más arriba.
## - Se queda posada hasta que el jugador pulse ESPACIO lejos de la placa, se aleje más de
##   DISTANCIA_MAXIMA_PLACA px o se cambie de época.

enum Estado { SIGUE, VUELA_A_PLACA, POSADO }

const DISTANCIA_SEGUIR := 40.0
const DISTANCIA_MAXIMA_PLACA := 300.0
## Nivel 2 (cofre de Soledad): se puede mandar más lejos y brilla más.
const DISTANCIA_MAXIMA_PLACA_NIVEL_2 := 500.0
const ALTURA_VUELO := 30.0
const ALTURA_POSADO := 9.0
const COLOR_CUERPO := Color("ffe08a")
const COLOR_LUZ := Color("ffcf7a")
const RADIO_LUZ := 64.0
const TAMANO_TEXTURA := 128

var jugador: Player
var estado: Estado = Estado.SIGUE
## La placa en la que está posada (o a la que vuela).
var placa: Node2D

var _altura := ALTURA_VUELO
var _tiempo := 0.0
var _luz: PointLight2D
var _chispas: CPUParticles2D
var _despidiendo := false

## true si está posada sobre una placa.
var posado: bool:
	get:
		return estado == Estado.POSADO


## Hasta dónde puede estar el jugador de la placa donde se posó el compañero, según el nivel de Vínculo.
static func distancia_maxima_placa() -> float:
	return DISTANCIA_MAXIMA_PLACA_NIVEL_2 if Habilidades.nivel_de("vinculo") >= 2 else DISTANCIA_MAXIMA_PLACA


func _ready() -> void:
	add_to_group("companero")
	# Explícito para seguir funcionando aunque la época donde nació quede desactivada (hasta que se mueva)
	process_mode = Node.PROCESS_MODE_PAUSABLE
	_luz = get_node_or_null("Luz")
	if _luz == null:
		_luz = PointLight2D.new()
		add_child(_luz)
	_luz.texture = Atmosfera.crear_textura_luz(TAMANO_TEXTURA)
	var mejorado := Habilidades.nivel_de("vinculo") >= 2
	_luz.texture_scale = RADIO_LUZ * (1.5 if mejorado else 1.0) * 2.0 / TAMANO_TEXTURA
	_luz.color = COLOR_LUZ
	_luz.energy = 1.2 if mejorado else 0.7
	_chispas = get_node_or_null("Chispas")
	if _chispas == null:
		_chispas = CPUParticles2D.new()
		add_child(_chispas)
	_preparar_chispas()
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.4)
	GameState.epoca_cambiada.connect(_on_epoca_cambiada)


## Empieza a seguir a un jugador.
func iniciar(p_jugador: Player) -> void:
	jugador = p_jugador
	estado = Estado.SIGUE
	global_position = jugador.global_position + Vector2(0, -6)


func _process(delta: float) -> void:
	_tiempo += delta
	if jugador == null or not is_instance_valid(jugador):
		return
	match estado:
		Estado.SIGUE:
			_volar_hacia(_punto_junto_al_jugador(), 4.0, ALTURA_VUELO, delta)
		Estado.VUELA_A_PLACA:
			if not is_instance_valid(placa):
				volver_con_jugador()
			else:
				_volar_hacia(placa.global_position, 5.0, ALTURA_VUELO, delta)
				if global_position.distance_to(placa.global_position) < 2.0:
					estado = Estado.POSADO
		Estado.POSADO:
			if not is_instance_valid(placa) \
					or jugador.global_position.distance_to(placa.global_position) > distancia_maxima_placa():
				volver_con_jugador()
			else:
				_volar_hacia(placa.global_position, 8.0, ALTURA_POSADO, delta)
	_luz.position = Vector2(0, -_altura)
	_chispas.position = Vector2(0, -_altura)
	queue_redraw()


## Punto en el suelo a ~40 px del jugador; da vueltas despacio para parecer que flota.
func _punto_junto_al_jugador() -> Vector2:
	var angulo := _tiempo * 0.9
	return jugador.global_position + Vector2(cos(angulo), sin(angulo) * 0.5) * DISTANCIA_SEGUIR


func _volar_hacia(destino: Vector2, suavidad: float, altura: float, delta: float) -> void:
	var paso := 1.0 - exp(-suavidad * delta)
	global_position = global_position.lerp(destino, paso)
	_altura = lerpf(_altura, altura + sin(_tiempo * 3.0) * 2.5, paso)


# --- Órdenes (las da HabilidadVinculo) ---

## Va a posarse sobre una placa doble.
func posarse_en(p_placa: Node2D) -> void:
	placa = p_placa
	estado = Estado.VUELA_A_PLACA


## Vuelve con el jugador (y se pasa a su época si hace falta).
func volver_con_jugador() -> void:
	estado = Estado.SIGUE
	placa = null
	_seguir_la_epoca_del_jugador()


## Se despide con un fundido y desaparece.
func despedir() -> void:
	if _despidiendo:
		return
	_despidiendo = true
	remove_from_group("companero")  # las placas dejan de verla enseguida
	var t := create_tween()
	t.tween_property(self, "modulate:a", 0.0, 0.35)
	t.tween_callback(queue_free)


# --- Épocas ---

func _on_epoca_cambiada(_epoca: String) -> void:
	# Mundo mueve al jugador a la otra época; el compañero lo sigue y vuelve con él
	volver_con_jugador.call_deferred()


## Pasa al mismo nodo donde está el jugador (así viaja con él entre Pasado y Presente).
func _seguir_la_epoca_del_jugador() -> void:
	if jugador == null or not is_instance_valid(jugador) or not is_inside_tree():
		return
	var destino := jugador.get_parent()
	if destino != null and destino != get_parent():
		reparent(destino, true)


# --- Dibujo ---

func _draw() -> void:
	# Sombra en el suelo (más pequeña cuanto más alto vuela)
	var escala_sombra := clampf(1.0 - (_altura - ALTURA_POSADO) / 80.0, 0.4, 1.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.4))
	draw_circle(Vector2.ZERO, 4.0 * escala_sombra, Color(0, 0, 0, 0.25))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var centro := Vector2(0, -_altura)
	# Brillo
	draw_circle(centro, 7.0, Color(COLOR_CUERPO, 0.15))
	draw_circle(centro, 4.5, Color(COLOR_CUERPO, 0.3))
	# Alas que baten
	var aleteo := sin(_tiempo * 40.0) * 0.5 + 0.5 if estado != Estado.POSADO else 0.2
	for lado in [-1.0, 1.0]:
		var punta := centro + Vector2(lado * (3.0 + 4.0 * aleteo), -2.0 - 3.0 * aleteo)
		draw_line(centro + Vector2(lado * 1.0, -1.0), punta, Color(1, 1, 1, 0.6), 2.0, true)
	# Cuerpo
	draw_circle(centro, 2.2, COLOR_CUERPO)
	draw_circle(centro + Vector2(0, 1.5), 1.6, Color("fff4dc"))


func _preparar_chispas() -> void:
	_chispas.amount = 8
	_chispas.lifetime = 0.9
	_chispas.local_coords = false
	_chispas.direction = Vector2.UP
	_chispas.spread = 180.0
	_chispas.gravity = Vector2.ZERO
	_chispas.initial_velocity_min = 2.0
	_chispas.initial_velocity_max = 8.0
	_chispas.scale_amount_min = 1.0
	_chispas.scale_amount_max = 1.8
	var degradado := Gradient.new()
	degradado.set_color(0, Color(COLOR_CUERPO, 0.9))
	degradado.set_color(1, Color(COLOR_CUERPO, 0.0))
	_chispas.color_ramp = degradado
	_chispas.emitting = true
