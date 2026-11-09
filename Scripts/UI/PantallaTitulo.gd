extends Node2D
## Pantalla de título de ECOS (escena principal del proyecto).
##
## Secuencia: negro -> aparece la ilustración -> el título "ECOS" letra por letra -> subtítulo -> menú.
## Se puede saltar la entrada con INTERACTUAR o Enter.
## "Comenzar": el portal se ilumina con fuerza, el título se disuelve hacia arriba, pasa una ola de luz,
## fundido a negro y onboarding. "Continuar": carga la partida guardada y va al juego.

const ESCENA_ONBOARDING := "res://Scenes/Main.tscn"
const ESCENA_JUEGO := "res://Scenes/Mundo/PruebaEmociones.tscn"
const RUTA_FUENTE := "res://Assets/PixelifySans-VariableFont_wght.ttf"
const FONDO := preload("res://Assets/UI/fondo_titulo.png")

const PANTALLA := Vector2(640, 360)
const DORADO := Color("f4c77b")
const LETRAS_TITULO := "ECOS"
const SEGUNDOS_APARICION := 1.5
const SEGUNDOS_POR_LETRA := 0.32

# Puntos de luz medidos sobre la ilustración (640x360)
const FAROLES := [Vector2(52, 175), Vector2(73, 172), Vector2(105, 152), Vector2(161, 185)]
const CENTRO_PORTAL := Vector2(320, 180)
const RADIO_PORTAL := 37.0  # radio interior del aro
const COLOR_PORTAL_DORADO := Color(1.0, 0.82, 0.45)
const COLOR_PORTAL_AZUL := Color(0.5, 0.72, 1.0)

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

## Todo lo que pertenece a la ilustración (coordenadas de la imagen de 640x360).
## Cuelga de "mundo", que es el que "respira" (escala 1.0 a 1.03).
var _lienzo: Node2D
var _luz_portal: PointLight2D
var _particulas_portal: CPUParticles2D
var _luces_faroles: Array[PointLight2D] = []
var _textura_luz: GradientTexture2D

# Capas con movimiento suave: [nodo, amplitud en píxeles, posición base]
var _capas_parallax: Array = []
var _tiempo := 0.0


func _ready() -> void:
	if ResourceLoader.exists(RUTA_FUENTE):
		_fuente = load(RUTA_FUENTE)
	_crear_fondo()
	_crear_niebla_derecha()
	_crear_luces_faroles()
	_crear_portal()
	_crear_luciernagas()
	_crear_titulo()
	_aplicar_estilo_menu()
	_preparar_menu()
	_iniciar_respiracion()

	# Todo empieza en negro absoluto
	negro.color.a = 1.0
	subtitulo.modulate.a = 0.0
	menu.modulate.a = 0.0
	menu.visible = false
	_iniciar_intro()


func _process(delta: float) -> void:
	# Movimiento lento de la niebla
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


# --- Fondo: la ilustración ---

func _crear_fondo() -> void:
	# "mundo" está en el centro de la pantalla y "_lienzo" compensa, así el zoom parte del centro
	mundo.position = PANTALLA / 2.0
	_lienzo = Node2D.new()
	_lienzo.position = -PANTALLA / 2.0
	mundo.add_child(_lienzo)

	var ilustracion := Sprite2D.new()
	ilustracion.texture = FONDO  # importada con filtro Nearest (pixel art)
	ilustracion.centered = false
	_lienzo.add_child(ilustracion)

	# Textura de luz circular suave que comparten las luces
	var degradado := Gradient.new()
	degradado.set_color(0, Color.WHITE)
	degradado.set_color(1, Color(1, 1, 1, 0))
	_textura_luz = GradientTexture2D.new()
	_textura_luz.gradient = degradado
	_textura_luz.fill = GradientTexture2D.FILL_RADIAL
	_textura_luz.fill_from = Vector2(0.5, 0.5)
	_textura_luz.fill_to = Vector2(1.0, 0.5)
	_textura_luz.width = 128
	_textura_luz.height = 128


## "Respiración": zoom lento entre 1.0 y 1.03 (unos 12 s por ciclo). Nunca baja de 1.0, así no se ven bordes.
func _iniciar_respiracion() -> void:
	var t := create_tween().set_loops()
	t.tween_property(mundo, "scale", Vector2(1.03, 1.03), 6.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(mundo, "scale", Vector2.ONE, 6.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


## Niebla suave que se desplaza lento, solo sobre la mitad derecha (el Presente).
func _crear_niebla_derecha() -> void:
	for datos in [[Vector2(290, 215), Vector2(400, 120), 0.34, 10.0], [Vector2(300, 255), Vector2(380, 100), 0.26, 6.0]]:
		var niebla := _crear_niebla(datos[0], datos[1], datos[2])
		_lienzo.add_child(niebla)
		_capas_parallax.append([niebla, datos[3], niebla.position])


## Una franja de niebla: ruido suave con transparencia y bordes que se desvanecen.
func _crear_niebla(posicion: Vector2, tamano: Vector2, opacidad: float) -> TextureRect:
	var ruido := FastNoiseLite.new()
	ruido.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	ruido.frequency = 0.012
	ruido.seed = randi()
	var rampa := Gradient.new()
	rampa.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	rampa.colors = PackedColorArray([Color(0.8, 0.88, 1.0, 0.0), Color(0.8, 0.88, 1.0, 0.5), Color(0.9, 0.95, 1.0, 1.0)])
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
	material.set_shader_parameter("desvanecer_x", 0.28)
	rect.material = material
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect


# --- Luces de las linternas ---

## Luces cálidas sobre las linternas de los árboles de la izquierda, que parpadean suavemente.
func _crear_luces_faroles() -> void:
	for posicion in FAROLES:
		var luz := PointLight2D.new()
		luz.texture = _textura_luz
		luz.texture_scale = 0.75
		luz.color = Color(1.0, 0.7, 0.35)
		luz.energy = 0.8
		luz.position = posicion
		_lienzo.add_child(luz)
		_luces_faroles.append(luz)
		# Cada linterna parpadea a su ritmo
		var t := create_tween().set_loops()
		t.tween_interval(randf_range(0.0, 1.5))
		t.tween_property(luz, "energy", randf_range(0.45, 0.6), randf_range(0.7, 1.3)).set_trans(Tween.TRANS_SINE)
		t.tween_property(luz, "energy", randf_range(0.85, 1.1), randf_range(0.7, 1.3)).set_trans(Tween.TRANS_SINE)


# --- Portal ---

## Partículas en espiral dentro del aro y una luz tenue que alterna entre dorado y azul.
func _crear_portal() -> void:
	_luz_portal = PointLight2D.new()
	_luz_portal.texture = _textura_luz
	_luz_portal.texture_scale = 0.8
	_luz_portal.color = COLOR_PORTAL_DORADO
	_luz_portal.energy = 0.45
	_luz_portal.position = CENTRO_PORTAL
	_lienzo.add_child(_luz_portal)
	var alternar := create_tween().set_loops()
	alternar.tween_property(_luz_portal, "color", COLOR_PORTAL_AZUL, 2.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	alternar.tween_property(_luz_portal, "color", COLOR_PORTAL_DORADO, 2.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	var rampa := Gradient.new()
	rampa.offsets = PackedFloat32Array([0.0, 0.2, 0.7, 1.0])
	rampa.colors = PackedColorArray([Color(1.0, 0.9, 0.55, 0.0), Color(1.0, 0.88, 0.5, 1.0), Color(0.6, 0.78, 1.0, 0.9), Color(0.6, 0.78, 1.0, 0.0)])
	_particulas_portal = CPUParticles2D.new()
	_particulas_portal.name = "ParticulasPortal"
	_particulas_portal.texture = _textura_luz
	_particulas_portal.position = CENTRO_PORTAL
	_particulas_portal.amount = 36
	_particulas_portal.lifetime = 2.6
	_particulas_portal.preprocess = 2.6
	# Nacen en un anillo dentro del aro, giran y se acercan al centro
	_particulas_portal.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE_SURFACE
	_particulas_portal.emission_sphere_radius = RADIO_PORTAL - 8.0
	_particulas_portal.direction = Vector2.ZERO
	_particulas_portal.spread = 0.0
	_particulas_portal.gravity = Vector2.ZERO
	_particulas_portal.initial_velocity_min = 0.0
	_particulas_portal.initial_velocity_max = 0.0
	_particulas_portal.orbit_velocity_min = 0.25
	_particulas_portal.orbit_velocity_max = 0.45
	_particulas_portal.radial_accel_min = -9.0
	_particulas_portal.radial_accel_max = -5.0
	_particulas_portal.scale_amount_min = 0.03
	_particulas_portal.scale_amount_max = 0.06
	_particulas_portal.color_ramp = rampa
	_lienzo.add_child(_particulas_portal)


## Al elegir "Comenzar": el portal se ilumina con fuerza (sube la luz y las partículas).
func _encender_portal() -> void:
	var t := create_tween().set_parallel(true)
	t.tween_property(_luz_portal, "energy", 3.2, 0.6).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	t.tween_property(_luz_portal, "texture_scale", 2.2, 0.6).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	t.tween_property(_particulas_portal, "speed_scale", 3.0, 0.6)
	# Ráfaga de chispas desde el aro
	var chispas := CPUParticles2D.new()
	chispas.texture = _textura_luz
	chispas.position = CENTRO_PORTAL
	chispas.amount = 70
	chispas.lifetime = 1.0
	chispas.one_shot = true
	chispas.explosiveness = 0.85
	chispas.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE_SURFACE
	chispas.emission_sphere_radius = RADIO_PORTAL - 6.0
	chispas.direction = Vector2.UP
	chispas.spread = 180.0
	chispas.gravity = Vector2.ZERO
	chispas.initial_velocity_min = 20.0
	chispas.initial_velocity_max = 90.0
	chispas.scale_amount_min = 0.03
	chispas.scale_amount_max = 0.07
	chispas.color = Color(1.0, 0.92, 0.65)
	var desvanecer := Gradient.new()
	desvanecer.set_color(0, Color(1, 1, 1, 1))
	desvanecer.set_color(1, Color(1, 1, 1, 0))
	chispas.color_ramp = desvanecer
	_lienzo.add_child(chispas)
	chispas.emitting = true


# --- Luciérnagas doradas ---

func _crear_luciernagas() -> void:
	var rampa_alfa := Gradient.new()
	rampa_alfa.offsets = PackedFloat32Array([0.0, 0.25, 0.75, 1.0])
	rampa_alfa.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 1), Color(1, 1, 1, 1), Color(1, 1, 1, 0)])

	var p := CPUParticles2D.new()
	p.name = "Luciernagas"
	p.texture = _textura_luz
	p.amount = 40
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
	p.scale_amount_min = 0.045
	p.scale_amount_max = 0.1
	p.color = Color(1.0, 0.82, 0.4, 0.95)
	p.color_ramp = rampa_alfa
	_lienzo.add_child(p)


# --- Título y subtítulo (van en el cielo, entre y = 20 e y = 110) ---

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
	# Un instante de negro absoluto -> aparece la ilustración
	_tween_intro.tween_interval(0.4)
	_tween_intro.tween_property(negro, "color:a", 0.0, SEGUNDOS_APARICION)
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
	# Caja del menú: morado oscuro semitransparente con borde dorado (se lee sobre la ilustración)
	menu.add_theme_stylebox_override("panel", _crear_caja(Color("1e1b2e", 0.82), DORADO, 2, 8))


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
	t.tween_callback(_encender_portal)  # el portal se ilumina con fuerza...
	t.tween_interval(0.7)
	t.tween_callback(_disolver_titulo)  # ...y entonces se disuelve el título y pasa la ola de luz
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
