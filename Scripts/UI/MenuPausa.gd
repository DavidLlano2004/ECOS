class_name MenuPausa
extends CanvasLayer
## Menú de pausa (capa 9). Con el juego en pausa muestra la imagen del juego desenfocada y oscurecida,
## y un panel con: Continuar, Diario, Controles, Opciones, Guardar partida y Volver al título (con
## confirmación). Se maneja con teclado (flechas o W y S, ENTER) y con ratón; el foco es dorado.
##
## No pausa el árbol ni decide cuándo se abre: lo hace el autoload Menus, que sigue las reglas de ESC
## (la cancelación de conversaciones va primero; nunca en el onboarding, los cuestionarios ni una
## transición de época). El menú trabaja con el juego en pausa (process_mode = siempre).

signal reanudar_pedido
signal diario_pedido
signal volver_al_titulo_pedido

enum Pagina { PRINCIPAL, CONTROLES, OPCIONES, CONFIRMAR }

const RUTA_SHADER := "res://Shaders/pausa_menu.gdshader"
const SEGUNDOS_ENTRADA := 0.15

## Teclas del juego para la pantalla de Controles: [tecla, qué hace].
const CONTROLES := [
	["W A S D o flechas", "Moverse"],
	["E", "Hablar, recoger y usar portales y grietas para viajar entre el Pasado y el Presente"],
	["ESPACIO", "Usar la habilidad elegida (Reparar: mantenlo pulsado; Visión: enciende y apaga)"],
	["1 a 7 y rueda del ratón", "Elegir habilidad (también R y F)"],
	["G", "Brújula: una flecha hacia donde te sugiere la Guía (tras pedirle una pista)"],
	["F8", "Reportar un problema (si juegas desde el editor de Godot, la tecla Y)"],
	["TAB", "Diario"],
	["ESC", "Pausa"],
]

var abierta := false
var pagina: Pagina = Pagina.PRINCIPAL

var _raiz: Control
var _fondo: ColorRect
var _material: ShaderMaterial
var _panel: PanelContainer
var _paginas: Dictionary = {}   # Pagina -> VBoxContainer
var _primer_foco: Dictionary = {}   # Pagina -> Control que recibe el foco al entrar
var _boton_guardar: Button
var _aviso: Label
var _tween: Tween
var _tween_aviso: Tween
var _slider_musica: HSlider
var _slider_efectos: HSlider
var _casilla_pantalla: CheckButton
var _casilla_avisos: CheckButton
var _etiqueta_carpeta: Label
var _sincronizando := false
var _silenciar_foco := false   # true mientras el foco se pone por código (al cambiar de pantalla)


func _ready() -> void:
	layer = 9
	process_mode = Node.PROCESS_MODE_ALWAYS
	_construir()
	_raiz.visible = false


# --- Abrir y cerrar ---

func abrir() -> void:
	if abierta:
		return
	abierta = true
	Sonido.efecto("ui_aceptar")
	_raiz.visible = true
	_panel.visible = true
	_ir_a(Pagina.PRINCIPAL)
	_boton_guardar.disabled = not Guardado.puede_guardar()
	_boton_guardar.tooltip_text = "" if Guardado.puede_guardar() else "Solo se puede guardar dentro del mundo."
	_aviso.text = ""
	_raiz.modulate.a = 0.0
	_material.set_shader_parameter("fuerza", 0.0)
	if _tween != null:
		_tween.kill()
	_tween = create_tween().set_parallel(true)
	_tween.tween_property(_raiz, "modulate:a", 1.0, SEGUNDOS_ENTRADA)
	_tween.tween_method(func(v: float) -> void: _material.set_shader_parameter("fuerza", v), 0.0, 1.0, SEGUNDOS_ENTRADA)


func cerrar() -> void:
	if not abierta:
		return
	abierta = false
	Sonido.efecto("ui_cancelar")
	if _tween != null:
		_tween.kill()
	_raiz.visible = false   # sin fundido de salida: el juego se reanuda al instante


## Oculta o muestra solo el panel (el fondo desenfocado se queda): para cuando se abre el diario desde aquí.
func ocultar_panel(oculto: bool) -> void:
	_panel.visible = not oculto
	if not oculto:
		_ir_a(pagina)


## ESC dentro del menú: de una pantalla interior vuelve a la principal. Devuelve true si lo gastó
## (false si ya estaba en la principal y entonces el menú debe cerrarse).
func atras() -> bool:
	if pagina == Pagina.PRINCIPAL:
		return false
	Sonido.efecto("ui_cancelar")
	_ir_a(Pagina.PRINCIPAL)
	return true


# --- Navegación con W y S (además de las flechas) ---

func _input(evento: InputEvent) -> void:
	if not abierta or not _panel.visible or (evento is InputEventKey and evento.echo):
		return
	var foco := get_viewport().gui_get_focus_owner()
	if foco == null:
		return
	if evento.is_action_pressed("ABAJO"):
		get_viewport().set_input_as_handled()
		var siguiente := foco.find_next_valid_focus()
		if siguiente != null:
			siguiente.grab_focus()
	elif evento.is_action_pressed("ARRIBA"):
		get_viewport().set_input_as_handled()
		var anterior := foco.find_prev_valid_focus()
		if anterior != null:
			anterior.grab_focus()


# --- Construcción ---

func _construir() -> void:
	_raiz = Control.new()
	_raiz.set_anchors_preset(Control.PRESET_FULL_RECT)
	_raiz.mouse_filter = Control.MOUSE_FILTER_STOP
	_raiz.theme = EstiloUI.tema()
	add_child(_raiz)

	# La imagen del juego, desenfocada y oscura
	_fondo = ColorRect.new()
	_fondo.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fondo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_material = ShaderMaterial.new()
	_material.shader = load(RUTA_SHADER)
	_fondo.material = _material
	_raiz.add_child(_fondo)

	var centro := CenterContainer.new()
	centro.set_anchors_preset(Control.PRESET_FULL_RECT)
	centro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_raiz.add_child(centro)
	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(300, 0)
	_panel.add_theme_stylebox_override("panel", EstiloUI.caja(Color(EstiloUI.MORADO_OSCURO, 0.96), EstiloUI.DORADO, 2, 14, 5))
	centro.add_child(_panel)
	var marco := VBoxContainer.new()
	marco.add_theme_constant_override("separation", 8)
	_panel.add_child(marco)
	var titulo := EstiloUI.etiqueta("Pausa", 20, EstiloUI.DORADO)
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	marco.add_child(titulo)

	_paginas[Pagina.PRINCIPAL] = _construir_principal()
	_paginas[Pagina.CONTROLES] = _construir_controles()
	_paginas[Pagina.OPCIONES] = _construir_opciones()
	_paginas[Pagina.CONFIRMAR] = _construir_confirmacion()
	for p in _paginas.values():
		marco.add_child(p)
		p.visible = false

	_aviso = EstiloUI.etiqueta("", 10, EstiloUI.GRIS)
	_aviso.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	marco.add_child(_aviso)


## `sonido` es el efecto que suena al pulsarlo ("" = ninguno: lo pone otro, como al abrir el diario).
func _boton(texto: String, accion: Callable, sonido: String = "ui_aceptar") -> Button:
	var b := Button.new()
	b.text = texto
	b.custom_minimum_size = Vector2(0, 28)
	b.focus_mode = Control.FOCUS_ALL
	b.pressed.connect(func() -> void:
		Sonido.efecto(sonido)
		accion.call())
	b.focus_entered.connect(_sonar_foco)
	b.mouse_entered.connect(func() -> void:
		if b.visible and not b.disabled:
			b.grab_focus())   # el ratón también mueve el foco
	return b


func _construir_principal() -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 5)
	var continuar := _boton("Continuar", func() -> void: reanudar_pedido.emit(), "")
	v.add_child(continuar)
	v.add_child(_boton("Diario", func() -> void: diario_pedido.emit(), ""))
	v.add_child(_boton("Controles", func() -> void: _ir_a(Pagina.CONTROLES)))
	v.add_child(_boton("Opciones", func() -> void: _ir_a(Pagina.OPCIONES)))
	_boton_guardar = _boton("Guardar partida", _on_guardar)
	v.add_child(_boton_guardar)
	v.add_child(_boton("Volver al título", func() -> void: _ir_a(Pagina.CONFIRMAR)))
	_primer_foco[Pagina.PRINCIPAL] = continuar
	return v


func _construir_controles() -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 5)
	var rejilla := GridContainer.new()
	rejilla.columns = 2
	rejilla.add_theme_constant_override("h_separation", 14)
	rejilla.add_theme_constant_override("v_separation", 4)
	for fila in CONTROLES:
		rejilla.add_child(EstiloUI.etiqueta(fila[0], 11, EstiloUI.DORADO))
		var que := EstiloUI.etiqueta(fila[1], 11, EstiloUI.CREMA)
		que.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		que.custom_minimum_size = Vector2(170, 0)
		rejilla.add_child(que)
	v.add_child(rejilla)
	# Dónde están los datos del juego (partida, resultados y reportes), con un botón para abrir la carpeta
	_etiqueta_carpeta = EstiloUI.etiqueta("", 9, EstiloUI.GRIS)
	_etiqueta_carpeta.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	_etiqueta_carpeta.custom_minimum_size = Vector2(330, 0)
	var carpeta := _boton("Abrir carpeta de datos", func() -> void:
		var ruta := ProjectSettings.globalize_path("user://")
		_etiqueta_carpeta.text = "Carpeta de datos: %s" % ruta
		OS.shell_open(ruta))
	if OS.has_feature("web"):
		# En la web no hay carpeta que abrir: la partida vive en el almacenamiento de este navegador
		carpeta.hide()
		_etiqueta_carpeta.text = "En la web, tu partida se guarda en este navegador."
		_etiqueta_carpeta.add_theme_color_override("font_color", EstiloUI.DORADO)
	v.add_child(carpeta)
	v.add_child(_etiqueta_carpeta)
	var volver := _boton("Volver", func() -> void: _ir_a(Pagina.PRINCIPAL), "ui_cancelar")
	v.add_child(volver)
	_primer_foco[Pagina.CONTROLES] = volver
	return v


func _construir_opciones() -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	_slider_musica = _fila_volumen(v, "Música", Opciones.BUS_MUSICA)
	_slider_efectos = _fila_volumen(v, "Efectos", Opciones.BUS_EFECTOS)
	_casilla_pantalla = CheckButton.new()
	_casilla_pantalla.text = "Pantalla completa"
	_casilla_pantalla.focus_mode = Control.FOCUS_ALL
	_casilla_pantalla.toggled.connect(func(activa: bool) -> void:
		if not _sincronizando:
			Opciones.poner_pantalla_completa(activa))
	_casilla_pantalla.mouse_entered.connect(_casilla_pantalla.grab_focus)
	_casilla_pantalla.focus_entered.connect(_sonar_foco)
	v.add_child(_casilla_pantalla)
	_casilla_avisos = CheckButton.new()
	_casilla_avisos.text = "Avisos de pistas"
	_casilla_avisos.focus_mode = Control.FOCUS_ALL
	_casilla_avisos.toggled.connect(func(activa: bool) -> void:
		if not _sincronizando:
			Opciones.poner_avisos_pistas(activa))
	_casilla_avisos.mouse_entered.connect(_casilla_avisos.grab_focus)
	_casilla_avisos.focus_entered.connect(_sonar_foco)
	v.add_child(_casilla_avisos)
	var volver := _boton("Volver", func() -> void: _ir_a(Pagina.PRINCIPAL), "ui_cancelar")
	v.add_child(volver)
	_primer_foco[Pagina.OPCIONES] = _slider_musica
	return v


## Una fila "nombre + control deslizante" que maneja el volumen de un bus de audio.
func _fila_volumen(padre: Control, nombre: String, bus: String) -> HSlider:
	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", 8)
	var etiqueta := EstiloUI.etiqueta(nombre, 12, EstiloUI.CREMA)
	etiqueta.custom_minimum_size = Vector2(70, 0)
	fila.add_child(etiqueta)
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.custom_minimum_size = Vector2(150, 20)
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.focus_mode = Control.FOCUS_ALL
	slider.value_changed.connect(func(valor: float) -> void:
		if not _sincronizando:
			Opciones.poner_volumen(bus, valor)
			Sonido.efecto("ui_mover"))
	slider.focus_entered.connect(_sonar_foco)
	slider.mouse_entered.connect(slider.grab_focus)
	fila.add_child(slider)
	padre.add_child(fila)
	return slider


func _construir_confirmacion() -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	var pregunta := EstiloUI.etiqueta("¿Volver al título?", 14, EstiloUI.CREMA)
	pregunta.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(pregunta)
	var detalle := EstiloUI.etiqueta("Tu partida se guarda antes de salir.", 10, EstiloUI.GRIS)
	detalle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(detalle)
	var si := _boton("Sí, volver al título", func() -> void: volver_al_titulo_pedido.emit())
	v.add_child(si)
	var no := _boton("No, seguir aquí", func() -> void: _ir_a(Pagina.PRINCIPAL), "ui_cancelar")
	v.add_child(no)
	_primer_foco[Pagina.CONFIRMAR] = no   # por seguridad el foco empieza en "No"
	return v


# --- Páginas ---

func _ir_a(nueva: Pagina) -> void:
	pagina = nueva
	for p in _paginas:
		_paginas[p].visible = p == nueva
	if nueva == Pagina.OPCIONES:
		_sincronizar_opciones()
	_aviso.text = ""
	# El foco se pone al terminar el fotograma, cuando los botones ya son visibles
	var objetivo: Control = _primer_foco[nueva]
	_silenciar_foco = true   # poner el foco por código no hace sonar el "mover"
	objetivo.grab_focus.call_deferred()
	_quitar_silencio_foco.call_deferred()


func _quitar_silencio_foco() -> void:
	_silenciar_foco = false


func _sonar_foco() -> void:
	if abierta and not _silenciar_foco:
		Sonido.efecto("ui_mover")


func _sincronizar_opciones() -> void:
	_sincronizando = true
	_slider_musica.value = Opciones.volumen_musica
	_slider_efectos.value = Opciones.volumen_efectos
	_casilla_pantalla.button_pressed = Opciones.pantalla_completa
	_casilla_avisos.button_pressed = Opciones.avisos_pistas
	_sincronizando = false


func _on_guardar() -> void:
	var bien := Guardado.guardar_ahora()
	_mostrar_aviso("Partida guardada." if bien else "No se pudo guardar.")


func _mostrar_aviso(texto: String) -> void:
	_aviso.text = texto
	_aviso.modulate.a = 1.0
	if _tween_aviso != null:
		_tween_aviso.kill()
	_tween_aviso = create_tween()
	_tween_aviso.tween_interval(1.6)
	_tween_aviso.tween_property(_aviso, "modulate:a", 0.0, 0.4)
