class_name Valoracion
extends CanvasLayer
## Valoración del jugador (capa 12): su opinión sobre el juego. Se abre desde la pantalla de Resultados con
## "Dar mi opinión sobre el juego". Es OPCIONAL: se puede cerrar con "Ahora no" o con ESC sin perder nada (en
## ese caso no se guarda nada). Mismo estilo que el Cuestionario (fondo oscurecido, caja morada con borde
## dorado, el Guía escribiendo la introducción).
##
## Bloques: (opcional, si Resources/config_valoracion.json tiene "usar_sus": true) las 10 afirmaciones de la escala
## de usabilidad SUS; 1) seis afirmaciones de 1 a 5; 2) nota general (1 a 5 estrellas) y frecuencia con la que se
## juega; 3) tres comentarios libres de hasta 300 caracteres, todos opcionales.
## Se guarda en Evaluacion.valoracion y, SOLO con consentimiento, entra en el CSV y en el JSON de sesión.
##
## Uso:   await Valoracion.mostrar(get_tree())

const ESCENA := "res://Scenes/UI/Valoracion.tscn"
const RUTA_CONFIG := "res://Resources/config_valoracion.json"
const MAXIMO_TEXTO := 300

const INTRO := ["Antes de despedirnos, ¿me cuentas cómo fue tu experiencia?", "Es opcional y puedes salir cuando quieras, sin perder nada."]
const GRACIAS := "Gracias por contarnos tu experiencia. Tus palabras ayudan a que ECOS aprenda a escuchar mejor lo que sentimos."
const GRACIAS_SIN_GUARDAR := "Como elegiste jugar sin guardar, no se escribió nada en ningún archivo."

## Las 10 afirmaciones de la escala SUS, adaptadas al juego. Las impares son positivas y las pares, negativas.
const SUS := [
	["s1", "Creo que me gustaría usar este juego con frecuencia."],
	["s2", "Encontré el juego innecesariamente complejo."],
	["s3", "Pensé que el juego era fácil de usar."],
	["s4", "Creo que necesitaría ayuda de una persona técnica para poder jugarlo."],
	["s5", "Encontré que las diferentes partes del juego estaban bien integradas."],
	["s6", "Pensé que había demasiada inconsistencia en el juego."],
	["s7", "Imagino que la mayoría de las personas aprenderían a jugarlo muy rápido."],
	["s8", "Encontré el juego muy incómodo de usar."],
	["s9", "Me sentí muy seguro o segura jugándolo."],
	["s10", "Necesité aprender muchas cosas antes de poder empezar a jugar."],
]
const USABILIDAD := [
	["u1", "Entendí qué tenía que hacer en el juego."],
	["u2", "Los controles fueron fáciles de usar."],
	["u3", "El juego se veía y sonaba bien."],
	["u4", "Los textos y las pistas me ayudaron cuando no sabía qué hacer."],
	["u5", "Me dieron ganas de seguir jugando."],
	["u6", "El juego me hizo pensar en cómo manejo mis emociones."],
]
const FRECUENCIAS := ["Nunca", "A veces", "Seguido"]
const COMENTARIOS := [
	["gusto", "¿Qué fue lo que más te gustó?"],
	["mejorar", "¿Qué te confundió o qué cambiarías?"],
	["error", "¿Viste algún error? Cuéntanos qué pasó."],
]

signal terminada(enviada: bool)

var _raiz: Control
var _guia: AnimatedSprite2D
var _caja: PanelContainer
var _contenido: VBoxContainer
var _paginas: Array[Dictionary] = []
var _respuestas := {}          # id -> valor
var _textos := {}              # id -> TextEdit
var _cerrando := false
var _enviada := false

signal _avanzar


## Abre la valoración y espera a que se cierre. Devuelve true si se envió.
static func mostrar(arbol: SceneTree) -> bool:
	var escena := (load(ESCENA) as PackedScene).instantiate() as Valoracion
	arbol.root.add_child.call_deferred(escena)
	await escena.tree_exited
	return Evaluacion.valoracion_enviada()


## Lee Resources/config_valoracion.json: ¿se incluye la escala SUS? (por defecto no).
static func usar_sus() -> bool:
	if not FileAccess.file_exists(RUTA_CONFIG):
		return false
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(RUTA_CONFIG))
	return typeof(d) == TYPE_DICTIONARY and bool(d.get("usar_sus", false))


## Puntaje SUS (0 a 100): en los ítems impares, valor - 1; en los pares, 5 - valor; se suman los diez y se
## multiplican por 2.5. `respuestas` es id (s1..s10) -> valor de 1 a 5. Devuelve -1 si falta alguno.
static func calcular_sus(respuestas: Dictionary) -> float:
	var suma := 0
	for i in 10:
		var id := "s%d" % (i + 1)
		if not respuestas.has(id):
			return -1.0
		var v := int(respuestas[id])
		suma += (v - 1) if (i + 1) % 2 == 1 else (5 - v)
	return suma * 2.5


func _ready() -> void:
	layer = 12
	process_mode = Node.PROCESS_MODE_ALWAYS
	Evaluacion.cuestionario_activo = true
	_guia = FondoEvaluacion.crear(self)
	_raiz = Control.new()
	_raiz.set_anchors_preset(Control.PRESET_FULL_RECT)
	_raiz.theme = EstiloUI.tema()
	_raiz.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_raiz.modulate.a = 0.0
	add_child(_raiz)
	_caja = PanelContainer.new()
	_caja.position = Vector2(168, 24)
	_caja.size = Vector2(452, 312)
	_caja.add_theme_stylebox_override("panel", EstiloUI.caja(Color("1e1b2e", 0.96), EstiloUI.DORADO, 2, 14, 5))
	_raiz.add_child(_caja)
	_contenido = VBoxContainer.new()
	_contenido.add_theme_constant_override("separation", 8)
	_caja.add_child(_contenido)
	_armar_paginas()
	create_tween().tween_property(_raiz, "modulate:a", 1.0, 0.5)
	Sonido.efecto("dialogo_abrir")
	_ejecutar()


# ESC cancela (no se pierde nada: simplemente no se envía)
func _input(evento: InputEvent) -> void:
	if evento.is_action_pressed("DIARIO") or evento.is_action_pressed("HABILIDAD"):
		get_viewport().set_input_as_handled()
	elif evento.is_action_pressed("PAUSA") or evento.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_cerrar(false)


func _armar_paginas() -> void:
	_paginas.clear()
	if usar_sus():
		for s in SUS:
			_paginas.append({"tipo": "likert", "id": s[0], "texto": s[1], "titulo": "Sobre la facilidad de uso"})
	for u in USABILIDAD:
		_paginas.append({"tipo": "likert", "id": u[0], "texto": u[1], "titulo": "Tu experiencia"})
	_paginas.append({"tipo": "nota"})
	_paginas.append({"tipo": "frecuencia"})
	_paginas.append({"tipo": "textos"})


# --- Secuencia ---

func _ejecutar() -> void:
	await _intro()
	if _cerrando:
		return
	var i := 0
	while i < _paginas.size() and not _cerrando:
		await _mostrar_pagina(i)
		i += 1
	if _cerrando:
		return
	_enviar()
	await _gracias()
	_cerrar(true)


func _limpiar() -> void:
	for hijo in _contenido.get_children():
		hijo.queue_free()
	_textos.clear()


## El Guía escribe unas líneas de introducción.
func _intro() -> void:
	_limpiar()
	_contenido.add_child(EstiloUI.etiqueta("Guía", 12, EstiloUI.DORADO))
	var texto := _etiqueta_larga("\n\n".join(INTRO), 15)
	texto.custom_minimum_size = Vector2(410, 120)
	texto.visible_characters = 0
	_contenido.add_child(texto)
	var fila := HBoxContainer.new()
	fila.alignment = BoxContainer.ALIGNMENT_END
	fila.add_theme_constant_override("separation", 8)
	var ahora_no := _boton("Ahora no", func() -> void: _cerrar(false), 110)
	var seguir := _boton("Seguir", func() -> void: _avanzar.emit(), 110)
	fila.add_child(ahora_no)
	fila.add_child(seguir)
	_contenido.add_child(fila)
	seguir.disabled = true
	_guia.play(&"hablar")
	await Dialogo.escribir_etiqueta(texto, "\n\n".join(INTRO))   # mismo blip que todo el texto del juego
	_guia.play(&"idle")
	seguir.disabled = false
	seguir.grab_focus()
	await _avanzar


func _mostrar_pagina(indice: int) -> void:
	var p := _paginas[indice]
	_limpiar()
	_contenido.add_child(EstiloUI.etiqueta("Opinión  ·  %d de %d" % [indice + 1, _paginas.size()], 10, EstiloUI.GRIS))
	match p["tipo"]:
		"likert":
			await _pagina_likert(p)
		"nota":
			await _pagina_nota()
		"frecuencia":
			await _pagina_frecuencia()
		"textos":
			await _pagina_textos()


func _pagina_likert(p: Dictionary) -> void:
	_contenido.add_child(_etiqueta_larga(str(p["texto"]), 15))
	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", 8)
	fila.alignment = BoxContainer.ALIGNMENT_CENTER
	_contenido.add_child(fila)
	var primero: Button = null
	for v in range(1, 6):
		var elegir := func() -> void:
			_respuestas[p["id"]] = v
			_avanzar.emit()
		var b := _boton(str(v), elegir, 62)
		b.custom_minimum_size = Vector2(62, 44)
		fila.add_child(b)
		if primero == null:
			primero = b
	var extremos := HBoxContainer.new()
	var izquierda := EstiloUI.etiqueta("1 = Nada de acuerdo", 10, EstiloUI.GRIS)
	izquierda.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var derecha := EstiloUI.etiqueta("5 = Totalmente de acuerdo", 10, EstiloUI.GRIS)
	derecha.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	derecha.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	extremos.add_child(izquierda)
	extremos.add_child(derecha)
	_contenido.add_child(extremos)
	_contenido.add_child(_pie_ahora_no())
	primero.grab_focus.call_deferred()
	await _avanzar


## Nota general: de 1 a 5 estrellas.
func _pagina_nota() -> void:
	_contenido.add_child(_etiqueta_larga("Nota general del juego", 15))
	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", 6)
	fila.alignment = BoxContainer.ALIGNMENT_CENTER
	_contenido.add_child(fila)
	var primero: Button = null
	for n in range(1, 6):
		var b := BotonEstrellas.new(n)
		b.pressed.connect(func() -> void:
			Sonido.efecto("ui_elegir")
			_respuestas["nota"] = n
			_avanzar.emit())
		b.focus_entered.connect(func() -> void: Sonido.efecto("ui_mover"))
		fila.add_child(b)
		if primero == null:
			primero = b
	_contenido.add_child(EstiloUI.etiqueta("1 estrella = no me gustó, 5 estrellas = me encantó", 10, EstiloUI.GRIS))
	_contenido.add_child(_pie_ahora_no())
	primero.grab_focus.call_deferred()
	await _avanzar


func _pagina_frecuencia() -> void:
	_contenido.add_child(_etiqueta_larga("¿Con qué frecuencia juegas videojuegos?", 15))
	var primero: Button = null
	for f in FRECUENCIAS:
		var elegir := func() -> void:
			_respuestas["frecuencia"] = f
			_avanzar.emit()
		var b := _boton(f, elegir, 410)
		_contenido.add_child(b)
		if primero == null:
			primero = b
	_contenido.add_child(_pie_ahora_no())
	primero.grab_focus.call_deferred()
	await _avanzar


## Tres comentarios libres (todos opcionales, hasta 300 caracteres).
func _pagina_textos() -> void:
	_contenido.add_child(EstiloUI.etiqueta("En tus palabras (todo es opcional)", 13, EstiloUI.DORADO))
	for c in COMENTARIOS:
		_contenido.add_child(EstiloUI.etiqueta(c[1], 11, EstiloUI.CREMA))
		var campo := TextEdit.new()
		campo.custom_minimum_size = Vector2(410, 44)
		campo.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
		campo.scroll_fit_content_height = false
		campo.add_theme_font_size_override("font_size", 11)
		campo.text_changed.connect(func() -> void:
			if campo.text.length() > MAXIMO_TEXTO:
				campo.text = campo.text.substr(0, MAXIMO_TEXTO)
				campo.set_caret_column(MAXIMO_TEXTO))
		_contenido.add_child(campo)
		_textos[c[0]] = campo
	var fila := HBoxContainer.new()
	fila.alignment = BoxContainer.ALIGNMENT_END
	fila.add_theme_constant_override("separation", 8)
	fila.add_child(_boton("Ahora no", func() -> void: _cerrar(false), 110))
	var al_enviar := func() -> void:
		for c in COMENTARIOS:
			_respuestas[c[0]] = (_textos[c[0]] as TextEdit).text.strip_edges()
		_avanzar.emit()
	var enviar := _boton("Enviar", al_enviar, 110)
	fila.add_child(enviar)
	_contenido.add_child(fila)
	await _avanzar


func _gracias() -> void:
	_limpiar()
	_contenido.add_child(EstiloUI.etiqueta("Guía", 12, EstiloUI.DORADO))
	var texto := GRACIAS + ("\n\n" + GRACIAS_SIN_GUARDAR if not Evaluacion.consentimiento_guardar else "")
	var e := _etiqueta_larga(texto, 15)
	e.custom_minimum_size = Vector2(410, 130)
	e.visible_characters = 0
	_contenido.add_child(e)
	var cerrar := _boton("Cerrar", func() -> void: _avanzar.emit(), 130)
	cerrar.size_flags_horizontal = Control.SIZE_SHRINK_END
	cerrar.disabled = true
	_contenido.add_child(cerrar)
	_guia.play(&"hablar")
	await Dialogo.escribir_etiqueta(e, texto)   # mismo blip que todo el texto del juego
	_guia.play(&"idle")
	cerrar.disabled = false
	cerrar.grab_focus()
	await _avanzar


## Guarda la valoración (en memoria; Evaluacion la exporta solo con consentimiento).
func _enviar() -> void:
	var sus := {}
	for s in SUS:
		if _respuestas.has(s[0]):
			sus[s[0]] = _respuestas[s[0]]
	var datos := {
		"id_participante": Evaluacion.participante_id,
		"fecha_iso": Time.get_datetime_string_from_system(false),
		"version_juego": str(ProjectSettings.get_setting("application/config/version", "0")),
		"respuestas": {},
		"nota": int(_respuestas.get("nota", 0)),
		"frecuencia": str(_respuestas.get("frecuencia", "")),
		"sus": sus,
		"sus_puntaje": calcular_sus(sus) if sus.size() == 10 else -1.0,
		"gusto": str(_respuestas.get("gusto", "")),
		"mejorar": str(_respuestas.get("mejorar", "")),
		"error": str(_respuestas.get("error", "")),
	}
	for u in USABILIDAD:
		datos["respuestas"][u[0]] = int(_respuestas.get(u[0], 0))
	Evaluacion.guardar_valoracion(datos)
	_enviada = true


func _cerrar(enviada: bool) -> void:
	if _cerrando:
		return
	_cerrando = true
	Sonido.efecto("ui_cancelar" if not enviada else "ui_elegir")
	_avanzar.emit()   # por si algo estaba esperando
	terminada.emit(enviada)
	var t := create_tween()
	t.tween_property(_raiz, "modulate:a", 0.0, 0.4)
	await t.finished
	Evaluacion.cuestionario_activo = false
	queue_free()


# --- Utilidades ---

func _etiqueta_larga(texto: String, tamano: int) -> Label:
	var e := EstiloUI.etiqueta(texto, tamano, EstiloUI.CREMA)
	e.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	e.custom_minimum_size = Vector2(410, 60)
	return e


func _boton(texto: String, accion: Callable, ancho: int) -> Button:
	var b := Button.new()
	b.text = texto
	b.custom_minimum_size = Vector2(ancho, 30)
	b.pressed.connect(func() -> void:
		Sonido.efecto("ui_elegir")
		accion.call())
	b.focus_entered.connect(func() -> void: Sonido.efecto("ui_mover"))
	return b


func _pie_ahora_no() -> Control:
	var fila := HBoxContainer.new()
	fila.alignment = BoxContainer.ALIGNMENT_END
	fila.add_child(_boton("Ahora no", func() -> void: _cerrar(false), 110))
	return fila


## Un botón que se dibuja con n estrellas doradas (la nota de 1 a 5).
class BotonEstrellas extends Button:
	var n := 1

	func _init(cantidad: int) -> void:
		n = cantidad
		custom_minimum_size = Vector2(76, 40)
		tooltip_text = "%d estrella%s" % [n, "" if n == 1 else "s"]

	func _draw() -> void:
		var total := n * 11.0
		var inicio := (size.x - total) / 2.0 + 5.0
		for i in n:
			var c := Vector2(inicio + i * 11.0, size.y / 2.0)
			var puntos := PackedVector2Array()
			for k in 10:
				var radio := 5.0 if k % 2 == 0 else 2.2
				var a := -PI / 2.0 + k * PI / 5.0
				puntos.append(c + Vector2(cos(a), sin(a)) * radio)
			draw_colored_polygon(puntos, Color("f4c77b"))
