class_name EfectoReparar
extends Node2D
## Efecto de mantener ESPACIO para reparar: anillo de progreso dorado en el suelo alrededor del
## objeto, una cinta dorada que lo va rodeando y partículas. Al llegar a 1.2 s llama a reparar()
## del objeto. Si se suelta antes (o el jugador se aleja o algo bloquea las habilidades) se
## cancela sin penalización. Lo crea HabilidadReparacion.

signal terminado(completado: bool)

const SEGUNDOS := 1.2
## Nivel 2 (cofre de Culpa): se repara en la mitad de tiempo.
const SEGUNDOS_NIVEL_2 := 0.6
## Si el jugador se aleja más de esto del objeto, se cancela (un poco más que los 48 px de inicio).
const DISTANCIA_MAXIMA := 56.0
const DORADO := Color("f4c77b")
const RADIO_POR_DEFECTO := 24.0
const ALTURA_CINTA := 34.0

var objetivo: Node2D
var jugador: Player
## 0 a 1: avance de la reparación.
var progreso := 0.0

var _radio := RADIO_POR_DEFECTO
var _activo := false
var _particulas: CPUParticles2D


## Cuánto hay que mantener ESPACIO según el nivel de Reparar.
static func segundos_actuales() -> float:
	return SEGUNDOS_NIVEL_2 if Habilidades.nivel_de("reparacion") >= 2 else SEGUNDOS


## Empieza a reparar `p_objetivo`. Se llama justo después de añadir el nodo al árbol.
func iniciar(p_jugador: Player, p_objetivo: Node2D) -> void:
	jugador = p_jugador
	objetivo = p_objetivo
	top_level = true
	global_position = objetivo.global_position
	if "radio_reparar" in objetivo:
		_radio = float(objetivo.radio_reparar)
	_crear_particulas()
	_activo = true


## true mientras se está reparando (no durante el desvanecimiento final).
func esta_activo() -> bool:
	return _activo


func _process(delta: float) -> void:
	if not _activo:
		return
	if not _sigue_valido():
		_cancelar()
		return
	global_position = objetivo.global_position
	progreso = minf(progreso + delta / segundos_actuales(), 1.0)
	queue_redraw()
	if progreso >= 1.0:
		_completar()


## ¿Sigue pulsado ESPACIO, con la habilidad elegida y el jugador cerca del objeto?
func _sigue_valido() -> bool:
	if not is_instance_valid(objetivo) or not is_instance_valid(jugador):
		return false
	if not Input.is_action_pressed("HABILIDAD") or not Habilidades.puede_operar():
		return false
	if Habilidades.habilidad_seleccionada != "reparacion" or not jugador.can_move:
		return false
	# Una compuerta se mide por su área (cubre todo el objeto), no por su origen
	if objetivo.has_method("solapa_area"):
		return objetivo.solapa_area(jugador.global_position)
	return jugador.global_position.distance_to(objetivo.global_position) <= DISTANCIA_MAXIMA


func _cancelar() -> void:
	_activo = false
	_particulas.emitting = false
	terminado.emit(false)
	var t := create_tween()
	t.tween_property(self, "modulate:a", 0.0, 0.2)
	t.tween_callback(queue_free)


func _completar() -> void:
	_activo = false
	if is_instance_valid(objetivo) and objetivo.has_method("reparar"):
		objetivo.reparar()
	# Ráfaga final de chispas y un último destello del anillo
	_particulas.emitting = false
	_particulas.amount = 36
	_particulas.explosiveness = 1.0
	_particulas.one_shot = true
	_particulas.initial_velocity_min = 30.0
	_particulas.initial_velocity_max = 70.0
	_particulas.restart()
	terminado.emit(true)
	var t := create_tween()
	t.tween_property(self, "scale", Vector2(1.25, 1.25), 0.35).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(self, "modulate:a", 0.0, 0.5)
	t.tween_callback(queue_free)


func _crear_particulas() -> void:
	_particulas = CPUParticles2D.new()
	_particulas.position = Vector2(0, -ALTURA_CINTA / 2.0)
	_particulas.amount = 22
	_particulas.lifetime = 0.8
	_particulas.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	_particulas.emission_sphere_radius = _radio
	_particulas.direction = Vector2.UP
	_particulas.spread = 25.0
	_particulas.gravity = Vector2(0, -18)
	_particulas.initial_velocity_min = 8.0
	_particulas.initial_velocity_max = 22.0
	_particulas.scale_amount_min = 1.5
	_particulas.scale_amount_max = 2.6
	var degradado := Gradient.new()
	degradado.set_color(0, Color(DORADO.lightened(0.3), 1.0))
	degradado.set_color(1, Color(DORADO, 0.0))
	_particulas.color_ramp = degradado
	add_child(_particulas)
	_particulas.emitting = true


func _draw() -> void:
	var brillo := DORADO.lerp(Color.WHITE, progreso * 0.4)
	# Anillo de progreso en el suelo (elipse aplastada, como se ve en vista cenital)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.5))
	draw_arc(Vector2.ZERO, _radio, 0.0, TAU, 48, Color(DORADO, 0.25), 2.0, true)
	if progreso > 0.0:
		draw_arc(Vector2.ZERO, _radio, -PI / 2.0, -PI / 2.0 + TAU * progreso, 48, brillo, 3.0, true)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# Cinta dorada que sube en espiral alrededor del objeto a medida que avanza
	var vueltas := 2.2
	var total := TAU * vueltas * progreso
	if total > 0.1:
		for desfase in [0.0, PI]:
			var puntos := PackedVector2Array()
			var pasos := int(total / 0.2) + 2
			for i in pasos + 1:
				var a := total * i / pasos
				var altura := ALTURA_CINTA * a / (TAU * vueltas)
				puntos.append(Vector2(cos(a + desfase) * _radio, sin(a + desfase) * _radio * 0.5 - altura))
			draw_polyline(puntos, Color(brillo, 0.9 if desfase == 0.0 else 0.55), 2.0, true)
