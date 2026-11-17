class_name Final
extends Control
## La secuencia final: un espejo grande frente al protagonista. Según GameState.calcular_final():
##   BUENO  (7 integradas)  las 7 emociones aparecen una a una en su forma "calma", con su luz y su color, y el
##                          mundo del fondo recupera todo su color.
##   NEUTRO                 solo aparecen las integradas; las demás son siluetas tenues. El mundo recupera parte
##                          del color. Opción: volver al mundo a seguir explorando o cerrar el viaje.
##   DIFÍCIL                la mayoría son siluetas grises. Invitación (nunca culpa) a volver al Pasado o a cerrar.
## Si GameState.recuerdos_completos, al cerrar el reflejo recita lo que aprendió de cada emoción (un globo, una
## línea tras otra) y, con los 7 regalos de los santuarios, los menciona.
## Después: la evaluación final (Cuestionario "post", sin consentimiento) y la pantalla de resultados.
## Nunca hay softlock: siempre se puede volver al mundo (cancelar también vuelve) o terminar.

const ESCENA_MUNDO := "res://Scenes/Mundo/Mundo.tscn"
const ESCENA_TITULO := "res://Scenes/UI/PantallaTitulo.tscn"
const FONDO := "res://Assets/UI/fondo_titulo.png"
const SHADER := preload("res://Shaders/final_color.gdshader")
const FRAMES_GUIA := preload("res://Resources/Personajes/frames_guia.tres")
const ESCENA_JUGADOR := "res://Scenes/Personajes/Player.tscn"

const CENTRO_ESPEJO := Vector2(320, 142)
## Dónde van las 7 emociones (en el orden de EmocionData.orden), alrededor del espejo.
const PUESTOS := [Vector2(168, 78), Vector2(168, 150), Vector2(168, 222), Vector2(320, 34), Vector2(472, 78), Vector2(472, 150), Vector2(472, 222)]
const SEGUNDOS_ENTRE_EMOCIONES := 0.9

## Si es true, no espera a ninguna pulsación (para las pruebas automáticas).
var modo_prueba := false
## Se emite cuando termina del todo (justo antes de cambiar de escena); sirve para las pruebas.
signal secuencia_terminada(destino: String)

var tipo := ""
var _fondo: TextureRect
var _material := ShaderMaterial.new()
var _espejo: EspejoFinal
var _reflejo: AnimatedSprite2D
var _guia: AnimatedSprite2D
var _emociones: Dictionary = {}     # id -> {sprite, brillo}
var _blanco: ColorRect
var _negro: ColorRect
var _terminando := false


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	tipo = GameState.calcular_final()
	_construir()
	_secuencia()


func _exit_tree() -> void:
	Dialogo.retratos.erase("Guía")


# --- Construcción ---

func _construir() -> void:
	_fondo = TextureRect.new()
	if ResourceLoader.exists(FONDO):
		_fondo.texture = load(FONDO)
	_fondo.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fondo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_fondo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_fondo.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_material.shader = SHADER
	_material.set_shader_parameter("color_amount", 0.0)
	_fondo.material = _material
	add_child(_fondo)
	var velo := ColorRect.new()
	velo.color = Color(0.05, 0.03, 0.1, 0.55)
	velo.set_anchors_preset(Control.PRESET_FULL_RECT)
	velo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(velo)

	_espejo = EspejoFinal.new()
	_espejo.position = CENTRO_ESPEJO
	add_child(_espejo)

	# El reflejo (de frente, dentro del espejo) y el protagonista (de espaldas, frente a él)
	var frames := _frames_del_jugador()
	if frames != null:
		_reflejo = AnimatedSprite2D.new()
		_reflejo.sprite_frames = frames
		_reflejo.animation = &"walk_down"
		_reflejo.frame = 0
		_reflejo.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_reflejo.position = CENTRO_ESPEJO + Vector2(0, 22)
		_reflejo.scale = Vector2(2.2, 2.2)
		_reflejo.modulate = Color(0.78, 0.88, 1.0, 0.0)
		add_child(_reflejo)
		var jugador := AnimatedSprite2D.new()
		jugador.sprite_frames = frames
		jugador.animation = &"walk_up"
		jugador.frame = 0
		jugador.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		jugador.position = Vector2(320, 322)
		jugador.scale = Vector2(2.4, 2.4)
		add_child(jugador)

	# Las emociones (siluetas tenues hasta que aparecen)
	var ids := GameState.ids_emociones()
	for i in ids.size():
		var datos := GameState.obtener_datos(ids[i])
		var contenedor := Node2D.new()
		contenedor.position = PUESTOS[mini(i, PUESTOS.size() - 1)]
		add_child(contenedor)
		var brillo := Sprite2D.new()
		brillo.texture = Atmosfera.crear_textura_luz(128)
		brillo.modulate = Color(datos.color, 0.0)
		brillo.scale = Vector2(1.5, 1.5)
		var mezcla := CanvasItemMaterial.new()
		mezcla.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		brillo.material = mezcla
		contenedor.add_child(brillo)
		var sprite := AnimatedSprite2D.new()
		sprite.sprite_frames = datos.frames
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sprite.scale = Vector2(1.2, 1.2)
		if datos.frames != null:
			sprite.play(&"calma" if datos.frames.has_animation(&"calma") else &"idle")
		sprite.modulate.a = 0.0
		contenedor.add_child(sprite)
		_emociones[datos.id] = {"sprite": sprite, "brillo": brillo, "datos": datos}

	_guia = AnimatedSprite2D.new()
	_guia.sprite_frames = FRAMES_GUIA
	_guia.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_guia.scale = Vector2(2.0, 2.0)
	_guia.position = Vector2(70, 300)
	_guia.play(&"idle")
	add_child(_guia)
	Dialogo.retratos["Guía"] = FRAMES_GUIA.get_frame_texture("idle", 0)

	_negro = ColorRect.new()
	_negro.color = Color(0.03, 0.02, 0.06, 0.0)
	_negro.set_anchors_preset(Control.PRESET_FULL_RECT)
	_negro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_negro)
	_blanco = ColorRect.new()
	_blanco.color = Color.WHITE
	_blanco.set_anchors_preset(Control.PRESET_FULL_RECT)
	_blanco.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_blanco)


## Los fotogramas del jugador (se leen de Player.tscn sin añadirlo al árbol).
func _frames_del_jugador() -> SpriteFrames:
	var escena := load(ESCENA_JUGADOR) as PackedScene
	if escena == null:
		return null
	var nodo := escena.instantiate()
	var sprite := nodo.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	var frames: SpriteFrames = sprite.sprite_frames if sprite != null else null
	nodo.free()
	return frames


# --- Secuencia ---

func _secuencia() -> void:
	# El fundido a blanco de la puerta se acaba: aquí se aparece desde el blanco
	for viejo in get_tree().get_nodes_in_group("fundido_final"):
		viejo.queue_free()
	Sonido.musica("final_%s" % ("dificil" if tipo == "dificil" else tipo), 2.0)
	create_tween().tween_property(_blanco, "color:a", 0.0, 1.6)
	if _reflejo != null:
		create_tween().tween_property(_reflejo, "modulate:a", 0.9, 2.0).set_delay(0.8)
	await _esperar(1.8)

	# Cuánto color recupera el mundo
	var integradas := GameState.cantidad_integradas()
	var total := maxi(GameState.ids_emociones().size(), 1)
	var color_final := 1.0
	match tipo:
		"neutro":
			color_final = 0.3 + 0.55 * float(integradas) / total
		"dificil":
			color_final = 0.12 + 0.3 * float(integradas) / total
	create_tween().tween_property(_material, "shader_parameter/color_amount", color_final, maxf(3.0, integradas * SEGUNDOS_ENTRE_EMOCIONES + 2.0))
	var brillo_espejo := create_tween()
	brillo_espejo.tween_property(_espejo, "brillo", 0.35 + 0.65 * float(integradas) / total, 3.0)

	# Las emociones: las integradas aparecen una a una; las demás, como siluetas tenues
	for id in GameState.ids_emociones():
		if GameState.estado.get(id, "pendiente") != "integrada":
			_silueta(id)
	for id in GameState.ids_emociones():
		if GameState.estado.get(id, "pendiente") == "integrada":
			_aparecer(id)
			await _esperar(SEGUNDOS_ENTRE_EMOCIONES)
	await _esperar(0.8)

	match tipo:
		"bueno":
			await _decir("Guía", "No las venciste. Las escuchaste. Por eso el mundo recuperó su color.")
			await _decir("Reflejo", "Lo que atiendes hoy define el mundo de mañana.")
		"neutro":
			await _decir("Guía", "Algunas emociones ya caminan contigo. Otras todavía esperan, y no pasa nada: siguen ahí cuando quieras volver.")
			if await _elegir_volver("Volver al mundo a seguir explorando", false):
				return
		_:
			await _decir("Guía", ["El mundo sigue gris. Eso no es un fracaso: es una invitación.", "Lo que se ataca o se ignora no desaparece, espera."])
			if await _elegir_volver("Volver al Pasado a escucharlas", true):
				return
	await _cerrar_viaje()


## Hace aparecer una emoción integrada, en calma, con su luz.
func _aparecer(id: String) -> void:
	var e: Dictionary = _emociones[id]
	var sprite: AnimatedSprite2D = e["sprite"]
	var datos: EmocionData = e["datos"]
	sprite.modulate = Color.WHITE
	sprite.modulate.a = 0.0
	var t := create_tween().set_parallel(true)
	t.tween_property(sprite, "modulate:a", 1.0, 1.0)
	t.tween_property(e["brillo"], "modulate:a", 0.55, 1.2)
	var flote := sprite.create_tween().set_loops()
	flote.tween_property(sprite, "position:y", -4.0, 1.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	flote.tween_property(sprite, "position:y", 0.0, 1.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	Sonido.efecto("emo_%s_integrada" % datos.id)


## Las emociones que aún esperan: una silueta gris y tenue (nada de culpa, solo un lugar vacío).
func _silueta(id: String) -> void:
	var e: Dictionary = _emociones[id]
	var sprite: AnimatedSprite2D = e["sprite"]
	sprite.modulate = Color(0.16, 0.16, 0.24, 0.0)
	create_tween().tween_property(sprite, "modulate:a", 0.5, 1.4)


## Muestra un texto (con el balloon de siempre). En pruebas no espera a nadie.
func _decir(quien: String, texto: Variant) -> void:
	_hablar(quien == "Guía", true)
	await Dialogo.mostrar_texto(quien, texto)
	_hablar(quien == "Guía", false)


func _hablar(es_guia: bool, hablando: bool) -> void:
	if es_guia and _guia != null:
		_guia.play(&"hablar" if hablando else &"idle")


## La decisión de los finales neutro y difícil. Devuelve true si se vuelve al mundo (también al cancelar:
## nunca se queda atrapado). "Cerrar mi viaje" sigue hacia la evaluación final.
func _elegir_volver(texto_volver: String, al_pasado: bool) -> bool:
	_hablar(true, true)
	var elegida := await Dialogo.mostrar_texto("Guía", "¿Qué quieres hacer?", [texto_volver, "Cerrar mi viaje"])
	_hablar(true, false)
	if elegida == 1:
		return false
	await _volver_al_mundo(al_pasado)
	return true


func _volver_al_mundo(al_pasado: bool) -> void:
	if _terminando:
		return
	_terminando = true
	if al_pasado:
		GameState.epoca = "pasado"
	# Todo el estado sigue intacto; el jugador reaparece delante de la Puerta del Reflejo
	GameState.restaurar_posicion = GameState.tiene_posicion
	var t := create_tween()
	t.tween_property(_blanco, "color:a", 1.0, 1.0)
	await t.finished
	secuencia_terminada.emit("mundo")
	if not modo_prueba:
		get_tree().change_scene_to_file(ESCENA_MUNDO)


## Cierra el viaje: epílogo, evaluación final y resultados.
func _cerrar_viaje() -> void:
	if _terminando:
		return
	_terminando = true
	if GameState.recuerdos_completos:
		await _epilogo()
	if GameState.regalos_completos:
		await _decir("Reflejo", "Y llevas contigo los siete regalos: la brasa, la linterna, la gota, la luciérnaga, la cinta, el reloj y el espejo.")
	var t := create_tween()
	t.tween_property(_negro, "color:a", 1.0, 1.5)
	await t.finished
	if Evaluacion.valido:
		await Cuestionario.mostrar(get_tree(), "post")
		await Resultados.mostrar(get_tree())
	secuencia_terminada.emit("titulo")
	# Los resultados ya cambian de escena solos con "Jugar de nuevo" o "Salir"; si no, se vuelve al título
	if not modo_prueba and Resultados.ultimo_destino == "":
		get_tree().change_scene_to_file(ESCENA_TITULO)


## El reflejo recita, en una frase corta por emoción, lo que aprendió (de los textos de los recuerdos).
func _epilogo() -> void:
	var paginas: Array = []
	for id in GameState.ids_emociones():
		var recuerdo := GameState.obtener_recuerdo(id)
		if recuerdo == null or recuerdo.lineas.is_empty():
			continue
		paginas.append(_primera_frase(recuerdo.lineas[recuerdo.lineas.size() - 1]))
	if paginas.is_empty():
		return
	await _decir("Reflejo", paginas)


## La primera frase de un texto (hasta el primer punto).
func _primera_frase(texto: String) -> String:
	var corte := texto.find(". ")
	return texto if corte == -1 else texto.substr(0, corte + 1)


func _esperar(segundos: float) -> void:
	await get_tree().create_timer(0.05 if modo_prueba else segundos).timeout
