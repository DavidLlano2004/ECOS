extends Node2D
## Pantalla de título de ECOS (escena principal del proyecto).
##
## Secuencia: negro -> aparece el cielo -> el título "ECOS" letra por letra -> subtítulo -> menú.
## Se puede saltar la entrada con INTERACTUAR o Enter.
## "Comenzar": el título se disuelve hacia arriba, pasa una ola de luz, fundido a negro y onboarding.
## "Continuar": carga la partida guardada y va al juego.

const ESCENA_ONBOARDING := "res://Scenes/Main.tscn"
const ESCENA_JUEGO := "res://Scenes/Mundo/PruebaEmociones.tscn"
const RUTA_FUENTE := "res://Assets/PixelifySans-VariableFont_wght.ttf"

const PANTALLA := Vector2(640, 360)
const DORADO := Color("f4c77b")
const LETRAS_TITULO := "ECOS"
const SEGUNDOS_CIELO := 1.5
const SEGUNDOS_POR_LETRA := 0.32

@onready var mundo: Node2D = $Mundo
@onready var contenedor_letras: HBoxContainer = %Letras
@onready var subtitulo: Label = %Subtitulo
@onready var menu: PanelContainer = %Menu
@onready var boton_comenzar: Button = %Comenzar
@onready var boton_continuar: Button = %Continuar
@onready var boton_salir: Button = %Salir
@onready var negro: ColorRect = %Negro
## Música de fondo. Los sonidos se agregan en el paso de audio (aquí solo queda preparado el reproductor).
@onready var musica: AudioStreamPlayer = $Musica
## Sonido al cambiar de opción en el menú. Se agrega en el paso de audio.
@onready var sonido_seleccion: AudioStreamPlayer = $SonidoSeleccion

var _letras: Array[Label] = []
var _material_brillo: ShaderMaterial
var _en_intro := true
var _eligiendo := false
var _tween_intro: Tween
var _tweens_letras: Array[Tween] = []
var _fuente: Font

# Capas con movimiento suave (parallax): [nodo, amplitud en píxeles, posición base]
var _capas_parallax: Array = []
var _tiempo := 0.0


func _ready() -> void:
	if ResourceLoader.exists(RUTA_FUENTE):
		_fuente = load(RUTA_FUENTE)
	_crear_fondo()
	_crear_luciernagas()
	_crear_titulo()
	_aplicar_estilo_menu()
	_preparar_menu()

	# Todo empieza en negro absoluto
	negro.color.a = 1.0
	subtitulo.modulate.a = 0.0
	menu.modulate.a = 0.0
	menu.visible = false
	_iniciar_intro()


func _process(delta: float) -> void:
	# Movimiento lento de las capas: cada una se desplaza un poco distinto
	_tiempo += delta
	for capa in _capas_parallax:
		var nodo = capa[0]  # Node2D o Control: los dos tienen "position"
		var amplitud: float = capa[1]
		nodo.position = capa[2] + Vector2(sin(_tiempo * 0.17) * amplitud, cos(_tiempo * 0.11) * amplitud * 0.4)


func _unhandled_input(evento: InputEvent) -> void:
	# Saltar la animación de entrada
	if _en_intro and (evento.is_action_pressed("INTERACTUAR") or evento.is_action_pressed("ui_accept")):
		get_viewport().set_input_as_handled()
		_saltar_intro()
		return
	if _en_intro or _eligiendo:
		return
	var foco := get_viewport().gui_get_focus_owner()
	if foco == null:
		return
	# W/S (acciones del juego) también mueven el foco del menú
	if evento.is_action_pressed("ABAJO"):
		get_viewport().set_input_as_handled()
		foco.find_next_valid_focus().grab_focus()
	elif evento.is_action_pressed("ARRIBA"):
		get_viewport().set_input_as_handled()
		foco.find_prev_valid_focus().grab_focus()
	elif evento.is_action_pressed("INTERACTUAR") and foco is Button:
		get_viewport().set_input_as_handled()
		foco.pressed.emit()


# --- Fondo: cielo nocturno generado por código ---

func _crear_fondo() -> void:
	# Degradado: morado oscuro arriba, violeta y un toque naranja en el horizonte
	var degradado := Gradient.new()
	degradado.offsets = PackedFloat32Array([0.0, 0.7, 1.0])
	degradado.colors = PackedColorArray([Color("120c2a"), Color("5b3a8c"), Color("f08c50")])
	var textura := GradientTexture2D.new()
	textura.gradient = degradado
	textura.fill_from = Vector2(0.5, 0.0)
	textura.fill_to = Vector2(0.5, 1.0)
	textura.width = 8
	textura.height = 256
	var cielo := TextureRect.new()
	cielo.texture = textura
	cielo.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR  # sin bandas
	cielo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	cielo.stretch_mode = TextureRect.STRETCH_SCALE
	cielo.size = PANTALLA
	mundo.add_child(cielo)

	# Estrellas en dos capas (lejanas y cercanas) que titilan
	for datos in [[70, 1.0, 3.0], [26, 2.0, 5.0]]:
		var capa := Node2D.new()
		mundo.add_child(capa)
		for i in int(datos[0]):
			var estrella := ColorRect.new()
			estrella.size = Vector2(datos[1], datos[1])
			estrella.position = Vector2(randf_range(0, PANTALLA.x), randf_range(0, PANTALLA.y * 0.65))
			estrella.color = Color(1.0, 0.95, 0.8, randf_range(0.4, 1.0))
			capa.add_child(estrella)
			var t := create_tween().set_loops()
			var pausa := randf_range(0.8, 2.4)
			t.tween_interval(randf_range(0.0, 2.0))
			t.tween_property(estrella, "modulate:a", randf_range(0.1, 0.35), pausa)
			t.tween_property(estrella, "modulate:a", 1.0, pausa)
		_capas_parallax.append([capa, datos[2], capa.position])

	# Niebla suave que se desplaza lento
	for datos in [[200.0, 0.22, 14.0], [260.0, 0.16, 8.0]]:
		var niebla := _crear_niebla(Vector2(-60, datos[0]), Vector2(PANTALLA.x + 120, 130), datos[1])
		mundo.add_child(niebla)
		_capas_parallax.append([niebla, datos[2], niebla.position])

	# Tinte dividido: Pasado cálido (izquierda), Presente frío (derecha), con transición que ondula
	var tinte := ColorRect.new()
	tinte.name = "TinteDivision"
	tinte.size = PANTALLA
	tinte.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var material := ShaderMaterial.new()
	material.shader = load("res://Shaders/tinte_division.gdshader")
	tinte.material = material
	mundo.add_child(tinte)

	# El cielo aparece al irse el negro: ver _iniciar_intro()


## Una franja de niebla: ruido suave con transparencia.
func _crear_niebla(posicion: Vector2, tamano: Vector2, opacidad: float) -> TextureRect:
	var ruido := FastNoiseLite.new()
	ruido.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	ruido.frequency = 0.012
	ruido.seed = randi()
	var rampa := Gradient.new()
	rampa.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	rampa.colors = PackedColorArray([Color(0.8, 0.85, 1.0, 0.0), Color(0.8, 0.85, 1.0, 0.5), Color(0.9, 0.92, 1.0, 1.0)])
	var textura := NoiseTexture2D.new()
	textura.noise = ruido
	textura.width = 256
	textura.height = 96
	textura.seamless = true
	textura.color_ramp = rampa
	var rect := TextureRect.new()
	rect.texture = textura
	rect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.position = posicion
	rect.size = tamano
	rect.modulate.a = opacidad
	var material := ShaderMaterial.new()
	material.shader = load("res://Shaders/niebla.gdshader")
	rect.material = material
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect


# --- Luciérnagas doradas ---

func _crear_luciernagas() -> void:
	var punto := Gradient.new()
	punto.set_color(0, Color.WHITE)
	punto.set_color(1, Color(1, 1, 1, 0))
	var textura := GradientTexture2D.new()
	textura.gradient = punto
	textura.fill = GradientTexture2D.FILL_RADIAL
	textura.fill_from = Vector2(0.5, 0.5)
	textura.fill_to = Vector2(1.0, 0.5)
	textura.width = 12
	textura.height = 12

	var rampa_alfa := Gradient.new()
	rampa_alfa.offsets = PackedFloat32Array([0.0, 0.25, 0.75, 1.0])
	rampa_alfa.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 1), Color(1, 1, 1, 1), Color(1, 1, 1, 0)])

	var p := CPUParticles2D.new()
	p.name = "Luciernagas"
	p.texture = textura
	p.amount = 46
	p.lifetime = 9.0
	p.preprocess = 9.0  # ya hay luciérnagas flotando desde el primer cuadro
	p.position = PANTALLA / 2.0
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = PANTALLA / 2.0
	p.direction = Vector2.UP
	p.spread = 180.0
	p.gravity = Vector2.ZERO
	p.initial_velocity_min = 3.0
	p.initial_velocity_max = 11.0
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.1
	p.color = Color(1.0, 0.82, 0.4, 0.95)
	p.color_ramp = rampa_alfa
	mundo.add_child(p)


# --- Título y subtítulo ---

func _crear_titulo() -> void:
	_material_brillo = ShaderMaterial.new()
	_material_brillo.shader = load("res://Shaders/titulo_brillo.gdshader")
	for letra in LETRAS_TITULO:
		var caja := Control.new()
		caja.custom_minimum_size = Vector2(46, 66)
		caja.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var etiqueta := Label.new()
		etiqueta.text = letra
		etiqueta.material = _material_brillo
		etiqueta.add_theme_font_size_override("font_size", 60)
		etiqueta.add_theme_color_override("font_color", Color("f6c36a"))
		etiqueta.add_theme_color_override("font_outline_color", Color("1a1030"))
		etiqueta.add_theme_constant_override("outline_size", 8)
		if _fuente != null:
			etiqueta.add_theme_font_override("font", _fuente)
		etiqueta.modulate.a = 0.0
		etiqueta.position = Vector2(0, 12)
		caja.add_child(etiqueta)
		contenedor_letras.add_child(caja)
		_letras.append(etiqueta)

	if _fuente != null:
		subtitulo.add_theme_font_override("font", _fuente)
	subtitulo.add_theme_font_size_override("font_size", 14)
	subtitulo.add_theme_color_override("font_color", Color("fff4dc"))
	subtitulo.add_theme_color_override("font_outline_color", Color("1a1030"))
	subtitulo.add_theme_constant_override("outline_size", 5)


# --- Entrada animada ---

func _iniciar_intro() -> void:
	_tween_intro = create_tween()
	# Un instante de negro absoluto -> aparece el cielo
	_tween_intro.tween_interval(0.4)
	_tween_intro.tween_property(negro, "color:a", 0.0, SEGUNDOS_CIELO)
	_tween_intro.tween_interval(0.3)
	# Letra por letra, con fundido y una pequeña subida
	for i in _letras.size():
		_tween_intro.tween_callback(_animar_letra.bind(i))
		_tween_intro.tween_interval(SEGUNDOS_POR_LETRA)
	_tween_intro.tween_interval(0.5)
	_tween_intro.tween_property(subtitulo, "modulate:a", 1.0, 1.0)
	_tween_intro.tween_interval(0.3)
	_tween_intro.tween_callback(_mostrar_menu)


func _animar_letra(indice: int) -> void:
	var letra := _letras[indice]
	var t := create_tween().set_parallel(true)
	t.tween_property(letra, "modulate:a", 1.0, 0.5)
	t.tween_property(letra, "position:y", 0.0, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tweens_letras.append(t)


func _mostrar_menu() -> void:
	_en_intro = false
	menu.visible = true
	var t := create_tween()
	t.tween_property(menu, "modulate:a", 1.0, 0.5)
	_enfocar_primera_opcion()


## Salta directo al título completo y al menú.
func _saltar_intro() -> void:
	if _tween_intro != null:
		_tween_intro.kill()
	for t in _tweens_letras:
		t.kill()
	negro.color.a = 0.0
	for letra in _letras:
		letra.modulate.a = 1.0
		letra.position = Vector2.ZERO
	subtitulo.modulate.a = 1.0
	_en_intro = false
	menu.visible = true
	menu.modulate.a = 1.0
	_enfocar_primera_opcion()


# --- Menú ---

func _preparar_menu() -> void:
	boton_continuar.visible = GameState.hay_partida_guardada()
	for boton in [boton_comenzar, boton_continuar, boton_salir]:
		boton.focus_entered.connect(_on_foco_cambiado.bind(boton))
		boton.mouse_entered.connect(boton.grab_focus)
	boton_comenzar.pressed.connect(_comenzar)
	boton_continuar.pressed.connect(_continuar)
	boton_salir.pressed.connect(_salir)


func _enfocar_primera_opcion() -> void:
	var primera: Button = boton_continuar if boton_continuar.visible else boton_comenzar
	primera.grab_focus()


## Pequeño rebote del botón que recibe el foco.
func _on_foco_cambiado(boton: Button) -> void:
	_sonido_seleccion()
	boton.pivot_offset = boton.size / 2.0
	boton.scale = Vector2(1.12, 1.12)
	var t := create_tween()
	t.tween_property(boton, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Reproduce el sonido de selección si ya tiene un archivo asignado (se agrega en el paso de audio).
func _sonido_seleccion() -> void:
	if sonido_seleccion.stream != null and not _en_intro:
		sonido_seleccion.play()


func _aplicar_estilo_menu() -> void:
	var tema := Theme.new()
	if _fuente != null:
		tema.set_font("font", "Button", _fuente)
	tema.set_font_size("font_size", "Button", 16)
	tema.set_color("font_color", "Button", Color("d9cfe8"))
	tema.set_color("font_hover_color", "Button", DORADO)
	tema.set_color("font_focus_color", "Button", DORADO)
	tema.set_stylebox("normal", "Button", _crear_caja(Color("2d2845"), Color("2d2845"), 1, 4))
	tema.set_stylebox("hover", "Button", _crear_caja(Color("3a3358"), DORADO, 2, 4))
	tema.set_stylebox("pressed", "Button", _crear_caja(Color("4a4170"), DORADO, 2, 4))
	tema.set_stylebox("focus", "Button", _crear_caja(Color("3a3358"), DORADO, 2, 4))
	menu.theme = tema
	# Caja del menú: morado oscuro semitransparente con borde dorado
	menu.add_theme_stylebox_override("panel", _crear_caja(Color("1e1b2e", 0.88), DORADO, 2, 8))


func _crear_caja(fondo: Color, borde: Color, grosor: int, margen: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = fondo
	s.border_color = borde
	s.set_border_width_all(grosor)
	s.set_corner_radius_all(4)
	s.set_content_margin_all(margen)
	return s


# --- Acciones del menú ---

func _comenzar() -> void:
	if _eligiendo:
		return
	_eligiendo = true
	GameState.nueva_partida()
	var t := create_tween()
	t.tween_property(menu, "modulate:a", 0.0, 0.3)
	t.tween_callback(_disolver_titulo)
	t.tween_interval(1.6)
	t.tween_property(negro, "color:a", 1.0, 0.7)
	t.tween_callback(get_tree().change_scene_to_file.bind(ESCENA_ONBOARDING))


func _continuar() -> void:
	if _eligiendo:
		return
	if not GameState.cargar():
		boton_continuar.visible = false
		boton_comenzar.grab_focus()
		return
	_eligiendo = true
	var t := create_tween()
	t.tween_property(menu, "modulate:a", 0.0, 0.3)
	t.tween_property(negro, "color:a", 1.0, 0.7)
	t.tween_callback(get_tree().change_scene_to_file.bind(ESCENA_JUEGO))


func _salir() -> void:
	get_tree().quit()


## El título se disuelve hacia arriba en chispas doradas mientras una ola de luz cruza la pantalla.
func _disolver_titulo() -> void:
	var ruido := FastNoiseLite.new()
	ruido.frequency = 0.04
	var textura_ruido := NoiseTexture2D.new()
	textura_ruido.noise = ruido
	textura_ruido.width = 128
	textura_ruido.height = 128
	var material := ShaderMaterial.new()
	material.shader = load("res://Shaders/disolver.gdshader")
	material.set_shader_parameter("ruido", textura_ruido)
	material.set_shader_parameter("progreso", 0.0)
	for letra in _letras:
		letra.material = material
	subtitulo.material = material

	var t := create_tween().set_parallel(true)
	t.tween_method(func(valor: float) -> void: material.set_shader_parameter("progreso", valor), 0.0, 1.0, 1.5)

	_lanzar_chispas()
	_ola_de_luz()


func _lanzar_chispas() -> void:
	var chispas := CPUParticles2D.new()
	chispas.position = Vector2(PANTALLA.x / 2.0, 70.0)
	chispas.amount = 120
	chispas.lifetime = 1.6
	chispas.one_shot = true
	chispas.explosiveness = 0.25
	chispas.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	chispas.emission_rect_extents = Vector2(110, 30)
	chispas.direction = Vector2.UP
	chispas.spread = 30.0
	chispas.gravity = Vector2(0, -12)
	chispas.initial_velocity_min = 25.0
	chispas.initial_velocity_max = 70.0
	chispas.scale_amount_min = 1.5
	chispas.scale_amount_max = 3.0
	chispas.color = Color("f6c36a")
	var rampa := Gradient.new()
	rampa.set_color(0, Color(1, 1, 1, 1))
	rampa.set_color(1, Color(1, 1, 1, 0))
	chispas.color_ramp = rampa
	$Interfaz.add_child(chispas)
	chispas.emitting = true


## Franja de luz que recorre la pantalla de izquierda a derecha.
func _ola_de_luz() -> void:
	var degradado := Gradient.new()
	degradado.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	degradado.colors = PackedColorArray([Color(1, 0.95, 0.8, 0.0), Color(1, 0.95, 0.8, 0.6), Color(1, 0.95, 0.8, 0.0)])
	var textura := GradientTexture2D.new()
	textura.gradient = degradado
	textura.width = 128
	textura.height = 4
	textura.fill_from = Vector2(0, 0.5)
	textura.fill_to = Vector2(1, 0.5)
	var ola := TextureRect.new()
	ola.texture = textura
	ola.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	ola.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ola.stretch_mode = TextureRect.STRETCH_SCALE
	ola.size = Vector2(150, PANTALLA.y)
	ola.position = Vector2(-150, 0)
	ola.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var suma := CanvasItemMaterial.new()
	suma.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	ola.material = suma
	$Interfaz.add_child(ola)
	var t := create_tween()
	t.tween_property(ola, "position:x", PANTALLA.x + 10.0, 1.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_callback(ola.queue_free)
