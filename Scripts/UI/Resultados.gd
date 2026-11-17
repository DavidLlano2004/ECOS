class_name Resultados
extends CanvasLayer
## Pantalla de resultados, al terminar la fase "post" (capa 12). Muestra "Tu viaje en números":
##   - tres bloques con barras animadas ANTES (gris violáceo) y DESPUÉS (dorado): Conocimiento (trivia, 0 a 7),
##     Cómo reaccionas (situaciones, 0 a 7) y Cómo te sientes con tus emociones (escala, 2 a 10), con un texto
##     cálido según el cambio (nunca un reproche);
##   - una sección por emoción: su estado final, si acertó la trivia antes y después, la opción elegida en la
##     situación y la explicación de la trivia (aquí se revelan las respuestas correctas);
##   - un resumen de la partida (tiempo, emociones, fragmentos, habilidades y final);
##   - botones: Exportar mis resultados, Ver créditos, Jugar de nuevo y Salir.
## Navegable con teclado (flechas, TAB, ENTER; arriba y abajo desplazan) y con ratón.
##
## Uso:   await Resultados.mostrar(get_tree())   (cuando vuelve, Resultados.ultimo_destino dice a dónde se fue:
##        "" = a ninguna parte todavía, "nueva" = nueva partida, "salir", "prueba").

const ESCENA := "res://Scenes/UI/Resultados.tscn"
const ESCENA_ONBOARDING := "res://Scenes/Intro/Onboarding.tscn"
const GRIS_VIOLACEO := Color("8a7fa3")
const DORADO := Color("f4c77b")
const COLOR_ESTADO := {"integrada": Color("8fd19e"), "atacada": Color("e0a070"), "ignorada": Color("9aa3c4"), "pendiente": Color("8a7fa3")}
const NOMBRE_ESTADO := {"integrada": "Integrada", "atacada": "Atacada", "ignorada": "Ignorada", "pendiente": "Pendiente"}
const NOMBRE_FINAL := {"bueno": "Final bueno", "neutro": "Final neutro", "dificil": "Final difícil"}
## Qué bloques hay: clave, título, mínimo y máximo del puntaje.
const BLOQUES := [
	["trivia", "Conocimiento", 0, 7],
	["situaciones", "Cómo reaccionas", 0, 7],
	["escala", "Cómo te sientes con tus emociones", 2, 10],
]

signal cerrada

## A dónde se fue la última vez que se cerró ("" si no se fue a ningún sitio).
static var ultimo_destino := ""

var _raiz: Control
var _scroll: ScrollContainer
var _estado: Label
var _boton_exportar: Button
var _boton_carpeta: Button
var _codigo := ""
var _campo_codigo: LineEdit
var _boton_opinion: Button
var _boton_creditos: Button
var _botones: Array[Button] = []
var _barras: Array[BarraRes] = []
var _cerrando := false


## Una barra horizontal que se llena con una animación suave (fraccion de 0 a 1).
class BarraRes extends Control:
	var fraccion := 0.0:
		set(valor):
			fraccion = valor
			queue_redraw()
	var color := Color.WHITE

	func _init(color_barra: Color) -> void:
		color = color_barra
		custom_minimum_size = Vector2(250, 10)
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		draw_rect(Rect2(Vector2(0, 1), Vector2(size.x, 8)), Color("2d2845"))
		draw_rect(Rect2(Vector2(0, 1), Vector2(size.x * clampf(fraccion, 0.0, 1.0), 8)), color)
		draw_rect(Rect2(Vector2(0, 1), Vector2(size.x, 8)), Color(color, 0.35), false, 1.0)


static func mostrar(arbol: SceneTree) -> void:
	ultimo_destino = ""
	var escena := (load(ESCENA) as PackedScene).instantiate() as Resultados
	arbol.root.add_child.call_deferred(escena)   # (diferido: la raíz puede estar ocupada montando la escena)
	await escena.tree_exited


func _ready() -> void:
	layer = 12
	process_mode = Node.PROCESS_MODE_ALWAYS
	Evaluacion.cuestionario_activo = true
	FondoEvaluacion.crear(self)
	_raiz = Control.new()
	_raiz.set_anchors_preset(Control.PRESET_FULL_RECT)
	_raiz.theme = EstiloUI.tema()
	_raiz.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_raiz.modulate.a = 0.0
	add_child(_raiz)
	_construir()
	create_tween().tween_property(_raiz, "modulate:a", 1.0, 0.5)
	_animar_barras.call_deferred()
	Sonido.efecto("dialogo_abrir")
	_boton_exportar.grab_focus.call_deferred()


# ESC, TAB y la habilidad no hacen nada; arriba y abajo desplazan los resultados
func _input(evento: InputEvent) -> void:
	for accion in ["PAUSA", "DIARIO", "HABILIDAD", "ui_cancel"]:
		if evento.is_action_pressed(accion):
			get_viewport().set_input_as_handled()
			return
	if evento is InputEventKey and evento.pressed and _scroll != null:
		var paso := 0
		match evento.keycode:
			KEY_UP: paso = -44
			KEY_DOWN: paso = 44
			KEY_PAGEUP: paso = -200
			KEY_PAGEDOWN: paso = 200
		if paso != 0:
			_scroll.scroll_vertical += paso
			get_viewport().set_input_as_handled()


# --- Construcción ---

func _construir() -> void:
	var c := Evaluacion.comparar()
	var panel := PanelContainer.new()
	panel.position = Vector2(16, 10)
	panel.size = Vector2(608, 340)
	panel.add_theme_stylebox_override("panel", EstiloUI.caja(Color("1e1b2e", 0.97), EstiloUI.DORADO, 2, 12, 5))
	_raiz.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 5)
	panel.add_child(v)
	var titulo := EstiloUI.etiqueta("Tu viaje en números", 18, EstiloUI.DORADO)
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(titulo)

	_scroll = ScrollContainer.new()
	_scroll.custom_minimum_size = Vector2(580, 232)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.focus_mode = Control.FOCUS_NONE
	_scroll.follow_focus = true   # al navegar con el teclado, el desplazamiento sigue al botón enfocado
	v.add_child(_scroll)
	var contenido := VBoxContainer.new()
	contenido.add_theme_constant_override("separation", 10)
	contenido.custom_minimum_size = Vector2(560, 0)
	_scroll.add_child(contenido)

	if not c["hay_pre"]:
		contenido.add_child(_texto("No tengo tus respuestas del principio (jugaste sin guardarlas), pero estas son las de ahora.", 10, GRIS_VIOLACEO))
	for b in BLOQUES:
		contenido.add_child(_bloque(b, c))
	contenido.add_child(EstiloUI.etiqueta("Tus emociones", 14, EstiloUI.DORADO))
	for id in GameState.ids_emociones():
		contenido.add_child(_fila_emocion(id))
	contenido.add_child(EstiloUI.etiqueta("Tu partida", 14, EstiloUI.DORADO))
	contenido.add_child(_resumen(c))
	contenido.add_child(EstiloUI.etiqueta("Tu código de resultados", 14, EstiloUI.DORADO))
	contenido.add_child(_seccion_codigo())

	_estado = _texto("", 10, EstiloUI.CREMA)
	_estado.custom_minimum_size = Vector2(580, 0)
	v.add_child(_estado)
	var recordatorio := _texto("Esto no es un test psicológico ni da diagnósticos: solo te muestra cómo te fue en este juego.", 9, GRIS_VIOLACEO)
	recordatorio.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(recordatorio)

	var fila := HFlowContainer.new()
	fila.add_theme_constant_override("h_separation", 8)
	fila.alignment = FlowContainer.ALIGNMENT_CENTER
	v.add_child(fila)
	_boton_exportar = _boton(fila, "Exportar mis resultados" if Evaluacion.consentimiento_guardar else "Los datos no se guardaron porque elegiste jugar sin guardar", _exportar)
	_boton_opinion = _boton(fila, "Opinión enviada" if Evaluacion.valoracion_enviada() else "Dar mi opinión sobre el juego", _dar_opinion)
	_boton_carpeta = _boton(fila, "Abrir carpeta de datos", _abrir_carpeta)
	if OS.has_feature("web"):
		_boton_carpeta.hide()   # en la web no hay carpeta que abrir: los datos se descargan
		_botones.erase(_boton_carpeta)
	_boton_creditos = _boton(fila, "Ver créditos", _ver_creditos)
	_boton(fila, "Jugar de nuevo", _jugar_de_nuevo)
	if not OS.has_feature("web"):   # en la web no se puede cerrar la pestaña desde el juego
		_boton(fila, "Salir", _salir)


func _texto(texto: String, tamano: int, color: Color) -> Label:
	var e := EstiloUI.etiqueta(texto, tamano, color)
	e.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	e.custom_minimum_size = Vector2(540, 0)
	return e


func _boton(padre: Control, texto: String, accion: Callable) -> Button:
	var b := Button.new()
	b.text = texto
	b.add_theme_font_size_override("font_size", 11)
	b.custom_minimum_size = Vector2(0, 26)
	b.pressed.connect(func() -> void:
		Sonido.efecto("ui_elegir")
		accion.call())
	b.focus_entered.connect(func() -> void: Sonido.efecto("ui_mover"))
	padre.add_child(b)
	_botones.append(b)
	return b


## Un bloque: título, barra de antes, barra de después y el texto del cambio.
func _bloque(b: Array, c: Dictionary) -> Control:
	var clave: String = b[0]
	var minimo: int = b[2]
	var maximo: int = b[3]
	var datos: Dictionary = c["por_bloque"][clave]
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 3)
	v.add_child(EstiloUI.etiqueta(b[1], 13, EstiloUI.CREMA))
	if c["hay_pre"]:
		v.add_child(_fila_barra("Antes", int(datos["pre"]), minimo, maximo, GRIS_VIOLACEO))
	v.add_child(_fila_barra("Después", int(datos["post"]), minimo, maximo, DORADO))
	v.add_child(_texto(_mensaje(clave, int(datos["dif"]), c["hay_pre"]), 11, Color("d9cfe8")))
	return v


func _fila_barra(nombre: String, valor: int, minimo: int, maximo: int, color: Color) -> Control:
	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", 8)
	var e := EstiloUI.etiqueta(nombre, 11, color)
	e.custom_minimum_size = Vector2(58, 0)
	fila.add_child(e)
	var barra := BarraRes.new(color)
	barra.set_meta("destino", clampf(float(valor - minimo) / float(maximo - minimo), 0.0, 1.0))
	fila.add_child(barra)
	_barras.append(barra)
	var cifra := EstiloUI.etiqueta("%d de %d" % [valor, maximo] if minimo == 0 else "%d (de %d a %d)" % [valor, minimo, maximo], 11, EstiloUI.CREMA)
	cifra.custom_minimum_size = Vector2(88, 0)
	fila.add_child(cifra)
	return fila


## El texto del cambio: cálido y nunca un reproche (si baja, un mensaje neutro y amable).
func _mensaje(clave: String, dif: int, hay_pre: bool) -> String:
	if not hay_pre:
		return "Estas son tus respuestas de ahora."
	if dif > 0:
		return "Subiste %d punto%s respecto al principio. ¡Se nota lo que escuchaste!" % [dif, "" if dif == 1 else "s"]
	if dif == 0:
		return "Te mantuviste igual que al principio: eso también es una base firme."
	match clave:
		"trivia":
			return "A veces el juego hace pensar y cuestionar lo que creíamos saber, y eso también es aprender."
		"situaciones":
			return "A veces, al conocer mejor cada emoción, dudamos de lo que solíamos hacer. Esa duda también es aprender."
		_:
			return "Mirar de cerca lo que sentimos puede mostrarnos cuánto hay por descubrir. Eso también es aprender."


## Una emoción: ícono, estado final, trivia (antes y después), la situación y la explicación.
func _fila_emocion(id: String) -> Control:
	var datos := GameState.obtener_datos(id)
	var estado: String = GameState.estado.get(id, "pendiente")
	var hay_pre: bool = Evaluacion.pre_completo() and not Evaluacion.pre["respuestas"].is_empty()
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", EstiloUI.caja(Color("17141f"), Color(datos.color, 0.5), 1, 7, 3))
	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", 10)
	panel.add_child(fila)
	var icono := TextureRect.new()
	if datos.frames != null:
		icono.texture = datos.frames.get_frame_texture(&"idle", 0)
	icono.custom_minimum_size = Vector2(44, 44)
	icono.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icono.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icono.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icono.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	fila.add_child(icono)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 2)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fila.add_child(col)

	var cabecera := HBoxContainer.new()
	cabecera.add_theme_constant_override("separation", 8)
	cabecera.add_child(EstiloUI.etiqueta(datos.nombre, 13, datos.color.lightened(0.3)))
	cabecera.add_child(EstiloUI.etiqueta(NOMBRE_ESTADO[estado], 11, COLOR_ESTADO[estado]))
	col.add_child(cabecera)

	# Trivia: marcas de antes y después
	var trivia := HBoxContainer.new()
	trivia.add_theme_constant_override("separation", 6)
	trivia.add_child(EstiloUI.etiqueta("Trivia:", 10, GRIS_VIOLACEO))
	if hay_pre:
		trivia.add_child(EstiloUI.etiqueta("antes", 10, GRIS_VIOLACEO))
		trivia.add_child(_marca(Evaluacion.puntaje_de("pre", "t_" + id)))
	trivia.add_child(EstiloUI.etiqueta("después", 10, DORADO))
	trivia.add_child(_marca(Evaluacion.puntaje_de("post", "t_" + id)))
	col.add_child(trivia)

	# Situación: la opción elegida antes y después
	if hay_pre:
		col.add_child(_linea_situacion("Antes", "pre", id, GRIS_VIOLACEO))
	col.add_child(_linea_situacion("Después", "post", id, DORADO))

	# La respuesta correcta de la trivia y su explicación
	var pregunta := Evaluacion.pregunta("t_" + id)
	if not pregunta.is_empty():
		col.add_child(_texto("Respuesta correcta: %s" % pregunta["opciones"][int(pregunta["correcta"])], 10, EstiloUI.CREMA))
		col.add_child(_texto(str(pregunta.get("explicacion", "")), 10, Color("d9cfe8")))
	return panel


func _linea_situacion(rotulo: String, fase: String, id: String, color: Color) -> Control:
	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", 6)
	var respuestas: Dictionary = Evaluacion._fase(fase)["respuestas"]
	var pregunta := Evaluacion.pregunta("s_" + id)
	var texto := "(sin respuesta)"
	if respuestas.has("s_" + id) and not pregunta.is_empty():
		texto = str(pregunta["opciones"][int(respuestas["s_" + id])])
	var punto := Evaluacion.puntaje_de(fase, "s_" + id)
	var etiqueta_rotulo := EstiloUI.etiqueta("%s:" % rotulo, 10, color)
	etiqueta_rotulo.custom_minimum_size = Vector2(46, 0)
	fila.add_child(etiqueta_rotulo)
	fila.add_child(_marca(punto, true))
	var e := _texto(texto, 10, EstiloUI.CREMA)
	e.custom_minimum_size = Vector2(380, 0)
	fila.add_child(e)
	return fila


## Una marca simple: visto verde si acertó (o fue la opción más sana), cruz suave si no, guion si no hay dato.
## `suave`: en las situaciones no se marca "mal": solo un puntito neutro (no hay respuestas buenas ni malas).
func _marca(valor: int, suave: bool = false) -> Control:
	var m := Control.new()
	m.custom_minimum_size = Vector2(16, 14)
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	m.draw.connect(func() -> void:
		if valor < 0:
			m.draw_line(Vector2(3, 8), Vector2(12, 8), GRIS_VIOLACEO, 2.0)
		elif valor == 1:
			m.draw_polyline(PackedVector2Array([Vector2(2, 8), Vector2(6, 12), Vector2(14, 3)]), Color("8fd19e"), 2.5, true)
		elif suave:
			m.draw_circle(Vector2(8, 8), 3.0, GRIS_VIOLACEO)
		else:
			m.draw_line(Vector2(3, 3), Vector2(13, 13), Color("e0a070"), 2.5, true)
			m.draw_line(Vector2(13, 3), Vector2(3, 13), Color("e0a070"), 2.5, true))
	return m


func _resumen(c: Dictionary) -> Control:
	var total := GameState.ids_emociones().size()
	var minutos := float(c["duracion_segundos"]) / 60.0
	var lineas: Array[String] = []
	lineas.append("Tiempo jugado: %s" % ("%d minutos" % int(round(minutos)) if minutos >= 1.0 else ("menos de un minuto" if minutos > 0.0 else "no disponible")))
	lineas.append("Emociones integradas: %d de %d" % [GameState.cantidad_integradas(), total])
	lineas.append("Fragmentos de memoria: %d de %d" % [GameState.cantidad_fragmentos(), total])
	lineas.append("Habilidades: %d de %d" % [GameState.habilidades.size(), total])
	lineas.append("Tu final: %s" % NOMBRE_FINAL.get(GameState.calcular_final(), GameState.calcular_final()))
	return _texto("\n".join(lineas), 12, EstiloUI.CREMA)


## "Tu código de resultados": una línea en un cuadro de solo lectura, con "Copiar código" y "Abrir formulario".
## El código se muestra SIEMPRE (también si el jugador eligió jugar sin guardar): no se escribe en ningún archivo y
## el jugador decide si lo comparte.
func _seccion_codigo() -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	_codigo = CodigoResultados.generar()
	_campo_codigo = LineEdit.new()
	_campo_codigo.text = _codigo
	_campo_codigo.editable = false
	_campo_codigo.selecting_enabled = true
	_campo_codigo.custom_minimum_size = Vector2(540, 28)
	_campo_codigo.add_theme_font_size_override("font_size", 10)
	v.add_child(_campo_codigo)
	v.add_child(_texto("Copia este código y pégalo en la última pregunta del formulario. Solo se comparte si tú lo pegas. No contiene tu nombre ni datos personales.", 10, Color("d9cfe8")))
	var fila := HFlowContainer.new()
	fila.add_theme_constant_override("h_separation", 8)
	_boton(fila, "Copiar código", _copiar_codigo)
	var url := CodigoResultados.url_formulario()
	if url != "":
		_boton(fila, "Abrir formulario", func() -> void: OS.shell_open(url))
	else:
		push_warning("Resultados: Resources/config_formulario.json no tiene 'url': no se muestra el botón 'Abrir formulario'.")
	v.add_child(fila)
	return v


func _copiar_codigo() -> void:
	DisplayServer.clipboard_set(_codigo)
	_decir("Código copiado. Pégalo en la última pregunta del formulario.")


# --- Animación ---

func _animar_barras() -> void:
	var retraso := 0.4
	for barra in _barras:
		var t := barra.create_tween()
		t.tween_property(barra, "fraccion", float(barra.get_meta("destino")), 0.9).set_delay(retraso).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		retraso += 0.18


# --- Botones ---

func _decir(texto: String) -> void:
	_estado.text = texto


func _exportar() -> void:
	if not Evaluacion.consentimiento_guardar:
		_decir("Los datos no se guardaron porque elegiste jugar sin guardar.")
		return
	var r := Exportacion.exportar_a_documentos()
	if r["ok"]:
		_decir(("Listo. Tus resultados quedaron en: %s" if not OS.has_feature("web") else "Listo. Se descargó en: %s") % r["ruta"])
	else:
		_decir("No pude copiarlos a Documentos. Están en esta carpeta (usa \"Abrir carpeta de datos\"): %s" % r["ruta_usuario"] if not OS.has_feature("web") else "No pude descargar el archivo. Prueba de nuevo.")


## Abre la carpeta de datos del juego y muestra su ruta en pantalla.
func _abrir_carpeta() -> void:
	var ruta := ProjectSettings.globalize_path("user://")
	_decir("Carpeta de datos: %s" % ruta)
	OS.shell_open(ruta)


## Abre la valoración (opcional). Si ya se envió, el botón no hace nada.
func _dar_opinion() -> void:
	if Evaluacion.valoracion_enviada():
		_decir("Ya recibimos tu opinión. ¡Gracias!")
		return
	var enviada := await Valoracion.mostrar(get_tree())
	if is_instance_valid(_boton_opinion):
		_boton_opinion.text = "Opinión enviada" if enviada else "Dar mi opinión sobre el juego"
		_boton_opinion.grab_focus()


func _ver_creditos() -> void:
	await Creditos.mostrar(get_tree())
	if is_instance_valid(_boton_creditos):
		_boton_creditos.grab_focus()


func _jugar_de_nuevo() -> void:
	if _cerrando:
		return
	_cerrando = true
	ultimo_destino = "nueva"
	GameState.nueva_partida()
	var t := create_tween()
	t.tween_property(_raiz, "modulate:a", 0.0, 0.4)
	await t.finished
	Evaluacion.cuestionario_activo = false
	get_tree().change_scene_to_file(ESCENA_ONBOARDING)
	queue_free()


func _salir() -> void:
	ultimo_destino = "salir"
	Sonido.salir()


## SOLO PARA PRUEBAS: cierra la pantalla sin ir a ninguna parte.
func cerrar_para_pruebas() -> void:
	ultimo_destino = "prueba"
	Evaluacion.cuestionario_activo = false
	cerrada.emit()
	queue_free()
