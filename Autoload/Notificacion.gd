extends Node
## Tarjetas de aviso arriba a la derecha (por ejemplo, "Habilidad desbloqueada").
## Entran deslizando, se quedan unos segundos y salen con fundido. Si llegan varias, van en cola.
##
##   Notificacion.mostrar("Título", "Texto de la tarjeta")

const ESCENA := preload("res://Scenes/UI/Notificacion.tscn")
const RUTA_FUENTE := "res://Assets/PixelifySans-VariableFont_wght.ttf"

const ANCHO := 220.0
const MARGEN := 12.0
const SEGUNDOS_VISIBLE := 3.0
const SEGUNDOS_ENTRADA := 0.4
const SEGUNDOS_SALIDA := 0.5

## true mientras haya una tarjeta en pantalla.
var mostrando := false

var _cola: Array[Dictionary] = []
var _capa: CanvasLayer
var _tarjeta: PanelContainer
var _titulo: Label
var _texto: Label


func _ready() -> void:
	_capa = ESCENA.instantiate()
	add_child(_capa)
	_tarjeta = _capa.get_node("%Tarjeta")
	_titulo = _capa.get_node("%Titulo")
	_texto = _capa.get_node("%Texto")
	_aplicar_estilo()
	# Al integrar una emoción se avisa de la habilidad que da
	GameState.habilidad_desbloqueada.connect(_on_habilidad_desbloqueada)


## Cuántas tarjetas esperan su turno.
func pendientes() -> int:
	return _cola.size()


## Muestra una tarjeta (o la pone en la cola si ya hay una en pantalla).
func mostrar(titulo: String, texto: String) -> void:
	_cola.append({"titulo": titulo, "texto": texto})
	if not mostrando:
		_procesar_cola()


func _procesar_cola() -> void:
	mostrando = true
	while not _cola.is_empty():
		await _mostrar_una(_cola.pop_front())
	mostrando = false


func _mostrar_una(aviso: Dictionary) -> void:
	_titulo.text = aviso["titulo"]
	_texto.text = aviso["texto"]
	_texto.visible = aviso["texto"] != ""
	_tarjeta.modulate.a = 1.0
	_tarjeta.visible = true
	# Un contenedor no encoge solo: se pide el tamaño mínimo para que el alto se ajuste al texto
	await get_tree().process_frame
	_tarjeta.reset_size()
	await get_tree().process_frame

	var ancho_pantalla := _tarjeta.get_viewport_rect().size.x
	var destino := ancho_pantalla - ANCHO - MARGEN
	_tarjeta.position = Vector2(ancho_pantalla + 10.0, MARGEN)

	# Entra deslizando desde la derecha
	var entrada := create_tween()
	entrada.tween_property(_tarjeta, "position:x", destino, SEGUNDOS_ENTRADA) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await entrada.finished

	await get_tree().create_timer(SEGUNDOS_VISIBLE).timeout

	# Sale con fundido
	var salida := create_tween()
	salida.tween_property(_tarjeta, "modulate:a", 0.0, SEGUNDOS_SALIDA)
	await salida.finished
	_tarjeta.visible = false


func _on_habilidad_desbloqueada(habilidad_id: String) -> void:
	for id in GameState.ids_emociones():
		var datos := GameState.obtener_datos(id)
		if datos.habilidad_id == habilidad_id:
			mostrar("Habilidad desbloqueada: %s" % datos.habilidad_nombre, datos.habilidad_descripcion)
			return
	mostrar("Habilidad desbloqueada", habilidad_id)


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
	_titulo.add_theme_font_size_override("font_size", 16)
	_texto.add_theme_font_size_override("font_size", 14)
	_titulo.add_theme_color_override("font_color", Color("f4c77b"))
	_texto.add_theme_color_override("font_color", Color("fff4dc"))
