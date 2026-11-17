class_name Diario
extends CanvasLayer
## El diario de emociones (capa 8): un libro antiguo morado y dorado que se abre con TAB. Cuatro
## secciones: Emociones (7 tarjetas), Habilidades, Recuerdos (los fragmentos de memoria) y Progreso.
## Se navega con izquierda y derecha (o A y D), y con el ratón en las pestañas y las flechas. En
## Recuerdos, arriba y abajo eligen el recuerdo.
##
## No decide cuándo se puede abrir: lo hace el autoload Menus (no durante diálogos, el onboarding, los
## cuestionarios ni una transición). Sigue funcionando con el juego en pausa.

signal cerrado

const SECCIONES := ["Emociones", "Habilidades", "Recuerdos", "Regalos", "Conexiones", "Pistas", "Progreso"]
const RUTA_ICONOS := "res://Assets/UI/iconos_habilidades.png"
const TAMANO_LIBRO := Vector2(580, 316)
const COLOR_ESTADO := {
	"pendiente": Color("8a8499"), "atacada": Color("c0443a"), "ignorada": Color("8b5a2b"), "integrada": Color("f4c77b"),
}
const NOMBRE_ESTADO := {"pendiente": "Pendiente", "atacada": "Atacada", "ignorada": "Ignorada", "integrada": "Integrada"}
## Un sello claro lleva letra oscura y uno oscuro, letra clara.
const LETRA_ESTADO := {
	"pendiente": Color("1e1b2e"), "atacada": Color("fff4dc"), "ignorada": Color("fff4dc"), "integrada": Color("1e1b2e"),
}
const SEGUNDOS_ENTRADA := 0.2
const SEGUNDOS_SALIDA := 0.15

var abierto := false
var seccion := 0

var _raiz: Control
var _libro: Control
var _contenido: Control
var _pie: Label
var _botones: Array[Button] = []
var _tween: Tween
var _tween_seccion: Tween
var _recuerdo := 0
var _lista_recuerdos: Array[Button] = []
var _detalle_titulo: Label
var _detalle_texto: Label
var _iconos: Texture2D


func _ready() -> void:
	layer = 8
	process_mode = Node.PROCESS_MODE_ALWAYS   # funciona también con el juego en pausa
	if ResourceLoader.exists(RUTA_ICONOS):
		_iconos = load(RUTA_ICONOS)
	_construir()
	_raiz.visible = false


# --- Abrir y cerrar ---

## Abre el diario en una sección (0 = Emociones). Con fundido de entrada.
func abrir(inicial: int = 0) -> void:
	if abierto:
		return
	abierto = true
	Sonido.efecto("diario_abrir")
	seccion = clampi(inicial, 0, SECCIONES.size() - 1)
	_recuerdo = 0
	_raiz.visible = true
	_raiz.modulate.a = 0.0
	_mostrar_seccion()
	if _tween != null:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(_raiz, "modulate:a", 1.0, SEGUNDOS_ENTRADA)


func cerrar() -> void:
	if not abierto:
		return
	abierto = false   # el estado cambia ya; el fundido de salida es solo visual
	Sonido.efecto("diario_cerrar")
	if _tween != null:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(_raiz, "modulate:a", 0.0, SEGUNDOS_SALIDA)
	_tween.tween_callback(func() -> void:
		if not abierto:
			_raiz.visible = false)
	cerrado.emit()


# --- Entrada ---

func _input(evento: InputEvent) -> void:
	if not abierto or (evento is InputEventKey and evento.echo):
		return
	if evento.is_action_pressed("DERECHA") or evento.is_action_pressed("ui_right"):
		get_viewport().set_input_as_handled()
		cambiar_seccion(1)
	elif evento.is_action_pressed("IZQUIERDA") or evento.is_action_pressed("ui_left"):
		get_viewport().set_input_as_handled()
		cambiar_seccion(-1)
	elif seccion == 2 and (evento.is_action_pressed("ABAJO") or evento.is_action_pressed("ui_down")):
		get_viewport().set_input_as_handled()
		_elegir_recuerdo(_recuerdo + 1)
	elif seccion == 2 and (evento.is_action_pressed("ARRIBA") or evento.is_action_pressed("ui_up")):
		get_viewport().set_input_as_handled()
		_elegir_recuerdo(_recuerdo - 1)


## Pasa a la sección siguiente (paso = 1) o anterior (paso = -1), dando la vuelta.
func cambiar_seccion(paso: int) -> void:
	ir_a_seccion(posmod(seccion + paso, SECCIONES.size()))


func ir_a_seccion(indice: int) -> void:
	if indice == seccion or not abierto:
		return
	seccion = indice
	_mostrar_seccion()


# --- Construcción del libro ---

func _construir() -> void:
	_raiz = Control.new()
	_raiz.set_anchors_preset(Control.PRESET_FULL_RECT)
	_raiz.mouse_filter = Control.MOUSE_FILTER_STOP   # no deja pasar los clics al juego
	_raiz.theme = EstiloUI.tema()
	add_child(_raiz)

	var velo := ColorRect.new()
	velo.set_anchors_preset(Control.PRESET_FULL_RECT)
	velo.color = Color(0.04, 0.02, 0.09, 0.62)
	velo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_raiz.add_child(velo)

	_libro = Control.new()
	_libro.set_anchors_preset(Control.PRESET_CENTER)
	_libro.offset_left = -TAMANO_LIBRO.x / 2.0
	_libro.offset_right = TAMANO_LIBRO.x / 2.0
	_libro.offset_top = -TAMANO_LIBRO.y / 2.0
	_libro.offset_bottom = TAMANO_LIBRO.y / 2.0
	_libro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_libro.draw.connect(_dibujar_adornos)
	_raiz.add_child(_libro)

	# Tapa y página
	var tapa := Panel.new()
	tapa.size = TAMANO_LIBRO
	tapa.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tapa.add_theme_stylebox_override("panel", EstiloUI.caja(Color("181426"), EstiloUI.DORADO, 3, 0, 8))
	_libro.add_child(tapa)
	var pagina := Panel.new()
	pagina.position = Vector2(10, 10)
	pagina.size = TAMANO_LIBRO - Vector2(20, 20)
	pagina.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pagina.add_theme_stylebox_override("panel", EstiloUI.caja(Color("2a2440"), EstiloUI.DORADO.darkened(0.45), 1, 0, 3))
	_libro.add_child(pagina)

	# Cabecera: flecha, cuatro pestañas y flecha
	var cabecera := HBoxContainer.new()
	cabecera.position = Vector2(18, 16)
	cabecera.size = Vector2(TAMANO_LIBRO.x - 36, 22)
	cabecera.add_theme_constant_override("separation", 4)
	cabecera.alignment = BoxContainer.ALIGNMENT_CENTER
	_libro.add_child(cabecera)
	cabecera.add_child(_boton("<", 26, func() -> void: cambiar_seccion(-1)))
	for i in SECCIONES.size():
		var b := _boton(SECCIONES[i], 64, ir_a_seccion.bind(i))
		_botones.append(b)
		cabecera.add_child(b)
	cabecera.add_child(_boton(">", 26, func() -> void: cambiar_seccion(1)))

	_contenido = Control.new()
	_contenido.position = Vector2(18, 48)
	_contenido.size = Vector2(TAMANO_LIBRO.x - 36, 228)
	_contenido.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_libro.add_child(_contenido)

	_pie = EstiloUI.etiqueta("", 9, EstiloUI.GRIS)
	_pie.position = Vector2(18, 288)
	_pie.size = Vector2(TAMANO_LIBRO.x - 36, 14)
	_pie.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_libro.add_child(_pie)


## Un botón de pestaña o flecha. No toma el foco del teclado (TAB debe llegar al juego para cerrar).
func _boton(texto: String, ancho: int, accion: Callable) -> Button:
	var b := Button.new()
	b.text = texto
	b.custom_minimum_size = Vector2(ancho, 22)
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 10 if ancho < 70 else 12)
	b.pressed.connect(accion)
	return b


## Adornos del libro: remaches dorados en las esquinas, línea bajo las pestañas y esquinas de página.
func _dibujar_adornos() -> void:
	var oro := EstiloUI.DORADO
	for esquina in [Vector2(5, 5), Vector2(TAMANO_LIBRO.x - 5, 5), Vector2(5, TAMANO_LIBRO.y - 5), TAMANO_LIBRO - Vector2(5, 5)]:
		_libro.draw_circle(esquina, 2.5, oro)
	_libro.draw_line(Vector2(18, 42), Vector2(TAMANO_LIBRO.x - 18, 42), Color(oro, 0.55), 1.0)
	_libro.draw_line(Vector2(18, 44), Vector2(TAMANO_LIBRO.x - 18, 44), Color(oro, 0.25), 1.0)
	# esquinas dobladas de la página
	var x := TAMANO_LIBRO.x - 10
	var y := TAMANO_LIBRO.y - 10
	_libro.draw_colored_polygon(PackedVector2Array([Vector2(x - 14, y), Vector2(x, y - 14), Vector2(x, y)]), Color("3a3358"))
	_libro.draw_line(Vector2(x - 14, y), Vector2(x, y - 14), Color(oro, 0.6), 1.0)


# --- Secciones ---

## Reconstruye el contenido de la sección actual (con un pequeño fundido).
func _mostrar_seccion() -> void:
	for hijo in _contenido.get_children():
		hijo.hide()
		hijo.queue_free()
	_lista_recuerdos.clear()
	match seccion:
		0:
			_crear_emociones()
		1:
			_crear_habilidades()
		2:
			_crear_recuerdos()
		3:
			_crear_regalos()
		4:
			_crear_conexiones()
		5:
			_crear_pistas()
		6:
			_crear_progreso()
	for i in _botones.size():
		var activa := i == seccion
		_botones[i].add_theme_stylebox_override("normal", EstiloUI.caja(EstiloUI.MORADO_PULSADO if activa else EstiloUI.MORADO, EstiloUI.DORADO if activa else EstiloUI.MORADO, 2 if activa else 1, 4))
		_botones[i].add_theme_color_override("font_color", EstiloUI.DORADO if activa else Color("d9cfe8"))
	_pie.text = "A / D o flechas: cambiar de sección%s  ·  TAB: cerrar  ·  %d/%d" % [
		"  ·  W / S: elegir recuerdo" if seccion == 2 else "", seccion + 1, SECCIONES.size()]
	if _tween_seccion != null:
		_tween_seccion.kill()
	_contenido.modulate.a = 0.0
	_tween_seccion = create_tween()
	_tween_seccion.tween_property(_contenido, "modulate:a", 1.0, 0.12)


# Emociones -------------------------------------------------------------

func _crear_emociones() -> void:
	var rejilla := GridContainer.new()
	rejilla.columns = 4
	rejilla.add_theme_constant_override("h_separation", 6)
	rejilla.add_theme_constant_override("v_separation", 6)
	_contenido.add_child(rejilla)
	for id in GameState.ids_emociones():
		rejilla.add_child(_tarjeta_emocion(GameState.obtener_datos(id)))


func _tarjeta_emocion(datos: EmocionData) -> Control:
	var estado: String = GameState.estado.get(datos.id, "pendiente")
	var tarjeta := PanelContainer.new()
	tarjeta.custom_minimum_size = Vector2(132, 110)
	tarjeta.add_theme_stylebox_override("panel", EstiloUI.caja(Color("1e1b2e"), Color(COLOR_ESTADO[estado], 0.6), 1, 4, 3))
	var columna := VBoxContainer.new()
	columna.add_theme_constant_override("separation", 1)
	tarjeta.add_child(columna)

	# El sprite animado (en calma si ya está integrada)
	var hueco := Control.new()
	hueco.custom_minimum_size = Vector2(0, 38)
	hueco.mouse_filter = Control.MOUSE_FILTER_IGNORE
	columna.add_child(hueco)
	if datos.frames != null:
		var sprite := AnimatedSprite2D.new()
		sprite.sprite_frames = datos.frames
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sprite.scale = Vector2(0.6, 0.6)
		sprite.position = Vector2(62, 19)
		var animacion := &"calma" if estado == "integrada" else &"idle"
		if not datos.frames.has_animation(animacion) or datos.frames.get_frame_count(animacion) == 0:
			animacion = &"idle"
		if datos.frames.has_animation(animacion) and datos.frames.get_frame_count(animacion) > 0:
			sprite.play(animacion)
		hueco.add_child(sprite)

	var nombre := EstiloUI.etiqueta(datos.nombre, 12, EstiloUI.DORADO)
	nombre.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	columna.add_child(nombre)

	# Sello de estado, con su color
	var sello := EstiloUI.etiqueta(NOMBRE_ESTADO[estado], 9, LETRA_ESTADO[estado])
	sello.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sello.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	sello.add_theme_stylebox_override("normal", EstiloUI.caja(COLOR_ESTADO[estado], COLOR_ESTADO[estado].darkened(0.3), 1, 3, 3))
	columna.add_child(sello)

	var habilidad := EstiloUI.etiqueta("Habilidad: %s" % datos.habilidad_nombre, 9, Color("d9cfe8"))
	habilidad.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	columna.add_child(habilidad)

	# Su mensaje, solo si está integrada
	var mensaje := EstiloUI.etiqueta(datos.mensaje_integracion if estado == "integrada" else "", 8, EstiloUI.CREMA)
	mensaje.custom_minimum_size = Vector2(118, 28)
	mensaje.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	mensaje.max_lines_visible = 3
	mensaje.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	mensaje.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	columna.add_child(mensaje)
	if estado == "integrada":
		tarjeta.tooltip_text = datos.mensaje_integracion
	return tarjeta


# Habilidades -----------------------------------------------------------

func _crear_habilidades() -> void:
	var lista := VBoxContainer.new()
	lista.add_theme_constant_override("separation", 3)
	lista.size = _contenido.size
	_contenido.add_child(lista)
	var numero := 0
	for entrada in Habilidades.catalogo:
		var desbloqueada := Habilidades.esta_desbloqueada(entrada["id"])
		var fila := PanelContainer.new()
		fila.custom_minimum_size = Vector2(_contenido.size.x, 30)
		fila.add_theme_stylebox_override("panel", EstiloUI.caja(Color("1e1b2e"), Color(entrada["color"], 0.5) if desbloqueada else Color("3a3358"), 1, 3, 3))
		var linea := HBoxContainer.new()
		linea.add_theme_constant_override("separation", 8)
		fila.add_child(linea)
		linea.add_child(_icono_habilidad(numero, entrada["color"], desbloqueada))
		var textos := VBoxContainer.new()
		textos.add_theme_constant_override("separation", -1)
		textos.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var mejorada := desbloqueada and Habilidades.nivel_de(entrada["id"]) >= 2
		textos.add_child(EstiloUI.etiqueta(("%s  ·  nivel %d" % [entrada["nombre"], Habilidades.nivel_de(entrada["id"])]) if desbloqueada else "???", 12, EstiloUI.DORADO if desbloqueada else EstiloUI.GRIS))
		var descripcion: String = entrada["descripcion"] if desbloqueada else "???"
		if mejorada:
			var emocion := GameState.obtener_datos(str(entrada["emocion"]))
			descripcion = emocion.mejora_descripcion if emocion != null and emocion.mejora_descripcion != "" else descripcion
		textos.add_child(EstiloUI.etiqueta(descripcion, 9, Color("d9cfe8") if desbloqueada else EstiloUI.GRIS))
		linea.add_child(textos)
		linea.add_child(EstiloUI.etiqueta("Tecla %d" % (numero + 1), 10, EstiloUI.DORADO if desbloqueada else EstiloUI.GRIS))
		lista.add_child(fila)
		numero += 1


## El ícono de la hoja de íconos (o el candado si está bloqueada); sin la hoja, un círculo de color.
func _icono_habilidad(indice: int, color: Color, desbloqueada: bool) -> Control:
	if _iconos != null:
		var cuadro := indice if desbloqueada else 7
		var atlas := AtlasTexture.new()
		atlas.atlas = _iconos
		atlas.region = Rect2((cuadro % 4) * 32, (cuadro / 4) * 32, 32, 32)
		var icono := TextureRect.new()
		icono.texture = atlas
		icono.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icono.custom_minimum_size = Vector2(26, 26)
		icono.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icono.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icono.mouse_filter = Control.MOUSE_FILTER_IGNORE
		return icono
	var circulo := Control.new()
	circulo.custom_minimum_size = Vector2(26, 26)
	circulo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	circulo.draw.connect(func() -> void: circulo.draw_circle(Vector2(13, 13), 11.0, color if desbloqueada else Color("3a3648")))
	return circulo


# Recuerdos -------------------------------------------------------------

func _crear_recuerdos() -> void:
	var caja := HBoxContainer.new()
	caja.add_theme_constant_override("separation", 8)
	caja.size = _contenido.size
	_contenido.add_child(caja)

	var lista := VBoxContainer.new()
	lista.add_theme_constant_override("separation", 3)
	lista.custom_minimum_size = Vector2(170, 0)
	caja.add_child(lista)
	var ids := GameState.ids_emociones()
	for i in ids.size():
		var encontrado := GameState.tiene_fragmento(ids[i])
		var recuerdo := GameState.obtener_recuerdo(ids[i])
		var titulo := recuerdo.titulo if (encontrado and recuerdo != null) else "???"
		var b := Button.new()
		b.text = "%d. %s" % [i + 1, titulo]
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(170, 27)
		b.add_theme_font_size_override("font_size", 11)
		b.pressed.connect(_elegir_recuerdo.bind(i))
		lista.add_child(b)
		_lista_recuerdos.append(b)

	var detalle := PanelContainer.new()
	detalle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detalle.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detalle.add_theme_stylebox_override("panel", EstiloUI.caja(Color("1e1b2e"), EstiloUI.DORADO.darkened(0.5), 1, 10, 3))
	caja.add_child(detalle)
	var texto := VBoxContainer.new()
	texto.add_theme_constant_override("separation", 6)
	detalle.add_child(texto)
	_detalle_titulo = EstiloUI.etiqueta("", 14, EstiloUI.DORADO)
	texto.add_child(_detalle_titulo)
	_detalle_texto = EstiloUI.etiqueta("", 11, EstiloUI.CREMA)
	_detalle_texto.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detalle_texto.custom_minimum_size = Vector2(300, 0)
	texto.add_child(_detalle_texto)
	_elegir_recuerdo(_recuerdo)


func _elegir_recuerdo(indice: int) -> void:
	if _lista_recuerdos.is_empty():
		return
	_recuerdo = clampi(indice, 0, _lista_recuerdos.size() - 1)
	var ids := GameState.ids_emociones()
	for i in _lista_recuerdos.size():
		var activo := i == _recuerdo
		var b := _lista_recuerdos[i]
		b.add_theme_stylebox_override("normal", EstiloUI.caja(EstiloUI.MORADO_PULSADO if activo else EstiloUI.MORADO, EstiloUI.DORADO if activo else EstiloUI.MORADO, 2 if activo else 1, 5))
		b.add_theme_color_override("font_color", EstiloUI.DORADO if activo else Color("d9cfe8"))
	var id := ids[_recuerdo]
	var recuerdo := GameState.obtener_recuerdo(id)
	if GameState.tiene_fragmento(id) and recuerdo != null:
		_detalle_titulo.text = recuerdo.titulo
		_detalle_texto.text = "\n\n".join(recuerdo.lineas)
	else:
		_detalle_titulo.text = "???"
		_detalle_texto.text = "Un recuerdo aún sin encontrar"


# Regalos ---------------------------------------------------------------

## Los objetos de memoria de los cofres: uno por emoción. Los que aún no se tienen salen como "???".
func _crear_regalos() -> void:
	var rejilla := GridContainer.new()
	rejilla.columns = 2
	rejilla.add_theme_constant_override("h_separation", 6)
	rejilla.add_theme_constant_override("v_separation", 5)
	rejilla.size = _contenido.size
	_contenido.add_child(rejilla)
	for id in GameState.ids_emociones():
		var datos := GameState.obtener_datos(id)
		var tiene := GameState.tiene_regalo(id)
		var tarjeta := PanelContainer.new()
		tarjeta.custom_minimum_size = Vector2(_contenido.size.x / 2.0 - 4.0, 50)
		tarjeta.add_theme_stylebox_override("panel", EstiloUI.caja(Color("1e1b2e"), Color(datos.color, 0.7) if tiene else Color("3a3358"), 1, 5, 3))
		var columna := VBoxContainer.new()
		columna.add_theme_constant_override("separation", 1)
		tarjeta.add_child(columna)
		columna.add_child(EstiloUI.etiqueta(datos.regalo_nombre if tiene else "???", 11, datos.color.lightened(0.3) if tiene else EstiloUI.GRIS))
		var texto := EstiloUI.etiqueta(datos.regalo_texto if tiene else "Un regalo aún sin encontrar", 9, Color("d9cfe8") if tiene else EstiloUI.GRIS)
		texto.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		texto.max_lines_visible = 3
		texto.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		columna.add_child(texto)
		rejilla.add_child(tarjeta)


# Conexiones ------------------------------------------------------------

## Un esquema de tarjetas y flechas: emoción -> habilidad -> obstáculo -> zona que abre. Hasta que el
## jugador ve el obstáculo por primera vez, la conexión sale como "???"; después se ve completa y, con
## un visto, cuando ya está abierta.
func _crear_conexiones() -> void:
	var columna := VBoxContainer.new()
	columna.add_theme_constant_override("separation", 8)
	columna.size = _contenido.size
	_contenido.add_child(columna)
	var intro := EstiloUI.etiqueta("Lo que cada emoción te enseña abre caminos nuevos.", 11, EstiloUI.GRIS)
	intro.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	columna.add_child(intro)
	for c in Progresion.compuertas():
		columna.add_child(_fila_conexion(c))


func _fila_conexion(c: Dictionary) -> Control:
	var id: String = c["id"]
	var vista := GameState.compuerta_vista(id)
	var abierta := GameState.compuerta_esta_abierta(id)
	var emocion := GameState.obtener_datos(str(c["emocion_que_la_da"]))
	var destino := GameState.obtener_datos(str(c["zona_destino"]))
	var color: Color = emocion.color if emocion != null else EstiloUI.DORADO
	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", 4)
	fila.alignment = BoxContainer.ALIGNMENT_CENTER
	var habilidad: String = Progresion.nombre_habilidad(str(c["habilidad_requerida"])) if vista else "???"
	var textos := [
		emocion.nombre if (vista and emocion != null) else "???",
		habilidad,
		str(c["nombre"]) if vista else "???",
		destino.nombre if (vista and destino != null) else "???",
	]
	for i in textos.size():
		if i > 0:
			fila.add_child(_flecha(color if vista else EstiloUI.GRIS))
		fila.add_child(_tarjeta_conexion(textos[i], color if vista else EstiloUI.GRIS, abierta))
	fila.add_child(_visto(abierta))
	return fila


func _tarjeta_conexion(texto: String, color: Color, abierta: bool) -> Control:
	var tarjeta := PanelContainer.new()
	tarjeta.custom_minimum_size = Vector2(102, 40)
	tarjeta.add_theme_stylebox_override("panel", EstiloUI.caja(Color("1e1b2e"), Color(color, 0.9 if abierta else 0.55), 2 if abierta else 1, 4, 3))
	var e := EstiloUI.etiqueta(texto, 11, color.lightened(0.3))
	e.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	e.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	e.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tarjeta.add_child(e)
	return tarjeta


func _flecha(color: Color) -> Control:
	var f := Control.new()
	f.custom_minimum_size = Vector2(16, 40)
	f.mouse_filter = Control.MOUSE_FILTER_IGNORE
	f.draw.connect(func() -> void:
		var y := f.size.y / 2.0
		f.draw_line(Vector2(1, y), Vector2(13, y), color, 2.0)
		f.draw_line(Vector2(8, y - 5), Vector2(14, y), color, 2.0)
		f.draw_line(Vector2(8, y + 5), Vector2(14, y), color, 2.0))
	return f


## El visto de una conexión ya abierta (dibujado, sin depender de la fuente).
func _visto(abierta: bool) -> Control:
	var v := Control.new()
	v.custom_minimum_size = Vector2(22, 40)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if abierta:
		v.draw.connect(func() -> void:
			var y := v.size.y / 2.0
			v.draw_polyline(PackedVector2Array([Vector2(3, y), Vector2(9, y + 6), Vector2(19, y - 7)]), Color("8fd19e"), 3.0, true))
	return v


# Pistas ----------------------------------------------------------------

func _crear_pistas() -> void:
	var desplazable := ScrollContainer.new()
	desplazable.size = _contenido.size
	desplazable.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	desplazable.focus_mode = Control.FOCUS_NONE
	_contenido.add_child(desplazable)
	var columna := VBoxContainer.new()
	columna.add_theme_constant_override("separation", 8)
	columna.custom_minimum_size = Vector2(_contenido.size.x - 14, 0)
	desplazable.add_child(columna)
	if GameState.pistas.is_empty():
		var vacio := EstiloUI.etiqueta("Aún no has recibido pistas. Si algo te cierra el paso, pulsa E junto a él o habla con la Guía.", 12, EstiloUI.GRIS)
		vacio.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		columna.add_child(vacio)
		return
	for p in GameState.pistas:
		var caja := PanelContainer.new()
		caja.add_theme_stylebox_override("panel", EstiloUI.caja(Color("1e1b2e"), EstiloUI.DORADO.darkened(0.5), 1, 6, 3))
		var v := VBoxContainer.new()
		caja.add_child(v)
		v.add_child(EstiloUI.etiqueta(str(p["titulo"]), 12, EstiloUI.DORADO))
		var t := EstiloUI.etiqueta(str(p["texto"]), 11, EstiloUI.CREMA)
		t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(t)
		columna.add_child(caja)


# Progreso --------------------------------------------------------------

func _crear_progreso() -> void:
	var columna := VBoxContainer.new()
	columna.add_theme_constant_override("separation", 12)
	columna.size = _contenido.size
	columna.alignment = BoxContainer.ALIGNMENT_CENTER
	_contenido.add_child(columna)
	var total := GameState.ids_emociones().size()
	columna.add_child(_linea_progreso("Emociones integradas %d/%d" % [GameState.cantidad_integradas(), total]))
	columna.add_child(_linea_progreso("Recuerdos %d/%d" % [GameState.cantidad_fragmentos(), total]))
	columna.add_child(_linea_progreso("Consejos de las emociones %d/%d" % [GameState.cantidad_consejos_vistos(), Consejos.total()]))

	# Un punto por emoción, con el color de su estado
	var puntos := Control.new()
	puntos.custom_minimum_size = Vector2(0, 22)
	puntos.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ids := GameState.ids_emociones()
	puntos.draw.connect(func() -> void:
		var ancho := puntos.size.x
		for i in ids.size():
			var estado: String = GameState.estado.get(ids[i], "pendiente")
			var centro := Vector2(ancho / 2.0 + (i - (ids.size() - 1) / 2.0) * 30.0, 11.0)
			puntos.draw_circle(centro, 9.0, COLOR_ESTADO[estado].darkened(0.4))
			puntos.draw_circle(centro, 7.0, COLOR_ESTADO[estado]))
	columna.add_child(puntos)

	var es_pasado := GameState.epoca == "pasado"
	var epoca := EstiloUI.etiqueta(
		"Estás en el Pasado, donde viven los recuerdos cálidos." if es_pasado else "Estás en el Presente, un mundo gris que todavía puedes sanar.",
		12, Color("f4b860") if es_pasado else Color("9fb4d8"))
	epoca.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	columna.add_child(epoca)


func _linea_progreso(texto: String) -> Label:
	var e := EstiloUI.etiqueta(texto, 18, EstiloUI.DORADO)
	e.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return e
