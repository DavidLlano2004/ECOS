class_name Emocion
extends CharacterBody2D
## Criatura-emoción reutilizable. Todo lo que cambia entre emociones (sprite, velocidad,
## comportamiento, color, mensajes) viene de un recurso EmocionData (ver Resources/Emociones/).
##
## Ninguna criatura hace daño ni empuja al jugador: su cuerpo no está en la capa del jugador.
## El origen del nodo está en los PIES (igual que el jugador, para que funcione el y-sort).

## Se emite cuando el jugador integra a la criatura (la escucha hasta el final).
signal integrada(id: String)

## Título (cue) con el que empiezan los .dialogue de las emociones.
const CUE_DIALOGO := "start"
const RUTA_DIALOGO := "res://Dialogos/%s.dialogue"

const ACELERACION := 400.0

# Emoción integrada: vive tranquila en su zona (nunca empuja al jugador ni le estorba el paso)
const VELOCIDAD_CALMA := 14.0
const DIST_ACERCAR_CALMA := 130.0   # si el jugador se queda a menos de esto, se acerca un poco
const DIST_MINIMA_CALMA := 56.0     # pero nunca más cerca de esto
const DIST_APARTARSE_CALMA := 40.0  # y si el jugador está encima, se aparta
const TITULO_DESPUES := "despues"
const FRASES_DESPUES := 4

# Distancias de cada comportamiento (en píxeles)
const DIST_PERSEGUIR := 28.0
const DIST_HUIR := 100.0
const DIST_SOLEDAD := 36.0
const DIST_CULPA := 80.0
const DIST_VERGUENZA := 90.0
const TIEMPO_QUIETO_SOLEDAD := 1.5

# Ansiedad
const RAFAGA_ERRATICA := 0.3
const PAUSA_ERRATICA := 0.4

const ALPHA_ESCONDIDA := 0.35
const SEGUNDOS_HUIDA := 3.0
const ANIMACION_IDLE := &"idle"
const ANIMACION_CALMA := &"calma"

@export var datos: EmocionData
## La criatura nunca sale de este radio alrededor de su punto de origen.
@export var radio_zona: float = 220.0
## Ruta de un .dialogue propio. Si está vacía se usa Dialogos/<id>.dialogue.
@export var ruta_dialogo: String = ""

## Dónde apareció la criatura (centro de su zona).
var punto_origen: Vector2 = Vector2.ZERO
## El jugador (se busca solo por el grupo "player").
var jugador: Node2D = null

var _ocupada := false          # hablando con el jugador
var _integrada := false
var _oculta := false           # Vergüenza: se esconde porque la miran
var _factor_velocidad := 1.0   # sube un poco si la ignoran
var _huyendo := 0.0            # segundos que le quedan de huida (tras ser atacada)
var _temblor := 0.0            # intensidad de la vibración de este fotograma (px)
var _sacudida := 0.0           # segundos que le quedan de sacudida fuerte
var _fuerza_sacudida := 0.0
var _atascada := false         # chocó con algo y casi no avanza
var _distancia_jugador := INF
var _tiempo_quieto_jugador := 0.0
var _pos_jugador_anterior := Vector2.ZERO
var _direccion := Vector2.ZERO # dirección actual al deambular
var _caminando := false        # fase actual de los comportamientos con pausas
var _tween_alpha: Tween
var _tween_flotar: Tween
var _calma_caminando := false
var _calma_tiempo := 0.0
## Frase que dirá el diálogo "despues" (la elige _elegir_frase_despues; el .dialogue la lee).
var frase_despues := 0
var _ultima_frase_despues := -1

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var temporizador: Timer = $Temporizador


func _ready() -> void:
	add_to_group("emociones")
	y_sort_enabled = false  # solo Objetos ordena en Y; la criatura se ordena como un todo por sus pies
	punto_origen = global_position
	temporizador.one_shot = true
	temporizador.timeout.connect(_on_temporizador)

	if datos == null:
		push_warning("Emocion '%s': falta asignar 'datos' (EmocionData)." % name)
		set_physics_process(false)
		return

	_preparar_sprite()

	# Si ya estaba integrada, vuelve en calma y sin comportamiento
	if GameState.estado.get(datos.id, "pendiente") == "integrada":
		_entrar_en_calma()
	else:
		_reproducir(ANIMACION_IDLE)
		# Los comportamientos con pausas arrancan en momentos distintos para no moverse todas igual
		temporizador.start(randf_range(0.1, 1.2))


func _physics_process(delta: float) -> void:
	_temblor = 0.0
	if _ocupada:
		velocity = Vector2.ZERO
		_aplicar_vibracion(delta)
		return

	_actualizar_jugador(delta)

	if _integrada:
		# Ya fue escuchada: deambula despacio y flota con su animación "calma"
		_mover_calma(delta)
		_limitar_a_la_zona(delta)
		move_and_slide()
		_aplicar_vibracion(delta)
		return

	if _huyendo > 0.0:
		_huyendo -= delta
		_huir_del_jugador(_velocidad() * 1.3, 2.5, delta)
	elif jugador != null and jugador.global_position.distance_to(punto_origen) > radio_zona * 1.5:
		_volver_al_origen(delta)
	else:
		match datos.comportamiento:
			EmocionData.Comportamiento.PERSEGUIR:
				_mover_perseguir(delta)
			EmocionData.Comportamiento.HUIR:
				_mover_huir(delta)
			EmocionData.Comportamiento.ERRAR:
				_mover_errar(delta)
			EmocionData.Comportamiento.ACERCARSE_SI_QUIETO:
				_mover_acercarse_si_quieto(delta)
			EmocionData.Comportamiento.SEGUIR_SOMBRA:
				_mover_seguir_sombra(delta)
			EmocionData.Comportamiento.ERRATICO:
				_mover_erratico(delta)
			EmocionData.Comportamiento.ESCONDERSE:
				_mover_esconderse(delta)

	_limitar_a_la_zona(delta)
	move_and_slide()
	_atascada = get_slide_collision_count() > 0 and get_real_velocity().length() < _velocidad() * 0.3
	_aplicar_vibracion(delta)


# --- Sprite ---

## true si el AnimatedSprite2D tiene una animación "idle" con cuadros.
func _sprite_tiene_cuadros() -> bool:
	var frames := sprite.sprite_frames
	return frames != null and frames.has_animation(ANIMACION_IDLE) and frames.get_frame_count(ANIMACION_IDLE) > 0


## Usa los SpriteFrames de la escena; si no tiene, usa datos.frames de respaldo.
## Si no hay ninguno, avisa en la consola (la criatura queda invisible pero funciona).
func _preparar_sprite() -> void:
	if not _sprite_tiene_cuadros() and datos.frames != null:
		sprite.sprite_frames = datos.frames
	if not _sprite_tiene_cuadros():
		push_warning("Emocion '%s' (%s): sin sprite. Asigna 'sprite_frames' al AnimatedSprite2D de la escena o el campo 'frames' en su EmocionData (Resources/Emociones/frames_%s.tres) con las animaciones 'idle' y 'calma'." % [name, datos.id, datos.id])


## Reproduce una animación solo si existe (así no falla en silencio ni da errores).
func _reproducir(animacion: StringName) -> void:
	if sprite.sprite_frames != null and sprite.sprite_frames.has_animation(animacion):
		sprite.play(animacion)


## Velocidad actual (la de los datos, más lo que haya subido por ser ignorada).
func _velocidad() -> float:
	return datos.velocidad * _factor_velocidad


# --- Información del jugador ---

func _actualizar_jugador(delta: float) -> void:
	if not is_instance_valid(jugador):
		jugador = get_tree().get_first_node_in_group("player") as Node2D
	if jugador == null:
		_distancia_jugador = INF
		return
	_distancia_jugador = global_position.distance_to(jugador.global_position)
	# ¿Cuánto lleva quieto el jugador? (se mide por cuánto se movió desde el fotograma anterior)
	if jugador.global_position.distance_to(_pos_jugador_anterior) < 0.3:
		_tiempo_quieto_jugador += delta
	else:
		_tiempo_quieto_jugador = 0.0
	_pos_jugador_anterior = jugador.global_position


## Dirección desde el jugador hacia la criatura (para alejarse de él).
func _direccion_de_huida() -> Vector2:
	var d := global_position - jugador.global_position
	return d.normalized() if d.length() > 0.01 else Vector2.RIGHT


# --- Utilidades de movimiento ---

func _ir_hacia(objetivo_dir: Vector2, rapidez: float, delta: float, aceleracion: float = ACELERACION) -> void:
	velocity = velocity.move_toward(objetivo_dir * rapidez, aceleracion * delta)


func _detener(delta: float, frenado: float = 1.5) -> void:
	velocity = velocity.move_toward(Vector2.ZERO, ACELERACION * frenado * delta)


## Quita la parte del movimiento que la sacaría de su zona (así nunca pasa del radio).
func _limitar_a_la_zona(delta: float) -> void:
	var futuro := global_position + velocity * delta - punto_origen
	if futuro.length() > radio_zona:
		var hacia_afuera := futuro.normalized()
		var salida := velocity.dot(hacia_afuera)
		if salida > 0.0:
			velocity -= hacia_afuera * salida


func _en_borde_de_la_zona(hacia: Vector2) -> bool:
	var desde_origen := global_position - punto_origen
	return desde_origen.length() > radio_zona - 12.0 and hacia.dot(desde_origen.normalized()) > 0.0


## Vuelve despacio a su origen cuando el jugador está muy lejos.
func _volver_al_origen(delta: float) -> void:
	var hacia := punto_origen - global_position
	if hacia.length() > 6.0:
		_ir_hacia(hacia.normalized(), _velocidad() * 0.5, delta)
	else:
		_detener(delta)


## Elige una dirección al azar (inclinada hacia el origen si se alejó mucho).
func _elegir_direccion() -> Vector2:
	var d := Vector2.from_angle(randf() * TAU)
	var hacia_origen := punto_origen - global_position
	if hacia_origen.length() > radio_zona * 0.7:
		d = (hacia_origen.normalized() + d * 0.5).normalized()
	return d


## Los comportamientos con pausas cambian de fase con el Timer.
## Integrada: pasea despacio dentro de su zona, se acerca un poco al jugador si este se queda cerca
## y se aparta si le estorba. Su cuerpo no choca con el del jugador, así que nunca lo empuja.
func _mover_calma(delta: float) -> void:
	_calma_tiempo -= delta
	if _calma_tiempo <= 0.0:
		_calma_caminando = not _calma_caminando
		_calma_tiempo = randf_range(2.0, 4.0) if _calma_caminando else randf_range(1.5, 3.5)
		_direccion = _elegir_direccion() if _calma_caminando else Vector2.ZERO
	var objetivo := Vector2.ZERO
	if jugador != null and _distancia_jugador <= DIST_APARTARSE_CALMA:
		objetivo = _direccion_de_huida() * VELOCIDAD_CALMA * 0.8
	elif jugador != null and _distancia_jugador < DIST_ACERCAR_CALMA and _distancia_jugador > DIST_MINIMA_CALMA:
		objetivo = (jugador.global_position - global_position).normalized() * VELOCIDAD_CALMA * 0.8
	elif _calma_caminando:
		objetivo = _direccion * VELOCIDAD_CALMA
	velocity = velocity.move_toward(objetivo, ACELERACION * 0.3 * delta)


func _on_temporizador() -> void:
	if datos == null or _integrada:
		return
	_caminando = not _caminando
	_direccion = _elegir_direccion() if _caminando else Vector2.ZERO
	temporizador.start(_duracion_fase(_caminando))


func _duracion_fase(caminando: bool) -> float:
	match datos.comportamiento:
		EmocionData.Comportamiento.ERRATICO:
			return RAFAGA_ERRATICA if caminando else PAUSA_ERRATICA
		EmocionData.Comportamiento.ESCONDERSE:
			return randf_range(1.0, 2.0) if caminando else randf_range(1.0, 2.5)
		_:
			return randf_range(1.5, 3.0) if caminando else randf_range(2.5, 4.5)


# --- Comportamientos ---

## Rabia: se acerca al jugador hasta ~28 px y se queda ahí temblando, sin atravesarlo.
func _mover_perseguir(delta: float) -> void:
	if jugador == null:
		_detener(delta)
		return
	var hacia := jugador.global_position - global_position
	var distancia := hacia.length()
	if distancia > DIST_PERSEGUIR + 2.0:
		# Frena al llegar para no pasarse
		var rapidez := minf(_velocidad(), (distancia - DIST_PERSEGUIR) * 6.0)
		_ir_hacia(hacia.normalized(), rapidez, delta)
	else:
		_detener(delta)
		_temblor = 0.6


## Miedo: se aleja si el jugador está a menos de 100 px. Si llega al borde de su zona
## o se arrincona, se detiene y tiembla (así el jugador puede alcanzarla).
func _mover_huir(delta: float) -> void:
	if jugador == null or _distancia_jugador >= DIST_HUIR:
		_detener(delta)
		_temblor = 0.5  # temblor suave
		return
	_huir_del_jugador(_velocidad(), 1.5, delta)


## Se aleja del jugador; si no puede seguir (borde o pared) se queda quieta temblando.
func _huir_del_jugador(rapidez: float, temblor_acorralada: float, delta: float) -> void:
	if jugador == null:
		_detener(delta)
		return
	var lejos := _direccion_de_huida()
	if _en_borde_de_la_zona(lejos) or _atascada:
		_detener(delta, 3.0)
		_temblor = temblor_acorralada
	else:
		_ir_hacia(lejos, rapidez, delta)


## Tristeza: camina lento en una dirección al azar, con pausas largas.
func _mover_errar(delta: float) -> void:
	var objetivo := _direccion * _velocidad() if _caminando else Vector2.ZERO
	velocity = velocity.move_toward(objetivo, ACELERACION * delta)


## Soledad: si el jugador lleva quieto 1.5 s o más se acerca despacio hasta ~36 px.
## Si el jugador se mueve, se queda quieta y retrocede un poco.
func _mover_acercarse_si_quieto(delta: float) -> void:
	if jugador == null:
		_detener(delta)
		return
	var hacia := jugador.global_position - global_position
	if _tiempo_quieto_jugador >= TIEMPO_QUIETO_SOLEDAD:
		if hacia.length() > DIST_SOLEDAD + 2.0:
			_ir_hacia(hacia.normalized(), _velocidad(), delta)
		else:
			_detener(delta)
	elif _distancia_jugador < 60.0:
		_ir_hacia(_direccion_de_huida(), _velocidad() * 0.5, delta)
	else:
		_detener(delta)


## Culpa: sigue al jugador a ~80 px, arrastrándose. Si el jugador se detiene, se detiene a esa distancia.
func _mover_seguir_sombra(delta: float) -> void:
	if jugador == null:
		_detener(delta)
		return
	if _distancia_jugador > DIST_CULPA + 4.0:
		# Aceleración baja: se "arrastra"
		var hacia := (jugador.global_position - global_position).normalized()
		_ir_hacia(hacia, _velocidad(), delta, ACELERACION * 0.35)
	elif _distancia_jugador < DIST_CULPA - 12.0:
		_ir_hacia(_direccion_de_huida(), _velocidad() * 0.5, delta, ACELERACION * 0.35)
	else:
		_detener(delta, 0.5)


## Ansiedad: ráfagas rápidas de 0.3 s en zigzag, seguidas de pausas de 0.4 s en las que
## vibra (más si el jugador está cerca).
func _mover_erratico(delta: float) -> void:
	if _caminando:
		# El zigzag cambia de lado cada 0.1 s
		var transcurrido := RAFAGA_ERRATICA - temporizador.time_left
		var lado := 1.0 if int(transcurrido / 0.1) % 2 == 0 else -1.0
		velocity = _direccion.rotated(deg_to_rad(45.0) * lado) * _velocidad()
	else:
		velocity = Vector2.ZERO
		var cerca := 0.0
		if _distancia_jugador < INF:
			cerca = clampf(1.0 - _distancia_jugador / 150.0, 0.0, 1.0)
		_temblor = 1.0 + cerca * 2.5


## Vergüenza: deambula lento. Si el jugador está a menos de 90 px y la mira de frente
## (su 'facing' apunta hacia ella), se vuelve semitransparente, se aleja despacio y no
## se puede interactuar con ella. Si no la mira de frente, se queda visible.
func _mover_esconderse(delta: float) -> void:
	var la_miran := false
	if jugador != null and _distancia_jugador < DIST_VERGUENZA and "facing" in jugador:
		var del_jugador_a_ella := (global_position - jugador.global_position).normalized()
		la_miran = jugador.facing.dot(del_jugador_a_ella) > 0.5
	_establecer_oculta(la_miran)

	if _oculta:
		_ir_hacia(_direccion_de_huida(), _velocidad(), delta)
	else:
		_mover_errar(delta)


func _establecer_oculta(valor: bool) -> void:
	if valor == _oculta:
		return
	_oculta = valor
	if _tween_alpha != null:
		_tween_alpha.kill()
	_tween_alpha = create_tween()
	_tween_alpha.tween_property(self, "modulate:a", ALPHA_ESCONDIDA if _oculta else 1.0, 0.25)


# --- Vibración y sacudida ---

func _aplicar_vibracion(delta: float) -> void:
	var fuerza := _temblor
	if _sacudida > 0.0:
		_sacudida -= delta
		fuerza = maxf(fuerza, _fuerza_sacudida)
	if fuerza > 0.0:
		sprite.offset = Vector2(randf_range(-fuerza, fuerza), randf_range(-fuerza, fuerza))
	else:
		sprite.offset = Vector2.ZERO


## Sacudida fuerte (cuando la atacan).
func _sacudir(fuerza: float, segundos: float) -> void:
	_fuerza_sacudida = fuerza
	_sacudida = segundos


# --- Sombra ---

## Elipse oscura translúcida bajo los pies (se dibuja debajo del sprite).
func _draw() -> void:
	draw_set_transform(Vector2(0, -1), 0.0, Vector2(1.0, 0.4))
	draw_circle(Vector2.ZERO, 11.0, Color(0, 0, 0, 0.3))


# --- Interacción ---

## El jugador puede hablar con ella si no está integrada, ocupada ni escondida.
## Una emoción integrada se puede volver a hablar siempre (con frases cortas); solo se oculta la Vergüenza cuando la miran.
func puede_interactuar() -> bool:
	return datos != null and not _ocupada and not _oculta


## Abre el diálogo, reacciona al resultado y devuelve el control al jugador.
func interactuar() -> void:
	if not puede_interactuar():
		return
	_ocupada = true
	velocity = Vector2.ZERO
	if jugador != null and jugador.has_method("bloquear"):
		jugador.bloquear()

	var estado_antes: String = GameState.estado.get(datos.id, "pendiente")
	var resultado := await _abrir_dialogo()
	if estado_antes == "integrada":
		# Charla de después: no se vuelve a conceder la habilidad ni a repetir el efecto de integración
		if resultado == Dialogo.CANCELADO:
			GloboCierre.mostrar(self, datos.frase_cierre, -72.0)
	elif resultado == Dialogo.CANCELADO and GameState.estado.get(datos.id, "pendiente") == estado_antes:
		# "Ahora no": no es una decisión. Nada cambia, reanuda su vida y se despide con una frase breve
		GloboCierre.mostrar(self, datos.frase_cierre, -72.0)
	else:
		_reaccionar_al_resultado()

	_ocupada = false
	if jugador != null and is_instance_valid(jugador) and jugador.has_method("liberar"):
		jugador.liberar()


func _abrir_dialogo() -> int:
	var ruta := ruta_dialogo if ruta_dialogo != "" else RUTA_DIALOGO % datos.id
	if GameState.estado.get(datos.id, "pendiente") == "integrada":
		# El diálogo de decisión solo se abre con emociones pendientes, atacadas o ignoradas
		if not ResourceLoader.exists(ruta):
			return -1
		_elegir_frase_despues()
		return await Dialogo.mostrar(load(ruta), TITULO_DESPUES, [self])
	if ResourceLoader.exists(ruta):
		return await Dialogo.mostrar(load(ruta), CUE_DIALOGO)
	return await _dialogo_provisional()


## Elige la frase de la charla de después al azar, sin repetir la anterior.
func _elegir_frase_despues() -> void:
	var nueva := randi() % FRASES_DESPUES
	while nueva == _ultima_frase_despues:
		nueva = randi() % FRASES_DESPUES
	_ultima_frase_despues = nueva
	frase_despues = nueva


## Diálogo de emergencia si todavía no existe el .dialogue de esta emoción.
func _dialogo_provisional() -> int:
	var opciones := ["Atacarla", "Ignorarla", "Escucharla"]
	var elegida: int = await Dialogo.preguntar("%s te mira en silencio. ¿Qué haces?" % datos.nombre, opciones)
	var resultados := ["atacada", "ignorada", "integrada"]
	if elegida >= 0 and elegida < resultados.size():
		GameState.resolver(datos.id, resultados[elegida])
	return elegida


func _reaccionar_al_resultado() -> void:
	match GameState.estado.get(datos.id, "pendiente"):
		"integrada":
			_integrar()
		"atacada":
			# Sacudida fuerte y huida (x1.3) unos segundos; luego retoma su comportamiento
			_sacudir(4.0, 0.4)
			_huyendo = SEGUNDOS_HUIDA
		"ignorada":
			# Se oscurece un poco y se vuelve algo más rápida
			sprite.modulate = sprite.modulate.darkened(0.2)
			_factor_velocidad = minf(_factor_velocidad * 1.1, 1.5)
		_:
			pass  # pendiente: no cambia nada


## La criatura fue escuchada: partículas, calma y flotando.
func _integrar() -> void:
	_lanzar_particulas()
	_entrar_en_calma()
	integrada.emit(datos.id)


## Quieta, con la animación "calma" y un leve flotar.
func _entrar_en_calma() -> void:
	_integrada = true
	_oculta = false
	temporizador.stop()
	velocity = Vector2.ZERO
	_huyendo = 0.0
	_calma_caminando = false
	_calma_tiempo = randf_range(0.5, 2.0)
	sprite.modulate = Color.WHITE
	if _tween_alpha != null:
		_tween_alpha.kill()
	modulate.a = 1.0
	_reproducir(ANIMACION_CALMA)
	if _tween_flotar != null:
		_tween_flotar.kill()
	var base_y := sprite.position.y
	_tween_flotar = create_tween().set_loops()
	_tween_flotar.tween_property(sprite, "position:y", base_y - 4.0, 1.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tween_flotar.tween_property(sprite, "position:y", base_y, 1.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


## Ráfaga de 24 partículas del color de la emoción.
func _lanzar_particulas() -> void:
	var p := CPUParticles2D.new()
	p.position = sprite.position
	p.amount = 24
	p.one_shot = true
	p.explosiveness = 1.0
	p.lifetime = 0.9
	p.direction = Vector2.UP
	p.spread = 180.0
	p.gravity = Vector2.ZERO
	p.initial_velocity_min = 30.0
	p.initial_velocity_max = 80.0
	p.scale_amount_min = 2.0
	p.scale_amount_max = 3.0
	var degradado := Gradient.new()
	degradado.set_color(0, datos.color)
	degradado.set_color(1, Color(datos.color, 0.0))
	p.color_ramp = degradado
	add_child(p)
	p.emitting = true
	get_tree().create_timer(p.lifetime + 0.2).timeout.connect(p.queue_free)
