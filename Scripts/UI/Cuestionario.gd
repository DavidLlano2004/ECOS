class_name Cuestionario
extends CanvasLayer
## Pantalla de preguntas de la evaluación (capa 12). Una pregunta a la vez, con progreso ("Pregunta 5 de 16") y
## una barra discreta. Es una pantalla de EVALUACIÓN: no se puede cancelar (ESC no hace nada y no abre la
## pausa), ni abrir el diario, ni usar habilidades; no hay "Ahora no", no se puede saltar ni volver atrás. Nunca
## dice si una respuesta es correcta. Antes de cada bloque el Guía dice unas líneas (trivia, situaciones,
## escala). Al terminar llama a Evaluacion.calcular y emite fase_terminada(fase).
##
## Uso:   await Cuestionario.mostrar(get_tree(), "pre")   (o "post")

signal fase_terminada(fase: String)

const ESCENA := "res://Scenes/UI/Cuestionario.tscn"
const SEGUNDOS_FUNDIDO := 0.5

## Lo que dice el Guía antes de cada bloque (cada elemento es una línea).
const INTRO := {
	"trivia": ["Primero, cuánto sabes de lo que sientes.", "Aquí está bien equivocarse: no es un examen, solo queremos saber qué sabes hoy."],
	"situaciones": ["Ahora, cómo reaccionas normalmente.", "En esta parte no hay respuestas buenas ni malas. Elige la que más se parezca a ti."],
	"escala": ["Y por último, cómo te sientes con esto.", "Piensa en una escala del 1 al 5."],
}
const INTRO_POST := "Hemos llegado al final de este viaje. Te haré las mismas preguntas del principio. "

var fase := ""

var _preguntas: Array[Dictionary] = []
var _raiz: Control
var _guia: AnimatedSprite2D
var _panel_intro: Control
var _texto_intro: Label
var _boton_seguir: Button
var _panel_pregunta: Control
var _progreso: Label
var _barra_fondo: ColorRect
var _barra: ColorRect
var _texto_pregunta: Label
var _contenedor_opciones: Control
var _botones: Array[Button] = []
var _respondida := false
var _respuesta := -1

signal _elegida(indice_original: int)
signal _seguir


## Muestra el cuestionario de la fase y espera a que termine (y se cierre).
static func mostrar(arbol: SceneTree, fase_: String) -> void:
	var escena := (load(ESCENA) as PackedScene).instantiate() as Cuestionario
	escena.fase = fase_
	arbol.root.add_child.call_deferred(escena)   # (diferido: la raíz puede estar ocupada montando la escena)
	await escena.tree_exited


func _ready() -> void:
	layer = 12
	process_mode = Node.PROCESS_MODE_ALWAYS
	_guia = FondoEvaluacion.crear(self)
	_raiz = Control.new()
	_raiz.set_anchors_preset(Control.PRESET_FULL_RECT)
	_raiz.theme = EstiloUI.tema()
	_raiz.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_raiz.modulate.a = 0.0
	add_child(_raiz)
	_construir()
	_ejecutar()


# Se tragan ESC (pausa), TAB (diario) y la tecla de habilidad mientras dura la evaluación
func _input(evento: InputEvent) -> void:
	for accion in ["PAUSA", "DIARIO", "HABILIDAD", "ui_cancel"]:
		if evento.is_action_pressed(accion):
			get_viewport().set_input_as_handled()
			return


func _construir() -> void:
	# Panel de la intro de cada bloque: el Guía habla
	_panel_intro = _caja(Rect2(168, 70, 452, 220))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	_panel_intro.get_child(0).add_child(v)
	v.add_child(EstiloUI.etiqueta("Guía", 12, EstiloUI.DORADO))
	_texto_intro = EstiloUI.etiqueta("", 16, EstiloUI.CREMA)
	_texto_intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_texto_intro.custom_minimum_size = Vector2(410, 100)
	v.add_child(_texto_intro)
	_boton_seguir = Button.new()
	_boton_seguir.text = "Seguir"
	_boton_seguir.custom_minimum_size = Vector2(120, 26)
	_boton_seguir.size_flags_horizontal = Control.SIZE_SHRINK_END
	_boton_seguir.pressed.connect(func() -> void:
		Sonido.efecto("ui_elegir")
		_seguir.emit())
	_boton_seguir.focus_entered.connect(func() -> void: Sonido.efecto("ui_mover"))
	v.add_child(_boton_seguir)

	# Panel de la pregunta
	_panel_pregunta = _caja(Rect2(168, 36, 452, 290))
	var q := VBoxContainer.new()
	q.add_theme_constant_override("separation", 8)
	_panel_pregunta.get_child(0).add_child(q)
	_progreso = EstiloUI.etiqueta("", 11, EstiloUI.GRIS)
	q.add_child(_progreso)
	_barra_fondo = ColorRect.new()
	_barra_fondo.color = Color("3a3358")
	_barra_fondo.custom_minimum_size = Vector2(0, 3)
	_barra = ColorRect.new()
	_barra.color = EstiloUI.DORADO
	_barra.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	_barra_fondo.add_child(_barra)
	q.add_child(_barra_fondo)
	_texto_pregunta = EstiloUI.etiqueta("", 15, EstiloUI.CREMA)
	_texto_pregunta.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_texto_pregunta.custom_minimum_size = Vector2(410, 58)
	q.add_child(_texto_pregunta)
	_contenedor_opciones = VBoxContainer.new()
	_contenedor_opciones.add_theme_constant_override("separation", 6)
	q.add_child(_contenedor_opciones)
	_panel_pregunta.hide()
	_panel_intro.hide()


## Una caja morada con borde dorado; el hijo 0 es el margen donde se pone el contenido.
func _caja(rect: Rect2) -> Control:
	var panel := PanelContainer.new()
	panel.position = rect.position
	panel.size = rect.size
	panel.add_theme_stylebox_override("panel", EstiloUI.caja(Color("1e1b2e", 0.96), EstiloUI.DORADO, 2, 14, 5))
	_raiz.add_child(panel)
	var margen := MarginContainer.new()
	panel.add_child(margen)
	return panel


# --- Secuencia ---

func _ejecutar() -> void:
	Evaluacion.cuestionario_activo = true
	Evaluacion.iniciar_fase(fase)
	_preguntas = Evaluacion.orden_para(fase)
	create_tween().tween_property(_raiz, "modulate:a", 1.0, SEGUNDOS_FUNDIDO)
	Sonido.efecto("dialogo_abrir")
	await get_tree().create_timer(SEGUNDOS_FUNDIDO).timeout
	var bloque := ""
	for i in _preguntas.size():
		if str(_preguntas[i]["bloque"]) != bloque:
			bloque = str(_preguntas[i]["bloque"])
			await _intro(bloque)
		await _preguntar(i)
	Evaluacion.calcular(fase)
	Evaluacion.fase_terminada.emit(fase)
	fase_terminada.emit(fase)
	var salida := create_tween()
	salida.tween_property(_raiz, "modulate:a", 0.0, SEGUNDOS_FUNDIDO)
	await salida.finished
	Evaluacion.cuestionario_activo = false
	queue_free()


## El Guía dice unas líneas antes de cada bloque.
func _intro(bloque: String) -> void:
	_panel_pregunta.hide()
	var lineas: Array = INTRO[bloque]
	var texto := "\n\n".join(lineas)
	if fase == "post" and bloque == "trivia":
		texto = INTRO_POST + "\n\n" + texto
	_texto_intro.text = texto
	_texto_intro.visible_characters = 0
	_boton_seguir.disabled = true
	_panel_intro.show()
	_guia.play(&"hablar")
	await Dialogo.escribir_etiqueta(_texto_intro, texto)   # mismo blip que todo el texto del juego
	_guia.play(&"idle")
	_boton_seguir.disabled = false
	_boton_seguir.grab_focus()
	await _seguir
	_panel_intro.hide()


## Una pregunta: se espera a que el jugador elija; la respuesta se anota con su índice original.
func _preguntar(indice: int) -> void:
	var p := _preguntas[indice]
	_progreso.text = "Pregunta %d de %d" % [indice + 1, _preguntas.size()]
	_barra.anchor_right = float(indice) / _preguntas.size()
	_barra.offset_right = 0.0
	_texto_pregunta.text = str(p["texto"])
	for hijo in _contenedor_opciones.get_children():
		hijo.queue_free()
	_botones.clear()
	_respondida = false
	if p["bloque"] == "escala":
		_construir_escala(p)
	else:
		for opcion in p["opciones"]:
			_botones.append(_boton_opcion(str(opcion["texto"]), int(opcion["indice_original"])))
	_panel_pregunta.modulate.a = 0.0
	_panel_pregunta.show()
	create_tween().tween_property(_panel_pregunta, "modulate:a", 1.0, 0.2)
	await get_tree().process_frame
	if not _botones.is_empty():
		_botones[0].grab_focus()
	var elegida: int = await _elegida
	Evaluacion.registrar(fase, str(p["id"]), elegida)
	# Sin decir si estaba bien o mal: solo un breve fundido hacia la siguiente
	var t := create_tween()
	t.tween_property(_panel_pregunta, "modulate:a", 0.0, 0.18)
	await t.finished


func _boton_opcion(texto: String, indice_original: int) -> Button:
	var b := Button.new()
	b.text = texto
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.custom_minimum_size = Vector2(410, 36)
	b.pressed.connect(_al_elegir.bind(indice_original))
	b.focus_entered.connect(func() -> void: Sonido.efecto("ui_mover"))
	_contenedor_opciones.add_child(b)
	return b


## Escala del 1 al 5: cinco botones numerados y los extremos rotulados debajo.
func _construir_escala(p: Dictionary) -> void:
	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", 8)
	fila.alignment = BoxContainer.ALIGNMENT_CENTER
	_contenedor_opciones.add_child(fila)
	for opcion in p["opciones"]:
		var b := Button.new()
		b.text = str(opcion["texto"])
		b.custom_minimum_size = Vector2(62, 44)
		b.pressed.connect(_al_elegir.bind(int(opcion["indice_original"])))
		b.focus_entered.connect(func() -> void: Sonido.efecto("ui_mover"))
		fila.add_child(b)
		_botones.append(b)
	var extremos := HBoxContainer.new()
	_contenedor_opciones.add_child(extremos)
	var izquierda := EstiloUI.etiqueta("1 = %s" % p["minimo"], 10, EstiloUI.GRIS)
	izquierda.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	extremos.add_child(izquierda)
	var derecha := EstiloUI.etiqueta("5 = %s" % p["maximo"], 10, EstiloUI.GRIS)
	derecha.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	derecha.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	extremos.add_child(derecha)


func _al_elegir(indice_original: int) -> void:
	if _respondida:
		return
	_respondida = true
	Sonido.efecto("ui_elegir")
	for b in _botones:
		b.disabled = true
	_elegida.emit(indice_original)
