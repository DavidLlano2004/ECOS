class_name DialogoBalloon
extends CanvasLayer
## Balloon propio de ECOS para Dialogue Manager.
## Caja morada con borde dorado, fuente Pixelify Sans, texto letra por letra,
## nombre de quien habla arriba de la caja y retrato opcional a la izquierda.
##
## Retrato (opcional): en el .dialogue, agrega una etiqueta a la línea:
##   Guía: [#retrato=res://Assets/Personajes/guia.png] Hola.
## También se puede registrar un retrato por personaje en Dialogo.retratos["Nombre"].
## Si no hay ni etiqueta ni retrato registrado, el espacio se oculta.

## Se emite al terminar el diálogo (ya con el fundido de salida hecho).
## indice_respuesta es la posición (0, 1, 2...) de la última respuesta elegida, o -1 si no hubo.
signal terminado(indice_respuesta: int)
## Empieza a escribirse una línea (personaje vacío si es el narrador) y cuando termina de escribirse.
signal escribiendo_iniciado(personaje: String)
signal escribiendo_terminado()

const RUTA_FUENTE := "res://Assets/PixelifySans-VariableFont_wght.ttf"
const TAM_FUENTE := 16
const SEGUNDOS_POR_LETRA := 0.03
const FUNDIDO_ENTRADA := 0.2
const FUNDIDO_SALIDA := 0.15
const ACCION_SIGUIENTE := &"INTERACTUAR"
## ESC: cancela la conversación (una pulsación con opciones visibles; mantenida durante el texto).
const ACCION_CANCELAR := &"PAUSA"
const SEGUNDOS_PARA_SALIR := 0.7
const TEXTO_CANCELAR := "Ahora no"
const COLOR_CANCELAR := Color("8a7fa3")        # gris violáceo apagado
const COLOR_CANCELAR_FOCO := Color("c9bfe0")

## Recurso .dialogue y cue inicial (los rellena DialogueManager o Dialogo.mostrar).
@export var dialogue_resource: DialogueResource
@export var start_from_cue: String = ""

@onready var raiz: Control = %Raiz
@onready var caja_nombre: PanelContainer = %CajaNombre
@onready var etiqueta_nombre: Label = %Nombre
@onready var caja: PanelContainer = %Caja
@onready var retrato: TextureRect = %Retrato
@onready var texto: DialogueLabel = %Texto
@onready var respuestas: DialogueResponsesMenu = %Respuestas
@onready var indicador: Control = %Indicador

## Estados extra que ve el diálogo (el balloon mismo, por si se usa "locals").
var estados_temporales: Array = []
## true cuando el texto ya terminó y se espera que el jugador avance.
var esperando_entrada := false
## false en los cuestionarios (onboarding y final): no hay "Ahora no" y ESC no hace nada.
var cancelable := true
## Evita elegir dos veces la misma respuesta (clic + tecla).
var _respuesta_tomada := false
var _ultima_respuesta := -1
var _cerrando := false
var _temporizador_mutacion := Timer.new()
var _ocultar_por_mutacion := false
var _boton_cancelar: Button
var _separador: ColorRect
var _pista: Label
var _tiempo_salida := 0.0

## Línea actual. Al asignar una línea nula, el diálogo terminó.
var linea: DialogueLine:
	set(valor):
		if _cerrando:
			return  # ya se canceló o terminó: se ignoran las líneas que lleguen tarde
		if valor:
			linea = valor
			_aplicar_linea()
		else:
			_terminar()
	get:
		return linea


func _ready() -> void:
	_aplicar_estilo()
	_crear_cancelacion()
	raiz.hide()
	raiz.modulate.a = 0.0
	retrato.hide()
	indicador.hide()
	respuestas.hide()
	respuestas.next_action = ACCION_SIGUIENTE
	respuestas.auto_focus_first_item = false
	respuestas.response_selected.connect(_on_respuesta_elegida)
	texto.seconds_per_step = SEGUNDOS_POR_LETRA

	_temporizador_mutacion.one_shot = true
	_temporizador_mutacion.timeout.connect(_on_temporizador_mutacion)
	add_child(_temporizador_mutacion)
	Engine.get_singleton("DialogueManager").mutated.connect(_on_mutacion)

	_animar_indicador()


## Empieza el diálogo. Misma firma que usa DialogueManager.show_dialogue_balloon().
func start(recurso: DialogueResource = null, cue: String = "", estados_extra: Array = []) -> void:
	estados_temporales = [self] + estados_extra
	esperando_entrada = false
	if is_instance_valid(recurso):
		dialogue_resource = recurso
	if not cue.is_empty():
		start_from_cue = cue
	linea = await dialogue_resource.get_next_dialogue_line(start_from_cue, estados_temporales)


func _input(evento: InputEvent) -> void:
	if not raiz.visible or linea == null or _cerrando:
		return
	# Con las opciones a la vista, una pulsación de ESC cancela. También con INTERACTUAR sobre "Ahora no".
	if cancelable and respuestas.visible:
		if evento.is_action_pressed(ACCION_CANCELAR) and not evento.is_echo():
			get_viewport().set_input_as_handled()
			_cancelar()
			return
		if evento.is_action_pressed(ACCION_SIGUIENTE) and _boton_cancelar.has_focus():
			get_viewport().set_input_as_handled()
			_cancelar()
			return
	var presionado := evento.is_action_pressed(ACCION_SIGUIENTE)
	var clic: bool = evento is InputEventMouseButton and evento.pressed \
		and evento.button_index == MOUSE_BUTTON_LEFT
	if not (presionado or clic):
		return

	# Con INTERACTUAR (o clic) se completa el texto al instante
	if texto.is_typing:
		get_viewport().set_input_as_handled()
		texto.skip_typing()
	# Si no hay respuestas, la misma tecla pasa a la siguiente línea
	elif esperando_entrada and linea.responses.is_empty():
		get_viewport().set_input_as_handled()
		_siguiente(linea.next_id)


func _process(delta: float) -> void:
	# Durante el texto, mantener ESC sale de la conversación
	if cancelable and raiz.visible and not _cerrando and linea != null and not respuestas.visible:
		if Input.is_action_pressed(ACCION_CANCELAR):
			_tiempo_salida += delta
			_pista.text = "Saliendo…"
			_pista.modulate.a = 1.0
			if _tiempo_salida >= SEGUNDOS_PARA_SALIR:
				_cancelar()
			return
	_tiempo_salida = 0.0
	if _pista != null:
		_pista.text = "Mantén ESC para salir"
		_pista.modulate.a = 0.45


## Cierra la conversación sin elegir nada. NO es una decisión del juego: no se ejecuta ninguna
## línea más del .dialogue, así que ningún estado cambia. mostrar() devuelve Dialogo.CANCELADO.
func _cancelar() -> void:
	if not cancelable or _cerrando:
		return
	_ultima_respuesta = Dialogo.CANCELADO
	_terminar()


func _siguiente(id: String) -> void:
	linea = await dialogue_resource.get_next_dialogue_line(id, estados_temporales)


## Muestra la línea actual: nombre, retrato, texto escrito letra por letra y respuestas.
func _aplicar_linea() -> void:
	var esta_linea := linea
	_temporizador_mutacion.stop()
	_ocultar_por_mutacion = false
	_respuesta_tomada = false
	esperando_entrada = false
	indicador.hide()
	_tiempo_salida = 0.0
	_boton_cancelar.hide()
	_separador.hide()
	_pista.visible = cancelable

	# Nombre de quien habla (se oculta si es narrador)
	var nombre := tr(linea.character, "dialogue")
	caja_nombre.visible = not linea.character.is_empty()
	etiqueta_nombre.text = nombre

	_actualizar_retrato()

	texto.hide()
	texto.dialogue_line = linea
	respuestas.hide()
	respuestas.responses = linea.responses
	_conectar_botones()

	_mostrar_balloon()
	texto.show()
	if not linea.text.is_empty():
		escribiendo_iniciado.emit(linea.character)
		texto.type_out()
		await texto.finished_typing
		escribiendo_terminado.emit()
		if _cerrando or esta_linea != linea:
			return  # ya cambió la línea (o se canceló) mientras se escribía

	if linea.responses.size() > 0:
		respuestas.show()
		_pista.hide()
		_boton_cancelar.visible = cancelable
		_separador.visible = cancelable
		respuestas.focus_first_item()
	elif linea.time != "":
		var segundos := linea.text.length() * 0.02 if linea.time == "auto" else linea.time.to_float()
		await get_tree().create_timer(segundos).timeout
		if esta_linea == linea:
			_siguiente(linea.next_id)
	else:
		esperando_entrada = true
		indicador.show()


func _actualizar_retrato() -> void:
	var ruta := linea.get_tag_value("retrato")
	var textura: Texture2D = null
	if ruta != "" and ResourceLoader.exists(ruta):
		textura = load(ruta)
	elif Dialogo.retratos.has(linea.character):
		textura = Dialogo.retratos[linea.character]  # registrado por la escena (ver Dialogo.retratos)
	retrato.texture = textura
	retrato.visible = textura != null


## Hace visible la caja, con fundido si estaba escondida.
func _mostrar_balloon() -> void:
	if raiz.visible and raiz.modulate.a >= 1.0:
		return
	raiz.show()
	var t := create_tween()
	t.tween_property(raiz, "modulate:a", 1.0, FUNDIDO_ENTRADA)


func _terminar() -> void:
	if _cerrando:
		return
	_cerrando = true
	esperando_entrada = false
	indicador.hide()
	var t := create_tween()
	t.tween_property(raiz, "modulate:a", 0.0, FUNDIDO_SALIDA)
	await t.finished
	terminado.emit(_ultima_respuesta)
	queue_free()


# --- Respuestas ---

## Los botones también responden a Enter/clic (el menú solo escucha INTERACTUAR y el ratón).
func _conectar_botones() -> void:
	var items := respuestas.get_menu_items()
	for item in items:
		if item is BaseButton:
			item.pressed.connect(_on_respuesta_elegida.bind(item.get_meta("response")))
	# Con el teclado se llega a "Ahora no" bajando desde la última respuesta (y se vuelve subiendo)
	if not items.is_empty():
		var ultimo := items[items.size() - 1] as Control
		ultimo.focus_neighbor_bottom = ultimo.get_path_to(_boton_cancelar)
		_boton_cancelar.focus_neighbor_top = _boton_cancelar.get_path_to(ultimo)


## "Ahora no": una opción pequeña, gris violácea y separada por una línea tenue de las respuestas,
## para que no se confunda con una decisión. Se crea por código (así no hay que editar la escena).
func _crear_cancelacion() -> void:
	var contenedor := respuestas.get_parent()
	_separador = ColorRect.new()
	_separador.custom_minimum_size = Vector2(0, 1)
	_separador.color = Color(COLOR_CANCELAR, 0.35)
	_separador.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_separador.hide()
	contenedor.add_child(_separador)

	_boton_cancelar = Button.new()
	_boton_cancelar.text = TEXTO_CANCELAR
	_boton_cancelar.flat = true
	_boton_cancelar.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_boton_cancelar.focus_mode = Control.FOCUS_ALL
	_boton_cancelar.add_theme_font_size_override("font_size", 12)
	_boton_cancelar.add_theme_color_override("font_color", COLOR_CANCELAR)
	_boton_cancelar.add_theme_color_override("font_hover_color", COLOR_CANCELAR_FOCO)
	_boton_cancelar.add_theme_color_override("font_focus_color", COLOR_CANCELAR_FOCO)
	_boton_cancelar.hide()
	_boton_cancelar.pressed.connect(_cancelar)
	contenedor.add_child(_boton_cancelar)

	_pista = Label.new()
	_pista.text = "Mantén ESC para salir"
	_pista.size_flags_horizontal = Control.SIZE_SHRINK_END
	_pista.add_theme_font_size_override("font_size", 10)
	_pista.add_theme_color_override("font_color", COLOR_CANCELAR)
	_pista.modulate.a = 0.45
	_pista.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pista.hide()
	contenedor.add_child(_pista)


func _on_respuesta_elegida(respuesta: DialogueResponse) -> void:
	if _respuesta_tomada or linea == null:
		return
	_respuesta_tomada = true
	_ultima_respuesta = linea.responses.find(respuesta)
	_siguiente(respuesta.next_id)


# --- Mutaciones (líneas "$>" del .dialogue) ---

func _on_mutacion(mutacion: Dictionary) -> void:
	if not mutacion.is_inline:
		esperando_entrada = false
		_ocultar_por_mutacion = true
		_temporizador_mutacion.start(0.1)


func _on_temporizador_mutacion() -> void:
	if _ocultar_por_mutacion:
		_ocultar_por_mutacion = false
		raiz.hide()
		raiz.modulate.a = 0.0


# --- Estilo (mismo que el Dialogo anterior, adaptado a 640x360) ---

func _crear_caja(fondo: Color, borde: Color, grosor: int, margen: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = fondo
	s.border_color = borde
	s.set_border_width_all(grosor)
	s.set_corner_radius_all(4)
	s.set_content_margin_all(margen)
	return s


func _aplicar_estilo() -> void:
	caja.add_theme_stylebox_override("panel", _crear_caja(Color("1e1b2e", 0.95), Color("f4c77b"), 2, 8))
	caja_nombre.add_theme_stylebox_override("panel", _crear_caja(Color("2d2845"), Color("f4c77b"), 2, 4))
	etiqueta_nombre.add_theme_color_override("font_color", Color("f4c77b"))

	var tema := Theme.new()
	if ResourceLoader.exists(RUTA_FUENTE):
		var fuente: Font = load(RUTA_FUENTE)
		tema.set_font("font", "Label", fuente)
		tema.set_font("font", "Button", fuente)
		tema.set_font("normal_font", "RichTextLabel", fuente)
		tema.set_font("bold_font", "RichTextLabel", fuente)
		tema.set_font("italics_font", "RichTextLabel", fuente)
	for tipo in ["Label", "Button"]:
		tema.set_font_size("font_size", tipo, TAM_FUENTE)
	tema.set_font_size("normal_font_size", "RichTextLabel", TAM_FUENTE)
	tema.set_font_size("bold_font_size", "RichTextLabel", TAM_FUENTE)
	tema.set_font_size("italics_font_size", "RichTextLabel", TAM_FUENTE)
	tema.set_color("default_color", "RichTextLabel", Color("fff4dc"))
	tema.set_color("font_color", "Label", Color("fff4dc"))
	tema.set_color("font_color", "Button", Color("d9cfe8"))
	tema.set_color("font_hover_color", "Button", Color("f4c77b"))
	tema.set_color("font_focus_color", "Button", Color("f4c77b"))

	tema.set_stylebox("normal", "Button", _crear_caja(Color("2d2845"), Color("2d2845"), 1, 3))
	tema.set_stylebox("hover", "Button", _crear_caja(Color("3a3358"), Color("f4c77b"), 1, 3))
	tema.set_stylebox("pressed", "Button", _crear_caja(Color("4a4170"), Color("f4c77b"), 1, 3))
	tema.set_stylebox("focus", "Button", _crear_caja(Color("3a3358"), Color("f4c77b"), 1, 3))
	tema.set_stylebox("disabled", "Button", _crear_caja(Color("24203a"), Color("24203a"), 1, 3))
	raiz.theme = tema


## Triangulito dorado que parpadea cuando se puede avanzar.
func _animar_indicador() -> void:
	var t := create_tween().set_loops()
	t.tween_property(indicador, "modulate:a", 0.2, 0.5)
	t.tween_property(indicador, "modulate:a", 1.0, 0.5)
