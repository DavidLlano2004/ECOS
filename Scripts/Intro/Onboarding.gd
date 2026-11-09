extends Node2D
## Onboarding cinematográfico: el Guía explica el mundo, hace una pregunta por emoción
## (con la criatura apareciendo detrás de él) y se despide abriendo el portal.
##
## Las respuestas se guardan solas en GameState.respuestas_inicio desde el .dialogue.
## El .dialogue llama a mostrar_emocion() y ocultar_emocion() de esta escena (se pasa como estado extra).

## TEMPORAL: a donde se va al terminar. Cambiar por el mapa real en el Paso 3.
const ESCENA_SIGUIENTE := "res://Scenes/Mundo/Mundo.tscn"

const DIALOGO := preload("res://Dialogos/onboarding.dialogue")
const FRAMES_GUIA := preload("res://Resources/Personajes/frames_guia.tres")

const PANTALLA := Vector2(640, 360)
const POSICION_GUIA := Vector2(320, 150)
const POSICION_PORTAL := Vector2(320, 178)  # sobre el aro de piedra de la ilustración
const ALPHA_EMOCION := 0.5
const NOMBRE_GUIA := "Guía"

## Se emite cada vez que aparece la criatura de una pregunta (sirve para probar el orden).
signal emocion_mostrada(id: String)
## Se emite cuando empieza el cierre (el Guía levanta la linterna).
signal cierre_iniciado

@onready var guia: Node2D = $Mundo/Guia
@onready var sprite_guia: AnimatedSprite2D = $Mundo/Guia/Sprite
@onready var linterna: PointLight2D = $Mundo/Guia/Linterna
@onready var contenedor_emociones: Node2D = $Mundo/Emociones
@onready var portal: AnimatedSprite2D = $Mundo/Portal
@onready var luz_portal: PointLight2D = $Mundo/Portal/Luz
@onready var camara: Camera2D = $Camara
@onready var luz_blanca: ColorRect = %LuzBlanca

var _emocion_actual: AnimatedSprite2D = null
var _terminando := false
var _parpadeo_linterna: Tween
var _capas_niebla: Array = []  # [nodo, amplitud, posición base]
var _tiempo := 0.0


func _ready() -> void:
	# Si se abre sola con F6, las respuestas no deben acumularse
	GameState.respuestas_inicio.clear()

	_crear_niebla()
	linterna.texture = Atmosfera.crear_textura_luz(128)
	luz_portal.texture = Atmosfera.crear_textura_luz(128)
	portal.modulate.a = 0.0
	luz_portal.energy = 0.0
	luz_blanca.color.a = 0.0

	# El balloon muestra el primer cuadro del Guía como retrato
	Dialogo.retratos[NOMBRE_GUIA] = FRAMES_GUIA.get_frame_texture("idle", 0)
	# El Guía habla mientras se escribe su línea y espera mientras tanto
	Dialogo.linea_escribiendo.connect(_on_linea_escribiendo)
	Dialogo.linea_terminada.connect(_on_linea_terminada)

	_empezar()


func _exit_tree() -> void:
	# Los autoloads siguen vivos al cambiar de escena: se deshace lo que se registró
	if Dialogo.linea_escribiendo.is_connected(_on_linea_escribiendo):
		Dialogo.linea_escribiendo.disconnect(_on_linea_escribiendo)
	if Dialogo.linea_terminada.is_connected(_on_linea_terminada):
		Dialogo.linea_terminada.disconnect(_on_linea_terminada)
	Dialogo.retratos.erase(NOMBRE_GUIA)


func _process(delta: float) -> void:
	_tiempo += delta
	for capa in _capas_niebla:
		capa[0].position = capa[2] + Vector2(sin(_tiempo * 0.17) * capa[1], cos(_tiempo * 0.11) * capa[1] * 0.4)


# --- Secuencia principal ---

func _empezar() -> void:
	await _aparecer_guia()
	# El cuestionario de entrada NO se puede cancelar ni saltar (ni con "Ahora no" ni con ESC): es la
	# evaluación del aprendizaje y debe quedar completo. Lo mismo vale para el cuestionario de salida.
	# Por eso se pasa cancelable = false (y Dialogo.pausa_permitida() devuelve false mientras dura).
	await Dialogo.mostrar(DIALOGO, "start", [self], false)
	ocultar_emocion()
	_avisar_si_faltan_respuestas()
	await _cierre()


## El Guía aparece en el centro con un fundido y empieza a flotar; su linterna se enciende.
func _aparecer_guia() -> void:
	guia.modulate.a = 0.0
	linterna.energy = 0.0
	sprite_guia.play("idle")
	var t := create_tween().set_parallel(true)
	t.tween_property(guia, "modulate:a", 1.0, 1.6)
	t.tween_property(linterna, "energy", 1.0, 1.6)
	await t.finished
	# Flotar arriba y abajo
	var flotar := create_tween().set_loops()
	flotar.tween_property(guia, "position:y", POSICION_GUIA.y - 5.0, 1.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	flotar.tween_property(guia, "position:y", POSICION_GUIA.y + 1.0, 1.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	# La linterna parpadea suave
	_parpadeo_linterna = create_tween().set_loops()
	_parpadeo_linterna.tween_property(linterna, "energy", 0.7, 0.9).set_trans(Tween.TRANS_SINE)
	_parpadeo_linterna.tween_property(linterna, "energy", 1.1, 1.1).set_trans(Tween.TRANS_SINE)
	await get_tree().create_timer(0.6).timeout


# --- Hablar / esperar ---

func _on_linea_escribiendo(personaje: String) -> void:
	if personaje == NOMBRE_GUIA and not _terminando:
		sprite_guia.play("hablar")


func _on_linea_terminada() -> void:
	if not _terminando:
		sprite_guia.play("idle")


# --- Criaturas de las preguntas (las llama el .dialogue con "$> mostrar_emocion(...)") ---

## La criatura aparece detrás y a un lado del Guía, semitransparente y flotando.
func mostrar_emocion(id: String) -> void:
	var datos := GameState.obtener_datos(id)
	if datos == null or datos.frames == null:
		push_warning("Onboarding: no hay datos o frames para la emoción '%s'." % id)
		return
	ocultar_emocion()
	var criatura := AnimatedSprite2D.new()
	criatura.sprite_frames = datos.frames
	criatura.play("idle")
	# Se alternan los lados según el orden: 1 a la derecha, 2 a la izquierda, 3 a la derecha...
	var lado := 1.0 if datos.orden % 2 == 1 else -1.0
	criatura.position = Vector2(POSICION_GUIA.x + lado * 80.0, POSICION_GUIA.y - 12.0)
	criatura.modulate.a = 0.0
	contenedor_emociones.add_child(criatura)
	# Los tweens se crean en la propia criatura: se detienen solos cuando se borra
	var aparecer := criatura.create_tween()
	aparecer.tween_property(criatura, "modulate:a", ALPHA_EMOCION, 0.7)
	var flotar := criatura.create_tween().set_loops()
	flotar.tween_property(criatura, "position:y", criatura.position.y - 6.0, 1.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	flotar.tween_property(criatura, "position:y", criatura.position.y, 1.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_emocion_actual = criatura
	emocion_mostrada.emit(id)


## La criatura actual se desvanece (al responder).
func ocultar_emocion() -> void:
	if _emocion_actual == null or not is_instance_valid(_emocion_actual):
		_emocion_actual = null
		return
	var criatura := _emocion_actual
	_emocion_actual = null
	var t := criatura.create_tween()
	t.tween_property(criatura, "modulate:a", 0.0, 0.45)
	t.tween_callback(criatura.queue_free)


# --- Cierre: portal, zoom y luz blanca ---

func _avisar_si_faltan_respuestas() -> void:
	var esperadas := GameState.ids_emociones().size()
	if GameState.respuestas_inicio.size() != esperadas:
		push_warning("Onboarding: se esperaban %d respuestas y hay %d." % [esperadas, GameState.respuestas_inicio.size()])


func _cierre() -> void:
	if _terminando:
		return
	_terminando = true
	cierre_iniciado.emit()
	sprite_guia.play("idle")

	if _parpadeo_linterna != null:
		_parpadeo_linterna.kill()
	# El Guía levanta la linterna (no hay animación de brazo: sube la luz, que crece) y se aparta un poco
	var levantar := create_tween().set_parallel(true)
	levantar.tween_property(linterna, "position", linterna.position + Vector2(2, -22), 1.0).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	levantar.tween_property(linterna, "energy", 1.8, 1.0)
	levantar.tween_property(linterna, "texture_scale", 1.6, 1.0)
	levantar.tween_property(guia, "position:x", 248.0, 1.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await levantar.finished

	# Aparece el portal frente a él, "dormido"
	portal.play("dormido")
	portal.scale = Vector2(0.75, 0.75)
	var aparecer := create_tween().set_parallel(true)
	aparecer.tween_property(portal, "modulate:a", 1.0, 1.3)
	aparecer.tween_property(portal, "scale", Vector2.ONE, 1.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	aparecer.tween_property(luz_portal, "energy", 0.7, 1.3)
	await aparecer.finished
	await get_tree().create_timer(0.9).timeout

	# El portal despierta
	portal.play("activo")
	var despertar := create_tween().set_parallel(true)
	despertar.tween_property(luz_portal, "energy", 1.8, 0.8)
	despertar.tween_property(luz_portal, "texture_scale", 2.0, 0.8)
	await despertar.finished

	# Zoom lento hacia el portal mientras la pantalla se llena de luz blanca
	var zoom := create_tween().set_parallel(true)
	zoom.tween_property(camara, "zoom", Vector2(2.8, 2.8), 3.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	zoom.tween_property(camara, "position", POSICION_PORTAL, 3.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	zoom.tween_property(luz_portal, "energy", 4.0, 3.4).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	zoom.tween_property(luz_blanca, "color:a", 1.0, 1.7).set_delay(1.7).set_trans(Tween.TRANS_SINE)
	await zoom.finished
	await get_tree().create_timer(0.3).timeout
	get_tree().change_scene_to_file(ESCENA_SIGUIENTE)


# --- Fondo ---

## Niebla suave y lenta (la misma de la pantalla de título).
func _crear_niebla() -> void:
	for datos in [[Vector2(290, 215), Vector2(400, 120), 0.3, 10.0], [Vector2(300, 255), Vector2(380, 100), 0.22, 6.0]]:
		var niebla := Atmosfera.crear_niebla(datos[0], datos[1], datos[2])
		$Mundo.add_child(niebla)
		_capas_niebla.append([niebla, datos[3], niebla.position])
