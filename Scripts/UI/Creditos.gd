class_name Creditos
extends CanvasLayer
## Créditos: un texto que se desplaza suavemente sobre el fondo del título (capa 13). El contenido se edita en
## Resources/creditos.txt (secciones con "# ", líneas de texto, espacios en blanco y una nota final con "> ").
## Se cierra solo al terminar, o con ENTER, ESPACIO, ESC o un clic. Flecha abajo acelera el desplazamiento.
##
## Uso:   await Creditos.mostrar(get_tree())

const ESCENA := "res://Scenes/UI/Creditos.tscn"
const RUTA_TEXTO := "res://Resources/creditos.txt"
const VELOCIDAD := 26.0   # píxeles por segundo
const ANCHO := 420.0

signal cerrados

var _raiz: Control
var _columna: VBoxContainer
var _y := 0.0
var _cerrando := false


static func mostrar(arbol: SceneTree) -> void:
	var escena := (load(ESCENA) as PackedScene).instantiate() as Creditos
	arbol.root.add_child.call_deferred(escena)
	await escena.tree_exited


func _ready() -> void:
	layer = 13
	process_mode = Node.PROCESS_MODE_ALWAYS
	FondoEvaluacion.crear(self).hide()   # solo el fondo; sin el Guía
	_raiz = Control.new()
	_raiz.set_anchors_preset(Control.PRESET_FULL_RECT)
	_raiz.mouse_filter = Control.MOUSE_FILTER_STOP
	_raiz.modulate.a = 0.0
	_raiz.clip_contents = true
	add_child(_raiz)
	_columna = VBoxContainer.new()
	_columna.add_theme_constant_override("separation", 6)
	_columna.custom_minimum_size = Vector2(ANCHO, 0)
	_raiz.add_child(_columna)
	_leer_texto()
	var pie := EstiloUI.etiqueta("ENTER o ESC para salir", 9, EstiloUI.GRIS)
	pie.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	pie.offset_top = -16.0
	pie.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pie.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_raiz.add_child(pie)
	create_tween().tween_property(_raiz, "modulate:a", 1.0, 0.6)
	await get_tree().process_frame
	await get_tree().process_frame
	_columna.size = Vector2(ANCHO, _columna.get_combined_minimum_size().y)
	_y = _raiz.size.y + 10.0   # empieza justo debajo de la pantalla
	_columna.position = Vector2((_raiz.size.x - ANCHO) / 2.0, _y)


## Lee Resources/creditos.txt y crea una etiqueta por línea.
func _leer_texto() -> void:
	var texto := FileAccess.get_file_as_string(RUTA_TEXTO)
	for linea in texto.split("\n"):
		var l := linea.strip_edges()
		if l.begins_with("#") and not l.begins_with("# "):
			continue
		if l.begins_with("# "):
			# Los comentarios del principio del archivo (antes de la primera sección) también empiezan con "# ":
			# se distinguen porque el primer título real es "Juego"
			if _columna.get_child_count() == 0 and l != "# Juego":
				continue
			_columna.add_child(_espacio(18))
			var titulo := EstiloUI.etiqueta(l.substr(2), 16, EstiloUI.DORADO)
			titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			_columna.add_child(titulo)
		elif l == "":
			if _columna.get_child_count() > 0:
				_columna.add_child(_espacio(6))
		elif l.begins_with("> "):
			_columna.add_child(_espacio(30))
			var nota := EstiloUI.etiqueta(l.substr(2), 12, EstiloUI.CREMA)
			nota.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			nota.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			nota.custom_minimum_size = Vector2(ANCHO, 0)
			_columna.add_child(nota)
		else:
			if _columna.get_child_count() == 0:
				continue
			var e := EstiloUI.etiqueta(l, 12, EstiloUI.CREMA if not l.begins_with("[COMPLETAR") else Color("e0a070"))
			e.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			e.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			e.custom_minimum_size = Vector2(ANCHO, 0)
			_columna.add_child(e)
	_columna.add_child(_espacio(120))


func _espacio(alto: int) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, alto)
	return c


func _process(delta: float) -> void:
	if _cerrando or _columna == null or _y == 0.0:
		return
	var rapido := Input.is_key_pressed(KEY_DOWN)
	_y -= VELOCIDAD * (4.0 if rapido else 1.0) * delta
	_columna.position.y = _y
	if _y + _columna.size.y < -10.0:
		_cerrar()


func _input(evento: InputEvent) -> void:
	if _cerrando:
		return
	var salir := evento.is_action_pressed("ui_accept") or evento.is_action_pressed("ui_cancel") or evento.is_action_pressed("PAUSA")
	if evento is InputEventMouseButton and evento.pressed and evento.button_index == MOUSE_BUTTON_LEFT:
		salir = true
	if salir:
		get_viewport().set_input_as_handled()
		_cerrar()


func _cerrar() -> void:
	if _cerrando:
		return
	_cerrando = true
	Sonido.efecto("ui_cancelar")
	cerrados.emit()
	var t := create_tween()
	t.tween_property(_raiz, "modulate:a", 0.0, 0.4)
	await t.finished
	queue_free()
