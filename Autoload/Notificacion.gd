extends Node
## Tarjetas de aviso arriba a la derecha (por ejemplo, "Habilidad desbloqueada").
## Entran deslizando, se quedan el tiempo que pide su texto y salen con fundido. Si llegan varias, van
## de una en una (la siguiente aparece 0.4 s después) y con un contador "1 de 3".
##
##   Notificacion.mostrar("Título", "Texto de la tarjeta")
##   Notificacion.mostrar("Título", "Texto", true)   # importante: dura más y espera a ser cerrada
##
## Duración: 4 s + 0.07 s por carácter (mínimo 6 s, máximo 14 s). Las importantes (habilidad desbloqueada,
## mejora, regalo) esperan hasta 20 s a que el jugador las cierre. En Pausa, "Duración de los avisos"
## la duplica (Larga) o la deja hasta cerrar. La cuenta atrás se detiene con el ratón encima de la
## tarjeta y mientras hay un diálogo, un menú o el diario abiertos. Se cierra con la "✕" o con la tecla X
## (acción CERRAR_AVISO). Todo aviso queda anotado en GameState.avisos (sección "Avisos" del diario).

const ESCENA := preload("res://Scenes/UI/Notificacion.tscn")
const RUTA_FUENTE := "res://Assets/PixelifySans-VariableFont_wght.ttf"

const ANCHO := 220.0
const MARGEN := 12.0
const SEGUNDOS_ENTRADA := 0.3
## Cuánto baja la tarjeta al entrar (px): lo único que se mueve además de la opacidad.
const DESPLAZAMIENTO_ENTRADA := 8.0
const SEGUNDOS_SALIDA := 0.25
const SEGUNDOS_ENTRE_AVISOS := 0.4
const BASE_SEGUNDOS := 4.0
const SEGUNDOS_POR_CARACTER := 0.07
const MINIMO_SEGUNDOS := 6.0
const MAXIMO_SEGUNDOS := 14.0
## Las importantes no se van antes de MINIMO_IMPORTANTE (salvo que el jugador las cierre) y como mucho
## esperan MAXIMO_IMPORTANTE.
const MINIMO_IMPORTANTE := 8.0
const MAXIMO_IMPORTANTE := 20.0

## true mientras haya una tarjeta en pantalla.
var mostrando := false
## true mientras la cuenta atrás de la tarjeta actual está corriendo (no pausada ni cerrada).
var contando := false
## Segundos que le quedan a la tarjeta actual (INF = hasta que se cierre).
var restante := 0.0

var _cola: Array[Dictionary] = []
var _capa: CanvasLayer
var _tarjeta: PanelContainer
var _titulo: Label
var _texto: Label
var _contador: Label
var _boton_cerrar: Button
var _raton_encima := false
var _cerrar_pedido := false
var _numero_en_tanda := 0
var _total_en_tanda := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS   # así también se puede cerrar con el juego en pausa
	_capa = ESCENA.instantiate()
	add_child(_capa)
	_tarjeta = _capa.get_node("%Tarjeta")
	_titulo = _capa.get_node("%Titulo")
	_texto = _capa.get_node("%Texto")
	_construir_cabecera_y_pie()
	_aplicar_estilo()
	_tarjeta.mouse_filter = Control.MOUSE_FILTER_STOP
	_tarjeta.mouse_entered.connect(func() -> void: _raton_encima = true)
	_tarjeta.mouse_exited.connect(func() -> void: _raton_encima = false)
	# Al integrar una emoción se avisa de la habilidad que da
	GameState.habilidad_desbloqueada.connect(_on_habilidad_desbloqueada)


## Cuántas tarjetas esperan su turno.
func pendientes() -> int:
	return _cola.size()


## Segundos que dura una tarjeta con ese texto (sin la opción de duración).
static func segundos_base(titulo: String, texto: String, importante := false) -> float:
	if importante:
		return MAXIMO_IMPORTANTE
	var largo := titulo.length() + texto.length()
	return clampf(BASE_SEGUNDOS + SEGUNDOS_POR_CARACTER * largo, MINIMO_SEGUNDOS, MAXIMO_SEGUNDOS)


## Segundos que durará de verdad, según "Duración de los avisos" (INF = hasta cerrar).
func duracion_para(titulo: String, texto: String, importante := false) -> float:
	match Opciones.duracion_avisos:
		1:
			return segundos_base(titulo, texto, importante) * 2.0
		2:
			return INF
	return segundos_base(titulo, texto, importante)


## Muestra una tarjeta (o la pone en la cola si ya hay una en pantalla).
func mostrar(titulo: String, texto: String, importante := false) -> void:
	GameState.registrar_aviso(titulo, texto)
	_cola.append({"titulo": titulo, "texto": texto, "importante": importante})
	_total_en_tanda += 1
	_actualizar_contador()
	if not mostrando:
		_procesar_cola()


## Cierra la tarjeta que se ve (con un fundido corto). No hace nada si no hay ninguna.
func cerrar() -> void:
	if mostrando and _tarjeta.visible:
		_cerrar_pedido = true


## ¿La cuenta atrás debe esperar? (ratón encima, diálogo, menú o diario abiertos)
func _en_espera() -> bool:
	return _raton_encima or Dialogo.hay_dialogo() or Menus.hay_menu()


func _unhandled_input(evento: InputEvent) -> void:
	if evento.is_action_pressed("CERRAR_AVISO") and not evento.is_echo() and mostrando and _tarjeta.visible:
		cerrar()
		get_viewport().set_input_as_handled()


func _procesar_cola() -> void:
	mostrando = true
	while not _cola.is_empty():
		await _mostrar_una(_cola.pop_front())
		if not _cola.is_empty():
			await get_tree().create_timer(SEGUNDOS_ENTRE_AVISOS, true).timeout
	mostrando = false
	_numero_en_tanda = 0
	_total_en_tanda = 0


func _mostrar_una(aviso: Dictionary) -> void:
	_numero_en_tanda += 1
	_actualizar_contador()
	_cerrar_pedido = false
	# La tarjeta se prepara OCULTA (opacidad 0): texto completo, tamaño estable y posición final antes de verse
	_tarjeta.modulate.a = 0.0
	_titulo.text = aviso["titulo"]
	_texto.text = aviso["texto"]
	_texto.visible = aviso["texto"] != ""
	_tarjeta.visible = true
	# Un contenedor no encoge solo: se pide el tamaño mínimo y se espera (hasta 4 fotogramas) a que se estabilice
	var anterior := Vector2(-1, -1)
	for i in 4:
		await get_tree().process_frame
		_tarjeta.reset_size()
		if _tarjeta.size == anterior:
			break
		anterior = _tarjeta.size
	var tamano_final := _tarjeta.size
	_tarjeta.size = tamano_final

	var ancho_pantalla := _tarjeta.get_viewport_rect().size.x
	var destino := Vector2(ancho_pantalla - ANCHO - MARGEN, MARGEN)
	_tarjeta.position = destino - Vector2(0, DESPLAZAMIENTO_ENTRADA)

	# Entra con un fundido y un pequeño desplazamiento vertical (el tamaño y la posición horizontal no cambian)
	var entrada := create_tween().set_parallel(true)
	entrada.tween_property(_tarjeta, "modulate:a", 1.0, SEGUNDOS_ENTRADA)
	entrada.tween_property(_tarjeta, "position:y", destino.y, SEGUNDOS_ENTRADA) 		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	await entrada.finished

	# Cuenta atrás: se detiene con el ratón encima y con diálogos o menús abiertos
	restante = duracion_para(aviso["titulo"], aviso["texto"], aviso["importante"])
	var ultimo := Time.get_ticks_usec()
	while restante > 0.0 and not _cerrar_pedido:
		await get_tree().process_frame
		var ahora := Time.get_ticks_usec()
		contando = not _en_espera()
		if contando:
			restante -= float(ahora - ultimo) / 1000000.0
		ultimo = ahora
	contando = false

	# Sale con fundido
	var salida := create_tween()
	salida.tween_property(_tarjeta, "modulate:a", 0.0, SEGUNDOS_SALIDA)
	await salida.finished
	_tarjeta.visible = false
	_raton_encima = false


func _actualizar_contador() -> void:
	if _contador == null:
		return
	_contador.text = "%d de %d" % [_numero_en_tanda, _total_en_tanda] if _total_en_tanda > 1 else ""


## Arma la fila del título con el botón "✕" y el pie con el contador y "X cerrar".
func _construir_cabecera_y_pie() -> void:
	var contenido: VBoxContainer = _titulo.get_parent()
	var fila := HBoxContainer.new()
	fila.mouse_filter = Control.MOUSE_FILTER_IGNORE
	contenido.add_child(fila)
	contenido.move_child(fila, 0)
	_titulo.reparent(fila)
	_titulo.custom_minimum_size = Vector2(176, 0)
	_titulo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_boton_cerrar = Button.new()
	_boton_cerrar.text = "✕"
	_boton_cerrar.flat = true
	_boton_cerrar.focus_mode = Control.FOCUS_NONE
	_boton_cerrar.custom_minimum_size = Vector2(20, 20)
	_boton_cerrar.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_boton_cerrar.pressed.connect(cerrar)
	fila.add_child(_boton_cerrar)
	var pie := HBoxContainer.new()
	pie.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_contador = Label.new()
	_contador.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_contador.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pie.add_child(_contador)
	var cerrar_texto := Label.new()
	cerrar_texto.text = "X cerrar"
	cerrar_texto.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pie.add_child(cerrar_texto)
	contenido.add_child(pie)
	for e in [_contador, cerrar_texto]:
		e.add_theme_font_size_override("font_size", 10)
		e.add_theme_color_override("font_color", Color("a99bc4"))
	_boton_cerrar.add_theme_color_override("font_color", Color("f4c77b"))
	_boton_cerrar.add_theme_color_override("font_hover_color", Color("fff4dc"))


func _on_habilidad_desbloqueada(habilidad_id: String) -> void:
	for id in GameState.ids_emociones():
		var datos := GameState.obtener_datos(id)
		if datos.habilidad_id == habilidad_id:
			mostrar("Habilidad desbloqueada: %s" % datos.habilidad_nombre, datos.habilidad_descripcion, true)
			return
	mostrar("Habilidad desbloqueada", habilidad_id, true)


## Mismo estilo que la caja de diálogo: morado oscuro, borde dorado, Pixelify Sans.
func _aplicar_estilo() -> void:
	var caja := StyleBoxFlat.new()
	caja.bg_color = Color("1e1b2e", 0.95)
	caja.border_color = Color("f4c77b")
	caja.set_border_width_all(2)
	caja.set_corner_radius_all(4)
	caja.set_content_margin_all(8)
	_tarjeta.add_theme_stylebox_override("panel", caja)

	if ResourceLoader.exists(RUTA_FUENTE):
		var fuente: Font = load(RUTA_FUENTE)
		_titulo.add_theme_font_override("font", fuente)
		_texto.add_theme_font_override("font", fuente)
		_boton_cerrar.add_theme_font_override("font", fuente)
		for e in _contador.get_parent().get_children():
			e.add_theme_font_override("font", fuente)
	_titulo.add_theme_font_size_override("font_size", 16)
	_texto.add_theme_font_size_override("font_size", 14)
	_titulo.add_theme_color_override("font_color", Color("f4c77b"))
	_texto.add_theme_color_override("font_color", Color("fff4dc"))
